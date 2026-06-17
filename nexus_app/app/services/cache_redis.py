import json
import logging
from typing import Any, Optional, List, Dict
import redis
from redis.exceptions import RedisError
from app.config import get_settings

logger = logging.getLogger(__name__)
settings = get_settings()

# ============ PREFIJOS DE CACHÉ ============
PREFIJO_AMIGOS = "cache:amigos:"
PREFIJO_INTERESES = "cache:intereses:"
PREFIJO_ETIQUETAS_REC = "cache:etiquetas_rec:"
PREFIJO_COLABORATIVO = "cache:colaborativo:"
PREFIJO_STATS = "cache:stats:"

# ============ TIEMPOS DE EXPIRACIÓN (segundos) ============
TTL_AMIGOS = 3600  # 1 hora
TTL_INTERESES = 1800  # 30 minutos
TTL_ETIQUETAS = 3600  # 1 hora
TTL_COLABORATIVO = 1800  # 30 minutos
TTL_STATS = 600  # 10 minutos


class ManejadorCacheRedis:    
    def __init__(self):
        try:
            self.redis_client = redis.Redis(
                host=settings.redis_host,
                port=settings.redis_port,
                password=settings.redis_password,
                db=settings.redis_db,
                decode_responses=True,
                socket_connect_timeout=5,
                socket_keepalive=True,
                health_check_interval=30
            )
            # Probar conexión
            self.redis_client.ping()
            logger.info("Conexión exitosa a Redis")
        except RedisError as e:
            logger.error(f"Error conectando a Redis: {e}")
            self.redis_client = None
    
    def _esta_disponible(self) -> bool:
        if self.redis_client is None:
            return False
        try:
            self.redis_client.ping()
            return True
        except RedisError:
            logger.warning("Redis no disponible, operación sin caché")
            return False
    
    def _serializar(self, datos: Any) -> str:
        return json.dumps(datos, default=str)
    
    def _deserializar(self, datos_str: str) -> Any:
        return json.loads(datos_str)
    
    # ============ OPERACIONES BÁSICAS ============
    def obtener(self, clave: str) -> Optional[Any]:
        """Obtiene valor del caché."""
        if not self._esta_disponible():
            return None
        
        try:
            valor = self.redis_client.get(clave)
            if valor:
                logger.debug(f"CACHÉ HIT: {clave}")
                return self._deserializar(valor)
            logger.debug(f"CACHÉ MISS: {clave}")
            return None
        except RedisError as e:
            logger.error(f"Error obteniendo caché {clave}: {e}")
            return None
    
    def guardar(self, clave: str, valor: Any, ttl: int = 3600) -> bool:
        """Guarda valor en caché con TTL."""
        if not self._esta_disponible():
            return False
        
        try:
            self.redis_client.setex(
                clave,
                ttl,
                self._serializar(valor)
            )
            logger.debug(f"CACHÉ SET: {clave} (TTL: {ttl}s)")
            return True
        except RedisError as e:
            logger.error(f"Error guardando caché {clave}: {e}")
            return False
    
    def eliminar(self, clave: str) -> bool:
        """Elimina valor del caché."""
        if not self._esta_disponible():
            return False
        
        try:
            self.redis_client.delete(clave)
            logger.debug(f"CACHÉ DELETE: {clave}")
            return True
        except RedisError as e:
            logger.error(f"Error eliminando caché {clave}: {e}")
            return False
    
    def eliminar_patron(self, patron: str) -> int:
        """Elimina todas las claves que coinciden con el patrón."""
        if not self._esta_disponible():
            return 0
        
        try:
            claves = self.redis_client.keys(patron)
            if claves:
                cantidad = self.redis_client.delete(*claves)
                logger.debug(f"CACHÉ CLEAR PATTERN: {patron} ({cantidad} claves eliminadas)")
                return cantidad
            return 0
        except RedisError as e:
            logger.error(f"Error eliminando patrón {patron}: {e}")
            return 0
    
    def existe(self, clave: str) -> bool:
        """Verifica si clave existe."""
        if not self._esta_disponible():
            return False
        
        try:
            return bool(self.redis_client.exists(clave))
        except RedisError as e:
            logger.error(f"Error verificando existencia de {clave}: {e}")
            return False
    
    # ============ MÉTODOS ESPECÍFICOS PARA RECOMENDACIONES ============
    
    def obtener_amigos_de_amigos(self, usuario_id: str) -> Optional[List[Dict]]:
        """Obtiene amigos de amigos del caché."""
        clave = f"{PREFIJO_AMIGOS}{usuario_id}"
        return self.obtener(clave)
    
    def guardar_amigos_de_amigos(self, usuario_id: str, datos: List[Dict]) -> bool:
        """Guarda amigos de amigos en caché."""
        clave = f"{PREFIJO_AMIGOS}{usuario_id}"
        return self.guardar(clave, datos, TTL_AMIGOS)
    
    def obtener_intereses_comunes(self, usuario_id: str) -> Optional[List[Dict]]:
        """Obtiene usuarios con intereses comunes del caché."""
        clave = f"{PREFIJO_INTERESES}{usuario_id}"
        return self.obtener(clave)
    
    def guardar_intereses_comunes(self, usuario_id: str, datos: List[Dict]) -> bool:
        """Guarda usuarios con intereses comunes en caché."""
        clave = f"{PREFIJO_INTERESES}{usuario_id}"
        return self.guardar(clave, datos, TTL_INTERESES)
    
    def obtener_etiquetas_recomendadas(self, usuario_id: str) -> Optional[List[Dict]]:
        """Obtiene etiquetas recomendadas del caché."""
        clave = f"{PREFIJO_ETIQUETAS_REC}{usuario_id}"
        return self.obtener(clave)
    
    def guardar_etiquetas_recomendadas(self, usuario_id: str, datos: List[Dict]) -> bool:
        """Guarda etiquetas recomendadas en caché."""
        clave = f"{PREFIJO_ETIQUETAS_REC}{usuario_id}"
        return self.guardar(clave, datos, TTL_ETIQUETAS)
    
    def obtener_colaborativo(self, usuario_id: str) -> Optional[List[Dict]]:
        """Obtiene recomendaciones de filtrado colaborativo del caché."""
        clave = f"{PREFIJO_COLABORATIVO}{usuario_id}"
        return self.obtener(clave)
    
    def guardar_colaborativo(self, usuario_id: str, datos: List[Dict]) -> bool:
        """Guarda recomendaciones de filtrado colaborativo en caché."""
        clave = f"{PREFIJO_COLABORATIVO}{usuario_id}"
        return self.guardar(clave, datos, TTL_COLABORATIVO)
    
    def obtener_estadisticas(self, usuario_id: str) -> Optional[Dict]:
        """Obtiene estadísticas del caché."""
        clave = f"{PREFIJO_STATS}{usuario_id}"
        return self.obtener(clave)
    
    def guardar_estadisticas(self, usuario_id: str, datos: Dict) -> bool:
        """Guarda estadísticas en caché."""
        clave = f"{PREFIJO_STATS}{usuario_id}"
        return self.guardar(clave, datos, TTL_STATS)
    
    # ============ INVALIDACIÓN DE CACHÉ ============
    
    def invalidar_usuario(self, usuario_id: str) -> int:
        """Invalida TODA la caché de un usuario."""
        patron = f"cache:*:{usuario_id}"
        cantidad = self.eliminar_patron(patron)
        logger.info(f"Caché invalidada para usuario {usuario_id} ({cantidad} claves)")
        return cantidad
    
    def invalidar_etiquetas_usuario(self, usuario_id: str) -> int:
        """Invalida caché de etiquetas de un usuario."""
        patron = f"{PREFIJO_ETIQUETAS_REC}{usuario_id}"
        cantidad = self.eliminar(patron)
        logger.info(f"Caché de etiquetas invalidada para usuario {usuario_id}")
        return cantidad
    
    def invalidar_amistades_usuario(self, usuario_id: str) -> int:
        """Invalida caché de amistades de un usuario."""
        patron = f"{PREFIJO_AMIGOS}{usuario_id}"
        cantidad = self.eliminar(patron)
        logger.info(f"Caché de amistades invalidada para usuario {usuario_id}")
        return cantidad
    
    def invalidar_usuarios_afectados(self, usuario_id: str) -> int:
        patron = f"cache:*"
        cantidad = self.eliminar_patron(patron)
        logger.warning(f"Caché global invalidada ({cantidad} claves eliminadas)")
        return cantidad
    
    def obtener_estadisticas_cache(self) -> Dict[str, Any]:
        """Obtiene estadísticas del caché."""
        if not self._esta_disponible():
            return {"disponible": False}
        
        try:
            info = self.redis_client.info()
            return {
                "disponible": True,
                "memoria_usada_mb": info.get("used_memory_human"),
                "clientes_conectados": info.get("connected_clients"),
                "comandos_procesados": info.get("total_commands_processed"),
                "claves_totales": self.redis_client.dbsize()
            }
        except RedisError as e:
            logger.error(f"Error obteniendo estadísticas: {e}")
            return {"disponible": False, "error": str(e)}
    
    def limpiar_todo(self) -> bool:
        if not self._esta_disponible():
            return False
        
        try:
            self.redis_client.flushdb()
            logger.warning("CACHÉ COMPLETAMENTE LIMPIADO")
            return True
        except RedisError as e:
            logger.error(f"Error limpiando caché: {e}")
            return False

# ============ INSTANCIA GLOBAL ============
cache_redis = ManejadorCacheRedis()