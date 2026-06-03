from neo4j import GraphDatabase, Session, Driver
from typing import Optional, List, Dict, Any, Generator
from contextlib import contextmanager
import logging

logger = logging.getLogger(__name__)


class ManejadorBaseDatosGrafo:
    def __init__(self, uri: str, usuario: str, contraseña: str):
        """
        Inicializa el driver de Neo4j.
        Args:
            uri: URI de conexión a Neo4j (ej: 'bolt://localhost:7687')
            usuario: Usuario de Neo4j
            contraseña: Contraseña de Neo4j
        """
        self.driver: Driver = GraphDatabase.driver(uri, auth=(usuario, contraseña))
        self._verificar_conexion()
    
    def _verificar_conexion(self) -> None:
        try:
            with self.driver.session() as sesion:
                sesion.run("RETURN 1")
            logger.info("Conexión exitosa a Neo4j")
        except Exception as e:
            logger.error(f"Fallo al conectar con Neo4j: {e}")
            raise
    
    @contextmanager
    def obtener_sesion(self) -> Generator[Session, None, None]:
        sesion = self.driver.session()
        try:
            yield sesion
        finally:
            sesion.close()
    
    def cerrar(self) -> None:
        self.driver.close()
        logger.info("Driver de Neo4j cerrado")
    
    def ejecutar_consulta(self, consulta: str, parametros: Optional[Dict[str, Any]] = None) -> List[Dict[str, Any]]:
        if parametros is None:
            parametros = {}
        
        with self.obtener_sesion() as sesion:
            resultado = sesion.run(consulta, parametros)
            return [registro.data() for registro in resultado]
    
    def crear_nodo_usuario(self, usuario_id: str, email: str, nombre_usuario: str, **kwargs) -> Dict[str, Any]:
        consulta = """
        CREATE (u:Usuario {
            id: $usuario_id,
            email: $email,
            nombre_usuario: $nombre_usuario,
            fecha_creacion: datetime()
        })
        SET u += $propiedades_adicionales
        RETURN u
        """
        
        params = {
            "usuario_id": usuario_id,
            "email": email,
            "nombre_usuario": nombre_usuario,
            "propiedades_adicionales": kwargs
        }
        
        resultado = self.ejecutar_consulta(consulta, params)
        return resultado[0] if resultado else None
    
    def crear_nodo_etiqueta(self, nombre_etiqueta: str, categoria: Optional[str] = None) -> Dict[str, Any]:
        consulta = """
        CREATE (t:Etiqueta {
            nombre: $nombre_etiqueta,
            fecha_creacion: datetime()
        })
        SET t += CASE WHEN $categoria IS NOT NULL THEN {categoria: $categoria} ELSE {} END
        RETURN t
        """
        
        params = {
            "nombre_etiqueta": nombre_etiqueta,
            "categoria": categoria
        }
        
        resultado = self.ejecutar_consulta(consulta, params)
        return resultado[0] if resultado else None
    
    def crear_relacion_interes(self, usuario_id: str, nombre_etiqueta: str, fortaleza: float = 1.0) -> bool:
        consulta = """
        MATCH (u:Usuario {id: $usuario_id})
        MATCH (t:Etiqueta {nombre: $nombre_etiqueta})
        CREATE (u)-[r:INTERESADO_EN {fortaleza: $fortaleza, fecha_creacion: datetime()}]->(t)
        RETURN r
        """
        
        params = {
            "usuario_id": usuario_id,
            "nombre_etiqueta": nombre_etiqueta,
            "fortaleza": fortaleza
        }
        
        resultado = self.ejecutar_consulta(consulta, params)
        return bool(resultado)
    
    def crear_relacion_amistad(self, usuario_id_1: str, usuario_id_2: str) -> bool:
        consulta = """
        MATCH (u1:Usuario {id: $usuario_id_1})
        MATCH (u2:Usuario {id: $usuario_id_2})
        CREATE (u1)-[r:AMIGO_DE {fecha_creacion: datetime()}]->(u2)
        RETURN r
        """
        
        params = {
            "usuario_id_1": usuario_id_1,
            "usuario_id_2": usuario_id_2
        }
        
        resultado = self.ejecutar_consulta(consulta, params)
        return bool(resultado)