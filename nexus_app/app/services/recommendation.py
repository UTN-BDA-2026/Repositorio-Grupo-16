from typing import List, Dict, Any, Optional
from app.models.graph import ManejadorBaseDatosGrafo
import logging

logger = logging.getLogger(__name__)


class ServicioRecomendaciones:    
    def __init__(self, manejador_grafo: ManejadorBaseDatosGrafo):
        """
         Se inicial el servicio de recomendaciones.
        
        Args:
            manejador_grafo: Instancia de ManejadorBaseDatosGrafo
        """
        self.manejador_grafo = manejador_grafo
    
    def obtener_amigos_de_amigos(
        self,
        usuario_id: str,
        limite: int = 10
    ) -> List[Dict[str, Any]]:
        consulta = """
        MATCH (u:Usuario {id: $usuario_id})-[:AMIGO_DE]->(amigo:Usuario)
        MATCH (amigo)-[:AMIGO_DE]->(amigo_de_amigo:Usuario)
        WHERE amigo_de_amigo.id <> $usuario_id
        AND NOT (u)-[:AMIGO_DE]->(amigo_de_amigo)
        WITH amigo_de_amigo, COUNT(amigo) as amigos_mutuos
        ORDER BY amigos_mutuos DESC
        LIMIT $limite
        RETURN amigo_de_amigo.id as usuario_id,
               amigo_de_amigo.nombre_usuario as nombre_usuario,
               amigo_de_amigo.email as email,
               amigos_mutuos
        """
        
        params = {
            "usuario_id": usuario_id,
            "limite": limite
        }
        
        return self.manejador_grafo.ejecutar_consulta(consulta, params)
    
    def obtener_usuarios_intereses_comunes(
        self,
        usuario_id: str,
        minimo_intereses_comunes: int = 1,
        limite: int = 10
    ) -> List[Dict[str, Any]]:
        consulta = """
        MATCH (u:Usuario {id: $usuario_id})-[:INTERESADO_EN]->(etiqueta:Etiqueta)
        MATCH (otro:Usuario)-[:INTERESADO_EN]->(etiqueta)
        WHERE otro.id <> $usuario_id
        WITH otro, COLLECT(DISTINCT etiqueta.nombre) as etiquetas_compartidas, COUNT(DISTINCT etiqueta) as cantidad_comun
        WHERE cantidad_comun >= $minimo_intereses_comunes
        ORDER BY cantidad_comun DESC
        LIMIT $limite
        RETURN otro.id as usuario_id,
               otro.nombre_usuario as nombre_usuario,
               otro.email as email,
               etiquetas_compartidas,
               cantidad_comun
        """
        
        params = {
            "usuario_id": usuario_id,
            "minimo_intereses_comunes": minimo_intereses_comunes,
            "limite": limite
        }
        
        return self.manejador_grafo.ejecutar_consulta(consulta, params)
    
    def obtener_etiquetas_recomendadas(
        self,
        usuario_id: str,
        limite: int = 15
    ) -> List[Dict[str, Any]]:
        consulta = """
        MATCH (u:Usuario {id: $usuario_id})-[:INTERESADO_EN]->(etiqueta:Etiqueta)
        MATCH (u)-[:AMIGO_DE|INTERESADO_EN*2..3]-(usuario_similar:Usuario)-[:INTERESADO_EN]->(etiqueta_recomendada:Etiqueta)
        WHERE NOT (u)-[:INTERESADO_EN]->(etiqueta_recomendada)
        AND etiqueta_recomendada.nombre <> etiqueta.nombre
        WITH etiqueta_recomendada, COUNT(DISTINCT usuario_similar) as popularidad
        ORDER BY popularidad DESC
        LIMIT $limite
        RETURN etiqueta_recomendada.nombre as nombre_etiqueta,
               popularidad
        """
        
        params = {
            "usuario_id": usuario_id,
            "limite": limite
        }
        
        return self.manejador_grafo.ejecutar_consulta(consulta, params)
    
    def obtener_recomendaciones_filtrado_colaborativo(
        self,
        usuario_id: str,
        limite: int = 10
    ) -> List[Dict[str, Any]]:
        consulta = """
        MATCH (u:Usuario {id: $usuario_id})-[:INTERESADO_EN]->(etiqueta_compartida:Etiqueta)
        MATCH (usuario_similar:Usuario)-[:INTERESADO_EN]->(etiqueta_compartida)
        WHERE usuario_similar.id <> $usuario_id
        WITH u, usuario_similar, COUNT(DISTINCT etiqueta_compartida) as puntuacion_similitud
        MATCH (usuario_similar)-[:INTERESADO_EN]->(etiqueta_recomendada:Etiqueta)
        WHERE NOT (u)-[:INTERESADO_EN]->(etiqueta_recomendada)
        WITH etiqueta_recomendada, SUM(puntuacion_similitud) as puntuacion_ponderada, COUNT(DISTINCT usuario_similar) as cantidad_recomendadores
        ORDER BY puntuacion_ponderada DESC, cantidad_recomendadores DESC
        LIMIT $limite
        RETURN etiqueta_recomendada.nombre as nombre_etiqueta,
               puntuacion_ponderada,
               cantidad_recomendadores
        """
        
        params = {
            "usuario_id": usuario_id,
            "limite": limite
        }
        
        return self.manejador_grafo.ejecutar_consulta(consulta, params)
    
    def obtener_estadisticas_red(self, usuario_id: str) -> Dict[str, Any]:
        consulta = """
        MATCH (u:Usuario {id: $usuario_id})
        WITH u
        OPTIONAL MATCH (u)-[:AMIGO_DE]->(amigos:Usuario)
        OPTIONAL MATCH (u)-[:INTERESADO_EN]->(etiquetas:Etiqueta)
        OPTIONAL MATCH (u)-[:AMIGO_DE]->()-[:AMIGO_DE]->(extendido:Usuario)
        WHERE extendido.id <> $usuario_id
        RETURN COUNT(DISTINCT amigos) as cantidad_amigos,
               COUNT(DISTINCT etiquetas) as cantidad_intereses,
               COUNT(DISTINCT extendido) as alcance_red,
               u.id as usuario_id
        """
        
        params = {"usuario_id": usuario_id}
        
        resultado = self.manejador_grafo.ejecutar_consulta(consulta, params)
        return resultado[0] if resultado else {}
    
    def agregar_multiples_etiquetas_transaccional(
        self,
        usuario_id: str,
        etiquetas: List[Dict[str, Any]]
    ) -> Dict[str, Any]:
        logger.info(f"Iniciando operación transaccional: {len(etiquetas)} etiquetas para usuario {usuario_id}")
        
        resultado = self.manejador_grafo.crear_multiples_relaciones_etiquetas_transaccional(
            usuario_id=usuario_id,
            etiquetas=etiquetas
        )
        
        if resultado['exitoso']:
            logger.info(
                f"Éxito: {resultado['etiquetas_creadas']} etiquetas agregadas "
                f"para usuario {usuario_id}"
            )
        else:
            logger.warning(
                f"Fallo en transacción para usuario {usuario_id}: {resultado['error']}"
            )
        
        return resultado