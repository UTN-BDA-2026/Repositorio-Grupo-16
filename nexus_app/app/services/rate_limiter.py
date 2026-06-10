import logging
from typing import Tuple
from datetime import timedelta
from redis.asyncio import Redis as AsyncRedis
from app.config import get_settings

logger = logging.getLogger(__name__)
settings = get_settings()

MAX_INTENTOS = 5
TIEMPO_BLOQUEO_MINUTOS = 15
PREFIJO_REDIS_INTENTOS = "login_intentos:"
PREFIJO_REDIS_BLOQUEADO = "login_bloqueado:"


class RateLimiterLoginRedis:
    """Gestor de Rate Limiter para intentos de login usando Redis."""
    
    def __init__(self, redis_client: AsyncRedis):
        self.redis = redis_client
        self.max_intentos = MAX_INTENTOS
        self.tiempo_bloqueo = TIEMPO_BLOQUEO_MINUTOS * 60  # Convertir a segundos
    
    async def está_bloqueado(self, email: str) -> bool:
        clave_bloqueado = f"{PREFIJO_REDIS_BLOQUEADO}{email}"
        resultado = await self.redis.exists(clave_bloqueado)
        
        if resultado:
            logger.warning(f"Email bloqueado por Rate Limiter: {email}")
        
        return bool(resultado)
    
    async def registrar_intento_fallido(self, email: str) -> Tuple[int, bool]:
        clave_intentos = f"{PREFIJO_REDIS_INTENTOS}{email}"
        clave_bloqueado = f"{PREFIJO_REDIS_BLOQUEADO}{email}"
        
        # Incrementar contador de intentos
        numero_intentos = await self.redis.incr(clave_intentos)
        
        # Establecer TTL de 24 horas si es el primer intento
        if numero_intentos == 1:
            await self.redis.expire(clave_intentos, 86400)
        
        logger.warning(f"Intento fallido #{numero_intentos} para {email}")
        
        # Si alcanza el máximo, bloquear
        bloqueado_ahora = False
        if numero_intentos >= self.max_intentos:
            await self.redis.setex(
                clave_bloqueado,
                self.tiempo_bloqueo,
                "bloqueado"
            )
            bloqueado_ahora = True
            logger.error(f"{email} bloqueado por {TIEMPO_BLOQUEO_MINUTOS} minutos")
        
        return numero_intentos, bloqueado_ahora
    
    async def registrar_intento_exitoso(self, email: str) -> None:
        clave_intentos = f"{PREFIJO_REDIS_INTENTOS}{email}"
        await self.redis.delete(clave_intentos)
        logger.info(f"Historial de intentos borrado para {email}")
    
    async def obtener_intentos_restantes(self, email: str) -> int:
        clave_intentos = f"{PREFIJO_REDIS_INTENTOS}{email}"
        intentos_actuales = await self.redis.get(clave_intentos)
        
        if intentos_actuales is None:
            return self.max_intentos
        
        intentos_actuales = int(intentos_actuales)
        intentos_restantes = max(0, self.max_intentos - intentos_actuales)
        
        return intentos_restantes
    
    async def obtener_tiempo_bloqueo_restante(self, email: str) -> int:
        clave_bloqueado = f"{PREFIJO_REDIS_BLOQUEADO}{email}"
        ttl = await self.redis.ttl(clave_bloqueado)
        return ttl