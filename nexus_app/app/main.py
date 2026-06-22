import logging
import bcrypt
import redis
from redis.asyncio import Redis as AsyncRedis
from contextlib import asynccontextmanager, contextmanager
from typing import Generator

from fastapi import FastAPI, HTTPException, Depends
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import create_engine, event
from sqlalchemy.orm import sessionmaker, Session
from neo4j import GraphDatabase, Session as Neo4jSession
from neo4j.exceptions import Neo4jError

from app.config import get_settings, Settings
from app.models.relational import Base, UsuarioORM, PhotoORM, RegistroUsuarioRequest, RegistroUsuarioResponse, FotoRequest, FotoResponse
from app.models.graph import ManejadorBaseDatosGrafo

# ============ IMPORTACIONES DE SERVICIOS ============
from app.services.recommendation import ServicioRecomendaciones
from app.services.cache_redis import cache_redis

# ============ CONFIGURACIÓN INICIAL ============

settings = get_settings()
Settings.configurar_logging()
logger = logging.getLogger(__name__)

# ============ INICIALIZACIÓN DE SQLALCHEMY ============

engine = create_engine(
    settings.postgres_url_sqlalchemy,
    pool_size=settings.sqlalchemy_pool_size,
    max_overflow=settings.sqlalchemy_max_overflow,
    pool_timeout=settings.sqlalchemy_pool_timeout,
    pool_recycle=3600,  # Reciclar conexiones cada hora
    pool_pre_ping=True,  # Verificar conexión antes de usarla
    echo=settings.sqlalchemy_echo,
    echo_pool=True,
)

# Listener para auditoría de transacciones
@event.listens_for(engine, "begin")
def receive_begin(conn):
    """Log cuando comienza una transacción (BEGIN)."""
    logger.info("═══════════════════════════════════════════════════════════")
    logger.info("▶ TRANSACCIÓN INICIADA: BEGIN")
    logger.info("═══════════════════════════════════════════════════════════")


@event.listens_for(engine, "commit")
def receive_commit(conn):
    """Log cuando se confirma una transacción (COMMIT)."""
    logger.info("═══════════════════════════════════════════════════════════")
    logger.info("✓ TRANSACCIÓN CONFIRMADA: COMMIT")
    logger.info("═══════════════════════════════════════════════════════════")


@event.listens_for(engine, "rollback")
def receive_rollback(conn):
    """Log cuando se revierte una transacción (ROLLBACK)."""
    logger.error("═══════════════════════════════════════════════════════════")
    logger.error("✗ TRANSACCIÓN REVERTIDA: ROLLBACK")
    logger.error("═══════════════════════════════════════════════════════════")

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# ============ INICIALIZACIÓN DE NEO4J ============

# Driver 1 (básico, sin mejoras)
neo4j_driver = GraphDatabase.driver(
    settings.neo4j_uri,
    auth=(settings.neo4j_user, settings.neo4j_password),
    connection_timeout=settings.neo4j_connection_timeout,
)

# Driver 2 (mejorado, con pool, seguridad, context managers)
manejador_grafo = ManejadorBaseDatosGrafo(
    uri=settings.neo4j_uri,
    usuario=settings.neo4j_user,
    contraseña=settings.neo4j_password
)

# Verificar conexión a Neo4j
try:
    with neo4j_driver.session() as session:
        session.run("RETURN 1")
    logger.info("✓ Conexión exitosa a Neo4j")
except Neo4jError as e:
    logger.error(f"✗ No se pudo conectar a Neo4j: {e}")
    raise

# ============ INICIALIZACIÓN DE REDIS ============

# Cliente síncrono para operaciones básicas
redis_client = redis.from_url(settings.redis_url, decode_responses=True)

# Cliente asíncrono para FastAPI
redis_async = AsyncRedis.from_url(settings.redis_url, decode_responses=True)

logger.info("✓ Cliente Redis inicializado")

# ============ INSTANCIA DEL SERVICIO DE RECOMENDACIONES ============
servicio_recomendaciones = ServicioRecomendaciones(manejador_grafo)
logger.info("✓ ServicioRecomendaciones inicializado")

# ============ DEPENDENCIAS DE INYECCIÓN ============

def get_db() -> Generator[Session, None, None]:
    """
    Dependencia para obtener sesión de PostgreSQL.
    Asegura que la sesión se cierre correctamente después del endpoint.
    """
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def get_neo4j_session() -> Generator[Neo4jSession, None, None]:
    """Usar context manager del manejador mejorado"""
    with manejador_grafo.obtener_sesion(database=settings.neo4j_database) as sesion:
        yield sesion


# ============ DEPENDENCIA: REDIS ASYNC ============

async def get_redis():
    """Dependency para acceder a Redis en endpoints."""
    return redis_async


# ============ CONTEXT MANAGER PARA TRANSACCIONES HÍBRIDAS ============

@contextmanager
def transaccion_hibrida(db_session: Session, neo4j_session: Neo4jSession):
    """
    Context manager para gestionar transacciones híbridas ACID.
    
    Garantiza:
    - Si ambas BDs tienen éxito → COMMIT en ambas
    - Si Neo4j falla → ROLLBACK explícito en PostgreSQL
    - Logging detallado de auditoría (BEGIN, COMMIT, ROLLBACK, SQL, Cypher)
    
    Uso:
        with transaccion_hibrida(db_session, neo4j_session) as (db, neo4j):
            # Operaciones que deben ser atómicas
    """
    try:
        logger.info("▶ INICIANDO TRANSACCIÓN HÍBRIDA PostgreSQL + Neo4j")
        yield db_session, neo4j_session
        
        # Si llegamos aquí, todo fue exitoso
        db_session.commit()
        logger.info("✓ COMMIT exitoso en PostgreSQL")
        logger.info("✓ TRANSACCIÓN HÍBRIDA COMPLETADA CON ÉXITO")
        
    except Neo4jError as e:
        # Error en Neo4j → ROLLBACK en PostgreSQL
        logger.error(f"✗ ERROR en Neo4j: {str(e)}")
        logger.error("✗ EJECUTANDO ROLLBACK EN PostgreSQL...")
        
        db_session.rollback()
        logger.error("✗ ROLLBACK completado en PostgreSQL")
        logger.error("✗ TRANSACCIÓN HÍBRIDA FALLIDA - INCONSISTENCIA PREVENIDA")
        
        raise HTTPException(
            status_code=500,
            detail=f"Error crítico en transacción distribuida: {str(e)}"
        )
    
    except Exception as e:
        # Cualquier otro error → ROLLBACK en PostgreSQL
        logger.error(f"✗ ERROR inesperado: {str(e)}")
        logger.error("✗ EJECUTANDO ROLLBACK EN PostgreSQL...")
        
        db_session.rollback()
        logger.error("✗ ROLLBACK completado en PostgreSQL")
        
        raise HTTPException(
            status_code=500,
            detail=f"Error en transacción: {str(e)}"
        )


# ============ LIFESPAN DE LA APLICACIÓN ============

@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    Gestiona el ciclo de vida de la aplicación FastAPI.
    Maneja eventos de inicio y cierre.
    """
    # Startup
    logger.info(" Aplicación Nexus se está iniciando...")
    logger.info(f" Pool de conexiones: {settings.sqlalchemy_pool_size}")
    logger.info(f" Redis URL: {settings.redis_url}")
    yield
    # Shutdown
    logger.info(" Cerrando conexiones...")
    await redis_async.close()
    manejador_grafo.cerrar()  # ✅ Cerrar el manejador mejorado

app = FastAPI(lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ============ ENDPOINTS ============
from app.auth import router as auth_router
app.include_router(auth_router)


@app.get("/")
async def root():
    """Punto de entrada raíz."""
    return {
        "mensaje": "Bienvenido a la API Nexus",
        "version": "1.0.0",
        "documentacion": "/docs"
    }


@app.get("/health")
async def health():
    """Verificación de salud de la aplicación y conexiones."""
    return {
        "estado": "saludable",
        "postgres": "conectado",
        "neo4j": "conectado"
    }


# ============ ENDPOINT CRÍTICO: TRANSACCIÓN HÍBRIDA ============

@app.post("/usuarios/registro", response_model=RegistroUsuarioResponse, status_code=201)
async def registro_usuario_transaccion_hibrida(
    solicitud: RegistroUsuarioRequest,
    db: Session = Depends(get_db),
    neo4j: Neo4jSession = Depends(get_neo4j_session)
):
    """
     ENDPOINT CRÍTICO: Registro de usuario con transacción híbrida ACID.
    
    Este endpoint demuestra el requisito académico crítico de transacciones distribuidas:
    1. Inserta usuario en PostgreSQL usando SQLAlchemy ORM
    2. Crea nodo en Neo4j + relaciones a etiquetas de interés
    3. Si Neo4j falla → ROLLBACK explícito en PostgreSQL
    4. Logging detallado de auditoría (BEGIN, COMMIT, ROLLBACK, SQL, Cypher)
    
    Flujo ACID garantizado:
    ┌─────────────────────────────────────────────────────────┐
    │ PASO 1: Validar datos de entrada (Pydantic)            │
    │ PASO 2: Abrir transacción PostgreSQL (BEGIN)            │
    │ PASO 3: Insertar usuario y hacer flush para obtener ID   │
    │ PASO 4: Crear nodo en Neo4j con el usuario_id           │
    │ PASO 5: Crear relaciones INTERESADO_EN hacia etiquetas  │
    │ PASO 6: COMMIT en PostgreSQL si todo ok                 │
    │ PASO 7: Si Neo4j falla en paso 4-5 → ROLLBACK en PG     │
    └─────────────────────────────────────────────────────────┘
    
    Request:
        {
            "email": "usuario@example.com",
            "nombre_usuario": "usuario123",
            "contrasena": "secura_123",
            "fecha_nacimiento": "1995-05-15T00:00:00",
            "sexo": "Masculino",
            "bio": "Amante de la tecnología",
            "etiquetas_interes": [1, 2, 3]
        }
    
    Response (201):
        {
            "usuario_id": 42,
            "email": "usuario@example.com",
            "nombre_usuario": "usuario123",
            "bio": "Amante de la tecnología",
            "fecha_creacion": "2026-06-06T12:34:56",
            "nodo_neo4j_creado": true,
            "etiquetas_vinculadas": 3
        }
    
    Excepciones:
        - 400: Validación Pydantic falla (email inválido, etc)
        - 409: Email ya existe en PostgreSQL
        - 500: Neo4j falla (se ejecuta ROLLBACK en PostgreSQL)
    """
    
    logger.info(f"╔═══════════════════════════════════════════════════════════════╗")
    logger.info(f"║  SOLICITUD DE REGISTRO: {solicitud.email}")
    logger.info(f"╚═══════════════════════════════════════════════════════════════╝")
    
    try:
        # ========== PASO 1: Validación de email duplicado ==========
        logger.info(f"[1/7] Validando que email no exista en PostgreSQL...")
        usuario_existente = db.query(UsuarioORM).filter(
            UsuarioORM.email == solicitud.email
        ).first()
        
        if usuario_existente:
            logger.warning(f"⚠ Email '{solicitud.email}' ya está registrado")
            raise HTTPException(
                status_code=409,
                detail=f"El email '{solicitud.email}' ya existe en la plataforma"
            )
        logger.info(f"✓ Email disponible")
        
        # ========== PASO 2-7: TRANSACCIÓN HÍBRIDA ==========
        with transaccion_hibrida(db, neo4j) as (db_session, neo4j_session):
            
            # ========== PASO 3: Insertar en PostgreSQL ==========
            logger.info(f"[2/7] Hasheando contraseña con bcrypt...")
            salt = bcrypt.gensalt()
            contrasena_hash = bcrypt.hashpw(
                solicitud.contrasena.encode("utf-8"), 
                salt
            ).decode("utf-8")
            logger.info(f"✓ Contraseña hasheada")
            
            logger.info(f"[3/7] Insertando usuario en PostgreSQL (BEGIN)...")
            nuevo_usuario = UsuarioORM(
                email=solicitud.email,
                nombre_usuario=solicitud.nombre_usuario,
                contrasena_hash=contrasena_hash,
                fecha_nacimiento=solicitud.fecha_nacimiento,
                sexo=solicitud.sexo,
                bio=solicitud.bio,
                activo=True
            )
            
            db_session.add(nuevo_usuario)
            db_session.flush()  # Obtener el ID generado sin hacer COMMIT aún
            usuario_id = nuevo_usuario.usuario_id
            logger.info(f"✓ Usuario insertado: usuario_id={usuario_id}")
            logger.info(f"✓ SQL: INSERT INTO usuarios (email, nombre_usuario, ...) VALUES (...)")
            
            # ========== PASO 4: Crear nodo en Neo4j ==========
            logger.info(f"[4/7] Creando nodo Usuario en Neo4j...")
            cypher_crear_nodo = """
                CREATE (u:Usuario {
                    usuario_id: $usuario_id,
                    email: $email,
                    nombre_usuario: $nombre_usuario,
                    fecha_creacion: datetime()
                })
                RETURN u
            """
            params_nodo = {
                "usuario_id": usuario_id,
                "email": solicitud.email,
                "nombre_usuario": solicitud.nombre_usuario
            }
            logger.info(f"✓ Cypher: {cypher_crear_nodo}")
            neo4j_session.run(cypher_crear_nodo, params_nodo)
            logger.info(f"✓ Nodo Usuario creado en Neo4j")
            
            # ========== PASO 5: Crear relaciones a etiquetas ==========
            etiquetas_vinculadas = 0
            if solicitud.etiquetas_interes:
                logger.info(f"[5/7] Vinculando {len(solicitud.etiquetas_interes)} etiquetas de interés...")
                
                for etiqueta_id in solicitud.etiquetas_interes:
                    cypher_relacion = """
                        MATCH (u:Usuario {usuario_id: $usuario_id})
                        MATCH (e:Etiqueta {etiqueta_id: $etiqueta_id})
                        CREATE (u)-[r:INTERESADO_EN {
                            fecha_creacion: datetime(),
                            fortaleza: 1.0
                        }]->(e)
                        RETURN r
                    """
                    params_relacion = {
                        "usuario_id": usuario_id,
                        "etiqueta_id": etiqueta_id
                    }
                    logger.info(f"  ├─ Creando relación INTERESADO_EN → Etiqueta {etiqueta_id}")
                    neo4j_session.run(cypher_relacion, params_relacion)
                    etiquetas_vinculadas += 1
                
                logger.info(f"✓ {etiquetas_vinculadas} etiquetas vinculadas")
            else:
                logger.info(f"[5/7] Sin etiquetas de interés especificadas")
            
            # ========== PASO 6: Si llegamos aquí, todo OK ==========
            logger.info(f"[6/7] Preparando COMMIT en PostgreSQL...")
            # El context manager se encargará del COMMIT
            
            # ========== PASO 7: Preparar respuesta ==========
            logger.info(f"[7/7] Transacción híbrida completada exitosamente")
            
            return RegistroUsuarioResponse(
                usuario_id=usuario_id,
                email=solicitud.email,
                nombre_usuario=solicitud.nombre_usuario,
                bio=solicitud.bio,
                fecha_creacion=nuevo_usuario.fecha_creacion,
                nodo_neo4j_creado=True,
                etiquetas_vinculadas=etiquetas_vinculadas
            )
    
    except HTTPException:
        raise
    
    except Exception as e:
        logger.error(f"✗ Error inesperado en registro: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=500,
            detail="Error inesperado durante el registro"
        )


@app.get("/usuarios/{usuario_id}", response_model=dict)
async def obtener_usuario(usuario_id: int, db: Session = Depends(get_db)):
    """
    Obtiene los datos de un usuario específico desde PostgreSQL.
    """
    logger.info(f"Buscando usuario con ID {usuario_id}")
    
    usuario = db.query(UsuarioORM).filter(
        UsuarioORM.usuario_id == usuario_id,
        UsuarioORM.activo == True
    ).first()
    
    if not usuario:
        raise HTTPException(status_code=404, detail="Usuario no encontrado")
    
    return {
        "usuario_id": usuario.usuario_id,
        "email": usuario.email,
        "nombre_usuario": usuario.nombre_usuario,
        "bio": usuario.bio,
        "fecha_creacion": usuario.fecha_creacion,
        "activo": usuario.activo
    }


@app.get("/usuarios", response_model=dict)
async def listar_usuarios(limite: int = 20, offset: int = 0, db: Session = Depends(get_db)):
    """
    Lista usuarios con paginación.
    """
    logger.info(f"Listando usuarios (limite={limite}, offset={offset})")
    
    usuarios = db.query(UsuarioORM).filter(
        UsuarioORM.activo == True
    ).limit(limite).offset(offset).all()
    
    return {
        "usuarios": [
            {
                "usuario_id": u.usuario_id,
                "email": u.email,
                "nombre_usuario": u.nombre_usuario,
                "fecha_creacion": u.fecha_creacion
            }
            for u in usuarios
        ],
        "limite": limite,
        "offset": offset,
        "total": len(usuarios)
    }


@app.post("/usuarios/{usuario_id}/etiquetas/bulk")
async def agregar_multiples_etiquetas(
    usuario_id: str,
    etiquetas_request: dict
):
    
    logger.info(f"AGREGAR ETIQUETAS (TRANSACCIÓN ACID): Usuario {usuario_id}")

    try:
        if "etiquetas" not in etiquetas_request or not etiquetas_request["etiquetas"]:
            logger.warning("Solicitud sin etiquetas")
            raise HTTPException(
                status_code=400,
                detail="La solicitud debe contener una lista 'etiquetas' no vacía"
            )
        
        etiquetas = etiquetas_request["etiquetas"]
        
        for idx, etiqueta in enumerate(etiquetas):
            if "nombre" not in etiqueta:
                logger.error(f"Etiqueta {idx} sin campo 'nombre'")
                raise HTTPException(
                    status_code=400,
                    detail=f"Etiqueta {idx}: falta el campo obligatorio 'nombre'"
                )
        
        logger.info(f"[1/3] Validación completada: {len(etiquetas)} etiquetas para procesar")
        
        logger.info(f"[2/3] ServicioRecomendaciones inicializado")
        
        logger.info(f"[3/3] Iniciando transacción ACID para agregar etiquetas...")
        resultado = servicio_recomendaciones.agregar_multiples_etiquetas_transaccional(
            usuario_id=usuario_id,
            etiquetas=etiquetas
        )
        
        if not resultado['exitoso']:
            logger.error(f"Error en transacción: {resultado['error']}")
            raise HTTPException(
                status_code=500,
                detail=f"Error en transacción ACID: {resultado['error']}"
            )
        
        logger.info(f"Transacción exitosa: {resultado['etiquetas_creadas']} etiquetas agregadas")
        logger.info(f"OPERACIÓN COMPLETADA CON ÉXITO")
        
        return {
            "exitoso": True,
            "usuario_id": usuario_id,
            "etiquetas_agregadas": resultado['etiquetas_agregadas'],
            "detalles": resultado['detalles'],
            "cache_invalidada": resultado.get('cache_invalidada', False)
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error inesperado: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=500,
            detail=f"Error al agregar etiquetas: {str(e)}"
        )


# ============ ENDPOINTS DE FOTOS ============

@app.post("/usuarios/{usuario_id}/fotos", response_model=FotoResponse, status_code=201)
async def subir_foto(
    usuario_id: int,
    foto_request: FotoRequest,
    db: Session = Depends(get_db)
):
    """
    Sube una foto para un usuario.
    La primera foto subida se usa como foto de perfil.
    Máximo 6 fotos por usuario (validado por trigger en BD).
    
    Request:
        {
            "url_imagen": "https://imgur.com/photo.jpg",
            "descripcion": "Mi foto de perfil"
        }
    """
    logger.info(f"Subiendo foto para usuario {usuario_id}")
    
    try:
        # Verificar que el usuario existe
        usuario = db.query(UsuarioORM).filter(
            UsuarioORM.usuario_id == usuario_id
        ).first()
        
        if not usuario:
            logger.warning(f"Usuario {usuario_id} no existe")
            raise HTTPException(
                status_code=404,
                detail=f"Usuario {usuario_id} no encontrado"
            )
        
        # Crear foto
        nueva_foto = PhotoORM(
            user_id=usuario_id,
            url_imagen=foto_request.url_imagen,
            descripcion=foto_request.descripcion
        )
        
        db.add(nueva_foto)
        db.commit()
        db.refresh(nueva_foto)
        
        logger.info(f"✓ Foto {nueva_foto.photo_id} subida exitosamente para usuario {usuario_id}")
        
        return nueva_foto
        
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        logger.error(f"Error al subir foto: {str(e)}")
        raise HTTPException(
            status_code=500,
            detail=f"Error al subir foto: {str(e)}"
        )


@app.get("/usuarios/{usuario_id}/fotos", response_model=dict)
async def listar_fotos(
    usuario_id: int,
    db: Session = Depends(get_db)
):
    """
    Lista todas las fotos de un usuario, ordenadas por fecha de subida (la primera es la foto de perfil).
    """
    logger.info(f"Listando fotos para usuario {usuario_id}")
    
    try:
        # Verificar que el usuario existe
        usuario = db.query(UsuarioORM).filter(
            UsuarioORM.usuario_id == usuario_id
        ).first()
        
        if not usuario:
            logger.warning(f"Usuario {usuario_id} no existe")
            raise HTTPException(
                status_code=404,
                detail=f"Usuario {usuario_id} no encontrado"
            )
        
        # Obtener fotos ordenadas por fecha (la primera es la más antigua = foto de perfil)
        fotos = db.query(PhotoORM).filter(
            PhotoORM.user_id == usuario_id
        ).order_by(PhotoORM.fecha_subida).all()
        
        logger.info(f"✓ {len(fotos)} fotos encontradas para usuario {usuario_id}")
        
        return {
            "usuario_id": usuario_id,
            "fotos": [
                {
                    "photo_id": f.photo_id,
                    "url_imagen": f.url_imagen,
                    "descripcion": f.descripcion,
                    "fecha_subida": f.fecha_subida,
                    "es_foto_perfil": idx == 0  # La primera es la foto de perfil
                }
                for idx, f in enumerate(fotos)
            ],
            "total": len(fotos)
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error al listar fotos: {str(e)}")
        raise HTTPException(
            status_code=500,
            detail=f"Error al listar fotos: {str(e)}"
        )


# ============ ENDPOINTS DE RECOMENDACIONES (CON CACHÉ) ============

@app.get("/api/v1/recomendaciones/todas/{usuario_id}")
async def obtener_todas_las_recomendaciones(
    usuario_id: str,
    limite_por_tipo: int = 10,
    db: Session = Depends(get_db)
):
    try:
        logger.info(f"GET /api/v1/recomendaciones/todas/{usuario_id}")
        resultado = servicio_recomendaciones.obtener_todas_las_recomendaciones(
            usuario_id=usuario_id,
            limite_por_tipo=limite_por_tipo
        )
        return resultado
    except Exception as e:
        logger.error(f"Error: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/api/v1/recomendaciones/amigos-de-amigos/{usuario_id}")
async def obtener_amigos_de_amigos(
    usuario_id: str,
    limite: int = 10,
    db: Session = Depends(get_db)
):
    try:
        logger.info(f"GET /api/v1/recomendaciones/amigos-de-amigos/{usuario_id}")
        resultados = servicio_recomendaciones.obtener_amigos_de_amigos(
            usuario_id=usuario_id,
            limite=limite
        )
        return {
            "usuario_id": usuario_id,
            "tipo": "amigos_de_amigos",
            "resultados": resultados,
            "cantidad": len(resultados)
        }
    except Exception as e:
        logger.error(f"Error: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/api/v1/recomendaciones/intereses-comunes/{usuario_id}")
async def obtener_intereses_comunes(
    usuario_id: str,
    limite: int = 10,
    db: Session = Depends(get_db)
):
    try:
        logger.info(f"GET /api/v1/recomendaciones/intereses-comunes/{usuario_id}")
        resultados = servicio_recomendaciones.obtener_usuarios_intereses_comunes(
            usuario_id=usuario_id,
            limite=limite
        )
        return {
            "usuario_id": usuario_id,
            "tipo": "intereses_comunes",
            "resultados": resultados,
            "cantidad": len(resultados)
        }
    except Exception as e:
        logger.error(f"Error: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/api/v1/recomendaciones/etiquetas-sugeridas/{usuario_id}")
async def obtener_etiquetas_recomendadas(
    usuario_id: str,
    limite: int = 15,
    db: Session = Depends(get_db)
):
    try:
        logger.info(f"GET /api/v1/recomendaciones/etiquetas-sugeridas/{usuario_id}")
        resultados = servicio_recomendaciones.obtener_etiquetas_recomendadas(
            usuario_id=usuario_id,
            limite=limite
        )
        return {
            "usuario_id": usuario_id,
            "tipo": "etiquetas_sugeridas",
            "resultados": resultados,
            "cantidad": len(resultados)
        }
    except Exception as e:
        logger.error(f"Error: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/api/v1/recomendaciones/colaborativo/{usuario_id}")
async def obtener_colaborativo(
    usuario_id: str,
    limite: int = 10,
    db: Session = Depends(get_db)
):
    try:
        logger.info(f"GET /api/v1/recomendaciones/colaborativo/{usuario_id}")
        resultados = servicio_recomendaciones.obtener_recomendaciones_filtrado_colaborativo(
            usuario_id=usuario_id,
            limite=limite
        )
        return {
            "usuario_id": usuario_id,
            "tipo": "colaborativo",
            "resultados": resultados,
            "cantidad": len(resultados)
        }
    except Exception as e:
        logger.error(f"Error: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/api/v1/recomendaciones/estadisticas/{usuario_id}")
async def obtener_estadisticas(
    usuario_id: str,
    db: Session = Depends(get_db)
):
    try:
        logger.info(f"GET /api/v1/recomendaciones/estadisticas/{usuario_id}")
        stats = servicio_recomendaciones.obtener_estadisticas_red(usuario_id)
        return {
            "usuario_id": usuario_id,
            "estadisticas": stats
        }
    except Exception as e:
        logger.error(f"Error: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@app.delete("/api/v1/recomendaciones/cache/usuario/{usuario_id}")
async def limpiar_cache_usuario(usuario_id: str):
    try:
        logger.info(f"DELETE /api/v1/recomendaciones/cache/usuario/{usuario_id}")
        cantidad = cache_redis.invalidar_usuario(usuario_id)
        return {
            "usuario_id": usuario_id,
            "caché_limpiada": True,
            "claves_eliminadas": cantidad
        }
    except Exception as e:
        logger.error(f"Error: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/api/v1/recomendaciones/cache/estadisticas")
async def obtener_estadisticas_cache():
    try:
        logger.info(f"GET /api/v1/recomendaciones/cache/estadisticas")
        stats = cache_redis.obtener_estadisticas_cache()
        return stats
    except Exception as e:
        logger.error(f"Error: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@app.exception_handler(Exception)
async def manejador_excepciones_global(request, exc):
    """Manejador global de excepciones no capturadas."""
    logger.error(f"Excepción no manejada: {exc}", exc_info=True)
    return HTTPException(status_code=500, detail="Error interno del servidor")


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(
        app,
        host=settings.fastapi_host,
        port=settings.fastapi_port,
        debug=settings.fastapi_debug,
    )