import os
from neo4j import GraphDatabase


def get_neo4j_driver():
    """Crear y retornar una instancia del controlador Neo4j."""
    host = os.getenv("NEO4J_HOST", "localhost")
    port = os.getenv("NEO4J_PORT", 7687)
    user = os.getenv("NEO4J_USER", "neo4j")
    password = os.getenv("NEO4J_PASSWORD")

    uri = f"neo4j://{host}:{port}"
    return GraphDatabase.driver(uri, auth=(user, password))


def obtener_recomendaciones(user_id: int, limite: int = 5) -> list:
    """
    Obtiene recomendaciones personalizadas para un usuario desde Neo4j.
    Consulta la base de datos de grafos para usuarios con intereses compartidos.
    """
    driver = get_neo4j_driver()

    query = """
    MATCH (u1:User {user_id: $user_id})-[:INTERESTED_IN]->(interest:Interest)
    MATCH (u2:User)-[:INTERESTED_IN]->(interest)
    WHERE u1 <> u2
    WITH u2, COUNT(DISTINCT interest) AS shared_interests, 
         COUNT(DISTINCT interest) * 1.0 / (
            (SELECT COUNT(DISTINCT i) FROM (
                MATCH (u1)-[:INTERESTED_IN]->(i) RETURN i
            )) + (
                SELECT COUNT(DISTINCT i) FROM (
                    MATCH (u2)-[:INTERESTED_IN]->(i) RETURN i
                ))
        ) AS compatibilidad
    ORDER BY compatibilidad DESC
    LIMIT $limite
    RETURN u2.user_id, u2.nombre, u2.email, compatibilidad, 
           collect(DISTINCT interest.nombre) as intereses_compartidos
    """

    try:
        with driver.session() as session:
            result = session.run(query, user_id=user_id, limite=limite)
            recomendaciones = []
            for record in result:
                recomendaciones.append({
                    "user_id": record["u2.user_id"],
                    "nombre": record["u2.nombre"],
                    "email": record["u2.email"],
                    "compatibilidad": record["compatibilidad"],
                    "intereses_compartidos": record["intereses_compartidos"]
                })
            return recomendaciones
    except Exception as e:
        print(f"Error al obtener recomendaciones desde Neo4j: {e}")
        return []
    finally:
        driver.close()
