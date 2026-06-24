from typing import Generator, AsyncGenerator
from sqlalchemy.orm import Session
from redis.asyncio import Redis as AsyncRedis
import logging

logger = logging.getLogger(__name__)


# ============ DEPENDENCIAS PARA BASE DE DATOS RELACIONAL ============

def get_db() -> Generator[Session, None, None]:
    from app.config import get_settings
    from app.models.relational import get_session_local
    
    settings = get_settings()
    session_local = get_session_local(
        database_url=settings.database_url,
        echo=settings.sqlalchemy_echo
    )
    
    db = session_local()
    try:
        logger.debug("Sesión PostgreSQL abierta")
        yield db
    except Exception as e:
        logger.error(f"Error en sesión PostgreSQL: {e}")
        db.rollback()
        raise
    finally:
        db.close()
        logger.debug("Sesión PostgreSQL cerrada (pool devuelto)")


# ============ DEPENDENCIAS PARA BASE DE DATOS REDIS ============

async def get_redis() -> AsyncGenerator[AsyncRedis, None]:
    from app.config import get_settings
    
    settings = get_settings()
    
    # Crear conexión a Redis
    redis = AsyncRedis.from_url(
        settings.redis_url,
        encoding="utf-8",
        decode_responses=True,
        socket_keepalive=True,
    )
    
    try:
        logger.debug("Conexión Redis abierta")
        # Verificar que Redis está disponible
        await redis.ping()
        yield redis
    except Exception as e:
        logger.error(f"Error en conexión Redis: {e}")
        raise
    finally:
        await redis.close()
        logger.debug("Conexión Redis cerrada")


# ============ DEPENDENCIAS COMBINADAS ============

class DatabaseDependency:
    pass  # Por ahora solo decorativo


__all__ = [
    "get_db",
    "get_redis",
    "DatabaseDependency"
]