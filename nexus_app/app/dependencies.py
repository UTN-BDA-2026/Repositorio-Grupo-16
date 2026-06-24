from typing import Generator
from sqlalchemy.orm import Session
from redis.asyncio import Redis as AsyncRedis
import logging

logger = logging.getLogger(__name__)


# ============ DEPENDENCIAS PARA BASE DE DATOS RELACIONAL ============

def get_db() -> Generator[Session, None, None]:
    """
    Provee una sesión de PostgreSQL por request.
    Reutiliza el SessionLocal (engine + pool) creado en app.main,
    para no abrir un engine nuevo en cada petición.
    El import es diferido para evitar el import circular
    (main -> auth -> dependencies -> main).
    """
    from app.main import SessionLocal

    db = SessionLocal()
    try:
        logger.debug("Sesión PostgreSQL abierta")
        yield db
    finally:
        db.close()
        logger.debug("Sesión PostgreSQL cerrada (pool devuelto)")


# ============ DEPENDENCIAS PARA BASE DE DATOS REDIS ============

async def get_redis() -> AsyncRedis:
    """
    Provee el cliente Redis asíncrono compartido creado en app.main.
    Import diferido por la misma razón que get_db.
    """
    from app.main import redis_async

    return redis_async


__all__ = [
    "get_db",
    "get_redis",
]
