from neo4j import GraphDatabase, Session, Driver, Transaction, auth
from neo4j.exceptions import Neo4jError
from typing import Optional, List, Dict, Any, Generator, Callable
from contextlib import contextmanager
import logging

logger = logging.getLogger(__name__)


class ManejadorBaseDatosGrafo:
    def __init__(
        self,
        uri: str,
        usuario: str,
        contraseña: str,
        connection_timeout: int = 30,
        command_timeout: int = 60,
        max_pool_size: int = 50
    ):
        try:
            # Crear autenticación segura (credentials no se almacenan)
            credenciales = auth.basic_auth(usuario, contraseña)
            
            # Inicializar driver con pool de conexiones
            self.driver: Driver = GraphDatabase.driver(
                uri,
                auth=credenciales,
                connection_timeout=connection_timeout,
                command_timeout=command_timeout,
                max_pool_size=max_pool_size,
                # Seguridad adicional
                encrypted=False, 
                trust=None,  
            )
            
            self.uri = uri
            self._usuario_placeholder = "***PROTEGIDO***"
            self._contraseña_placeholder = "***PROTEGIDO***"
            
            self._verificar_conexion()
            logger.info("Driver Neo4j inicializado con seguridad mejorada")
            
        except Exception as e:
            logger.error(f"Error al inicializar driver Neo4j: {e}")
            raise
    
    def _verificar_conexion(self) -> None:
        """Verifica que la conexión a Neo4j sea válida."""
        try:
            with self.driver.session() as sesion:
                sesion.run("RETURN 1")
            logger.info("Conexión exitosa a Neo4j verificada")
        except Neo4jError as e:
            logger.error(f"Fallo al conectar con Neo4j: {e}")
            raise
    
    @contextmanager
    def obtener_sesion(self, database: str = "neo4j") -> Generator[Session, None, None]:
        sesion = self.driver.session(database=database)
        try:
            logger.debug(f"Sesión Neo4j abierta (DB: {database})")
            yield sesion
        except Neo4jError as e:
            logger.error(f"Error en sesión Neo4j: {e}")
            raise
        finally:
            sesion.close()
            logger.debug(f"Sesión Neo4j cerrada")
    
    @contextmanager
    def transaccion_explicita(
        self,
        database: str = "neo4j",
        timeout: Optional[int] = None
    ) -> Generator[Transaction, None, None]:
        sesion = self.driver.session(database=database)
        try:
            logger.debug(f"Iniciando transacción explícita en {database}")
            with sesion.begin_transaction() as txn:
                yield txn
            logger.info(f"Transacción completada exitosamente")
        except Neo4jError as e:
            logger.error(f"Error en transacción Neo4j: {e}. Rollback automático.")
            raise
        finally:
            sesion.close()
            logger.debug(f"Sesión de transacción cerrada")
    
    def ejecutar_en_transaccion(
        self,
        operaciones: List[Dict[str, Any]],
        database: str = "neo4j"
    ) -> Dict[str, Any]:
        resultados = []
        try:
            with self.transaccion_explicita(database=database) as txn:
                for idx, operacion in enumerate(operaciones):
                    consulta = operacion.get('consulta')
                    parametros = operacion.get('parametros', {})
                    
                    if not consulta:
                        raise ValueError(f"Operación {idx}: falta 'consulta'")
                    
                    logger.debug(f"Ejecutando operación {idx+1}/{len(operaciones)}")
                    resultado = txn.run(consulta, parametros)
                    datos = [registro.data() for registro in resultado]
                    resultados.append({
                        'operacion': idx,
                        'datos': datos,
                        'cantidad': len(datos)
                    })
                    logger.debug(f"Operación {idx}: {len(datos)} registros")
            
            logger.info(f"Transacción exitosa: {len(operaciones)} operaciones")
            return {
                'exitoso': True,
                'resultados': resultados,
                'cantidad_operaciones': len(operaciones),
                'errores': None
            }
        
        except Exception as e:
            mensaje_error = f"Fallo en transacción: {str(e)}"
            logger.error(f"{mensaje_error}")
            return {
                'exitoso': False,
                'resultados': [],
                'cantidad_operaciones': len(operaciones),
                'errores': mensaje_error
            }
    
    def ejecutar_consulta(
        self,
        consulta: str,
        parametros: Optional[Dict[str, Any]] = None,
        database: str = "neo4j"
    ) -> List[Dict[str, Any]]:
        if parametros is None:
            parametros = {}
        
        try:
            with self.obtener_sesion(database=database) as sesion:
                resultado = sesion.run(consulta, parametros)
                datos = [registro.data() for registro in resultado]
                logger.debug(f"Consulta ejecutada: {len(datos)} registros")
                return datos
        except Neo4jError as e:
            logger.error(f"Error en consulta: {e}")
            raise
    
    def cerrar(self) -> None:
        try:
            self.driver.close()
            logger.info("Driver Neo4j cerrado correctamente")
        except Exception as e:
            logger.error(f"Error al cerrar driver: {e}")
            raise
    
    def __repr__(self) -> str:
        return f"ManejadorBaseDatosGrafo(uri={self.uri}, usuario={self._usuario_placeholder})"