import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware

from app.config import get_settings

settings = get_settings()

logging.basicConfig(level=settings.log_level)
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    Gestiona el ciclo de vida de la aplicación FastAPI.
    Maneja eventos de inicio y cierre.
    """
    logger.info("Iniciando aplicación Nexus...")
    yield
    logger.info("Cerrando aplicación Nexus...")


app = FastAPI(
    title="API Nexus",
    description="Plataforma de recomendaciones sociales que conecta personas por intereses",
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


@app.get("/")
async def root():
    """Punto de entrada raíz."""
    return {"mensaje": "Bienvenido a la API Nexus", "version": "1.0.0"}


@app.get("/health")
async def health():
    """Punto de entrada para verificación de salud."""
    return {"estado": "saludable"}


@app.post("/usuarios")
async def crear_usuario(
    nombre: str,
    email: str,
    contrasena: str,
    bio: str | None = None,
):
    """
    Crea un nuevo usuario en la plataforma Nexus.
    Almacena los datos del usuario en PostgreSQL.
    """
    from app.services.user_service import crear_usuario

    usuario = crear_usuario(nombre, email, contrasena, bio)
    if not usuario:
        raise HTTPException(status_code=400, detail="No se pudo crear el usuario")
    return usuario


@app.get("/usuarios/{user_id}")
async def obtener_usuario(user_id: int):
    """
    Recupera un usuario por ID desde PostgreSQL.
    """
    from app.services.user_service import obtener_usuario

    usuario = obtener_usuario(user_id)
    if not usuario:
        raise HTTPException(status_code=404, detail="Usuario no encontrado")
    return usuario


@app.put("/usuarios/{user_id}")
async def actualizar_bio_usuario(user_id: int, nueva_bio: str):
    """
    Actualiza la biografía de un usuario en PostgreSQL.
    """
    from app.services.user_service import actualizar_bio

    usuario = actualizar_bio(user_id, nueva_bio)
    if not usuario:
        raise HTTPException(status_code=404, detail="Usuario no encontrado")
    return usuario


@app.get("/usuarios")
async def listar_usuarios(limite: int = 20, offset: int = 0):
    """
    Lista todos los usuarios activos con paginación.
    """
    from app.services.user_service import listar_usuarios

    usuarios = listar_usuarios(limite, offset)
    return {"usuarios": usuarios, "limite": limite, "offset": offset}


@app.post("/recomendaciones/{user_id}")
async def obtener_recomendaciones(user_id: int, limite: int = 5):
    """
    Obtiene recomendaciones personalizadas para un usuario usando el grafo Neo4j.
    Procesa interacciones sociales e intereses desde la base de datos de grafos.
    """
    try:
        from app.services.recommendation import obtener_recomendaciones

        recomendaciones = obtener_recomendaciones(user_id, limite)
        return {"user_id": user_id, "recomendaciones": recomendaciones}
    except Exception as e:
        logger.error(f"Error al obtener recomendaciones: {e}")
        raise HTTPException(status_code=500, detail="No se pudieron obtener recomendaciones")


@app.exception_handler(Exception)
async def manejador_excepciones_global(request, exc):
    """Manejador de excepciones global."""
    logger.error(f"Excepción no manejada: {exc}")
    return HTTPException(status_code=500, detail="Error interno del servidor")


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(
        app,
        host=settings.fastapi_host,
        port=settings.fastapi_port,
        debug=settings.fastapi_debug,
    )
