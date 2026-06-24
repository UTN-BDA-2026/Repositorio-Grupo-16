"""
Sincroniza el grafo Neo4j a partir de los datos relacionales de Postgres.
- Crea constraints (id de Usuario, nombre de Etiqueta).
- Crea nodos Usuario y Etiqueta.
- Crea relaciones INTERESADO_EN desde la tabla user_interests.
- Genera amistades AMIGO_DE entre usuarios con >= 2 intereses en comun.

Coherente con app/services/recommendation.py:
  Usuario.id es STRING, Etiqueta.nombre, relaciones :INTERESADO_EN y :AMIGO_DE.

Uso (dentro del contenedor fastapi):
    docker compose exec fastapi python ops/sync_neo4j.py [LIMITE_USUARIOS]
    (sin argumento usa 150; pasar 0 para todos)
"""
import sys
sys.path.insert(0, "/app")
from sqlalchemy import create_engine, text
from neo4j import GraphDatabase
from app.config import get_settings

LIMITE = int(sys.argv[1]) if len(sys.argv) > 1 else 150

s = get_settings()
pg = create_engine(s.postgres_url_sqlalchemy)
driver = GraphDatabase.driver(s.neo4j_uri, auth=(s.neo4j_user, s.neo4j_password))

# 1) Leer datos relacionales de Postgres
with pg.connect() as conn:
    q_users = "SELECT user_id, nombre, email FROM users WHERE activo = true ORDER BY user_id"
    if LIMITE > 0:
        q_users += f" LIMIT {LIMITE}"
    users = conn.execute(text(q_users)).fetchall()
    ids = [u.user_id for u in users]

    interests = conn.execute(text("""
        SELECT ui.user_id, c.nombre
        FROM user_interests ui
        JOIN categories c ON c.category_id = ui.category_id
        WHERE ui.user_id = ANY(:ids)
    """), {"ids": ids}).fetchall()

print(f"Leidos {len(users)} usuarios y {len(interests)} intereses de Postgres.")

# 2) Volcar al grafo Neo4j
with driver.session(database=s.neo4j_database) as ses:
    # Constraints (idempotentes)
    ses.run("CREATE CONSTRAINT usuario_id_unique IF NOT EXISTS "
            "FOR (u:Usuario) REQUIRE u.id IS UNIQUE")
    ses.run("CREATE CONSTRAINT etiqueta_nombre_unique IF NOT EXISTS "
            "FOR (e:Etiqueta) REQUIRE e.nombre IS UNIQUE")

    # Nodos Usuario (id como string para matchear las consultas de la API)
    ses.run("""
        UNWIND $rows AS r
        MERGE (u:Usuario {id: r.id})
        SET u.nombre_usuario = r.nombre, u.email = r.email
    """, rows=[{"id": str(u.user_id), "nombre": u.nombre, "email": u.email} for u in users])

    # Etiquetas + relaciones INTERESADO_EN
    ses.run("""
        UNWIND $rows AS r
        MERGE (e:Etiqueta {nombre: r.nombre})
        WITH r, e
        MATCH (u:Usuario {id: r.uid})
        MERGE (u)-[:INTERESADO_EN]->(e)
    """, rows=[{"uid": str(i.user_id), "nombre": i.nombre} for i in interests])

    # Amistades AMIGO_DE: usuarios que comparten >= 2 intereses (mutuas)
    res = ses.run("""
        MATCH (a:Usuario)-[:INTERESADO_EN]->(e:Etiqueta)<-[:INTERESADO_EN]-(b:Usuario)
        WHERE a.id < b.id
        WITH a, b, count(e) AS comunes
        WHERE comunes >= 2
        MERGE (a)-[:AMIGO_DE]->(b)
        MERGE (b)-[:AMIGO_DE]->(a)
        RETURN count(*) AS amistades
    """).single()
    print(f"Amistades AMIGO_DE generadas: {res['amistades']}")

driver.close()
print("✓ Grafo Neo4j sincronizado desde Postgres.")