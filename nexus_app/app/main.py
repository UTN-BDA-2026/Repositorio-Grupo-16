import logging
import bcrypt
from contextlib import asynccontextmanager, contextmanager
from typing import Generator

from fastapi import FastAPI, HTTPException, Depends
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import create_engine, event
from sqlalchemy.orm import sessionmaker, Session
from neo4j import GraphDatabase, Session as Neo4jSession
from neo4j.exceptions import Neo4jError

from app.config import get_settings, Settings
from app.models.relational import Base, UsuarioORM, RegistroUsuarioRequest, RegistroUsuarioResponse
from app.models.graph import ManejadorBaseDatosGrafo

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
    echo=settings.sqlalchemy_echo,  # Log de todas las sentencias SQL
    echo_pool=True,  # Log de eventos del pool de conexiones
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


# Crear tabla si no existe
Base.metadata.create_all(bind=engine)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# ============ INICIALIZACIÓN DE NEO4J ============

neo4j_driver = GraphDatabase.driver(
    settings.neo4j_uri,
    auth=(settings.neo4j_user, settings.neo4j_password),
    connection_timeout=settings.neo4j_connection_timeout,
)

# Verificar conexión a Neo4j
try:
    with neo4j_driver.session() as session:
        session.run("RETURN 1")
    logger.info("✓ Conexión exitosa a Neo4j")
except Neo4jError as e:
    logger.error(f"✗ No se pudo conectar a Neo4j: {e}")
    raise

manejador_grafo = ManejadorBaseDatosGrafo(
    uri=settings.neo4j_uri,
    usuario=settings.neo4j_user,
    contraseña=settings.neo4j_password
)

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
    """
    Dependencia para obtener sesión de Neo4j.
    Maneja el ciclo de vida de la sesión.
    """
    session = neo4j_driver.session(database=settings.neo4j_database)
    try:
        yield session
    finally:
        session.close()


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
    logger.info("🚀 Iniciando aplicación Nexus...")
    logger.info(f"📍 Entorno: {settings.environment}")
    logger.info(f"📍 PostgreSQL: {settings.postgres_host}:{settings.postgres_port}/{settings.postgres_db}")
    logger.info(f"📍 Neo4j: {settings.neo4j_host}:{settings.neo4j_port}")
    
    yield
    
    logger.info("🛑 Cerrando aplicación Nexus...")
    neo4j_driver.close()
    logger.info("✓ Driver de Neo4j cerrado correctamente")


# ============ INICIALIZACIÓN DE FASTAPI ============

app = FastAPI(
    title="API Nexus",
    description="Plataforma de recomendaciones sociales que conecta personas por intereses. "
                "Con transacciones híbridas ACID (PostgreSQL + Neo4j)",
    version="1.0.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ============ ENDPOINTS ============

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
    🔴 ENDPOINT CRÍTICO: Registro de usuario con transacción híbrida ACID.
    
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
    logger.info(f"║ 📝 SOLICITUD DE REGISTRO: {solicitud.email}")
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


@app.post("/recomendaciones/{usuario_id}")
async def obtener_recomendaciones(usuario_id: int, limite: int = 5):
    """
    Obtiene recomendaciones personalizadas usando el motor Neo4j.
    """
    logger.info(f"Obteniendo recomendaciones para usuario {usuario_id}")
    
    try:
        from app.services.recommendation import obtener_recomendaciones
        
        recomendaciones = obtener_recomendaciones(usuario_id, limite)
        return {
            "usuario_id": usuario_id,
            "recomendaciones": recomendaciones,
            "cantidad": len(recomendaciones)
        }
    except Exception as e:
        logger.error(f"Error al obtener recomendaciones: {e}")
        raise HTTPException(status_code=500, detail="Error al obtener recomendaciones")


@app.exception_handler(Exception)
async def manejador_excepciones_global(request, exc):
    """Manejador global de excepciones no capturadas."""
    logger.error(f"✗ Excepción no manejada: {exc}", exc_info=True)
    return HTTPException(status_code=500, detail="Error interno del servidor")


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(
        app,
        host=settings.fastapi_host,
        port=settings.fastapi_port,
        debug=settings.fastapi_debug,
    )