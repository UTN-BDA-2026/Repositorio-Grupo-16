"""
==============================================================
MIGRACIÓN PostgreSQL → MongoDB — PROYECTO NEXUS (Grupo 16)
==============================================================
Ubicación: Repositorio-Grupo-16/migracion_mongo/migrar.py
Requiere:  pip install psycopg2-binary pymongo python-dotenv
Uso:       python migrar.py
==============================================================
"""

import os
import sys
from datetime import datetime, date
from pathlib import Path


def _a_datetime(v):
    """BSON no encodea datetime.date; lo convertimos a datetime (medianoche)."""
    if isinstance(v, date) and not isinstance(v, datetime):
        return datetime(v.year, v.month, v.day)
    return v
from dotenv import load_dotenv

# Intenta cargar .env.mongo, pero no falla si tiene problemas de encoding
try:
    load_dotenv(dotenv_path=Path(__file__).parent / ".env.mongo", encoding="latin-1")
except Exception:
    pass

try:
    import psycopg2
    import psycopg2.extras
except ImportError:
    print("ERROR: Falta psycopg2. Ejecutá: pip install psycopg2-binary")
    sys.exit(1)

try:
    from pymongo import MongoClient, ASCENDING, DESCENDING
    from pymongo.errors import BulkWriteError
except ImportError:
    print("ERROR: Falta pymongo. Ejecutá: pip install pymongo")
    sys.exit(1)

# ── Configuración ─────────────────────────────────────────────
PG_CONFIG = {
    "host":     os.getenv("POSTGRES_HOST", "localhost"),
    "port":     int(os.getenv("POSTGRES_PORT", 5432)),
    "dbname":   os.getenv("POSTGRES_DB",   "nexus_db"),
    "user":     os.getenv("POSTGRES_USER", "nexus_user"),
    "password": os.getenv("POSTGRES_PASSWORD", "nexus_desarrollo_123"),
}

MONGO_URI = os.getenv("MONGO_URI", "mongodb://localhost:27017")
MONGO_DB  = os.getenv("MONGO_DB",  "nexus_mongo")
BATCH     = 500


# ══════════════════════════════════════════════════════════════
# PASO 1 — Conectar
# ══════════════════════════════════════════════════════════════
def conectar():
    print("\n[1/5] Conectando a PostgreSQL y MongoDB...")

    try:
        pg = psycopg2.connect(**PG_CONFIG)
        pg.autocommit = True
        print(f"  ✓ PostgreSQL → {PG_CONFIG['host']}:{PG_CONFIG['port']}/{PG_CONFIG['dbname']}")
    except Exception as e:
        print(f"  ✗ Error PostgreSQL: {e}")
        print("    Verificá que los contenedores estén arriba: docker compose ps")
        sys.exit(1)

    try:
        client = MongoClient(MONGO_URI, serverSelectionTimeoutMS=5000)
        client.server_info()
        mongo = client[MONGO_DB]
        print(f"  ✓ MongoDB → {MONGO_URI}/{MONGO_DB}")
    except Exception as e:
        print(f"  ✗ Error MongoDB: {e}")
        print("    Verificá que el contenedor nexus-mongodb esté corriendo.")
        sys.exit(1)

    return pg, mongo


# ══════════════════════════════════════════════════════════════
# PASO 2 — Leer PostgreSQL
# IMPORTANTE: la tabla 'users' tiene la columna 'nombre' (SQL)
# que el ORM expone como 'nombre_usuario'. Usamos el nombre SQL real.
# ══════════════════════════════════════════════════════════════
def leer_postgres(pg):
    print("\n[2/5] Leyendo datos de PostgreSQL...")
    cur = pg.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

    # Usuarios: columna real es 'nombre', alias como 'nombre_usuario'
    cur.execute("""
        SELECT
            u.user_id,
            u.nombre        AS nombre_usuario,
            u.email,
            u.contrasena_hash,
            u.bio,
            u.fecha_creacion AS fecha_registro,
            u.activo,
            u.fecha_nacimiento,
            r.nombre        AS rol_nombre
        FROM users u
        LEFT JOIN roles r ON r.rol_id = u.rol_id
        ORDER BY u.user_id
    """)
    usuarios = cur.fetchall()
    print(f"  • {len(usuarios)} usuarios")

    # Fotos agrupadas por user_id
    cur.execute("""
        SELECT photo_id, user_id, url_imagen, descripcion, fecha_subida
        FROM photos
        ORDER BY user_id, fecha_subida
    """)
    fotos_por_usuario = {}
    for f in cur.fetchall():
        fotos_por_usuario.setdefault(f["user_id"], []).append({
            "photo_id":    f["photo_id"],
            "url_imagen":  f["url_imagen"],
            "descripcion": f["descripcion"],
            "fecha_subida": f["fecha_subida"],
        })
    total_fotos = sum(len(v) for v in fotos_por_usuario.values())
    print(f"  • {total_fotos} fotos")

    # Intereses agrupados por user_id
    cur.execute("""
        SELECT ui.user_id, ui.category_id, c.nombre AS categoria_nombre,
            ui.nivel_interes, ui.fecha_agregado
        FROM user_interests ui
        JOIN categories c ON c.category_id = ui.category_id
        ORDER BY ui.user_id
    """)
    intereses_por_usuario = {}
    for i in cur.fetchall():
        intereses_por_usuario.setdefault(i["user_id"], []).append({
            "category_id":      i["category_id"],
            "categoria_nombre": i["categoria_nombre"],
            "nivel_interes":    i["nivel_interes"],
            "fecha_agregado":   i["fecha_agregado"],
        })
    total_intereses = sum(len(v) for v in intereses_por_usuario.values())
    print(f"  • {total_intereses} intereses")

    # Categorías
    cur.execute("SELECT category_id, nombre, descripcion, icono FROM categories ORDER BY category_id")
    categorias = cur.fetchall()
    print(f"  • {len(categorias)} categorías")

    # Historial (tabla particionada → se lee igual, PG unifica particiones automáticamente)
    cur.execute("""
        SELECT id, usuario_id, accion, modulo, ip_origen, detalle, fecha_actividad
        FROM historial_actividad
        ORDER BY fecha_actividad
    """)
    historial = cur.fetchall()
    print(f"  • {len(historial)} registros de historial_actividad")

    # Logs (tabla particionada)
    cur.execute("""
        SELECT id, usuario_id, tipo_evento, ip_origen, user_agent, duracion_ms, fecha_conexion
        FROM logs_conexiones
        ORDER BY fecha_conexion
    """)
    logs = cur.fetchall()
    print(f"  • {len(logs)} registros de logs_conexiones")

    cur.close()
    return usuarios, fotos_por_usuario, intereses_por_usuario, categorias, historial, logs


# ══════════════════════════════════════════════════════════════
# PASO 3 — Transformar al modelo de documentos MongoDB
#
# Decisiones de diseño:
#   usuarios       → embedding de fotos e intereses (se acceden juntos siempre)
#   categorias     → colección separada (datos maestros, referenciados)
#   historial      → colección separada (crece mucho, se consulta aparte)
#   logs           → colección separada (igual razón)
#   anio/mes       → campos extra para filtrar sin particiones (reemplaza partition pruning de PG)
# ══════════════════════════════════════════════════════════════
def transformar(usuarios, fotos_por_usuario, intereses_por_usuario, categorias, historial, logs):
    print("\n[3/5] Transformando al modelo de documentos...")

    docs_usuarios = []
    for u in usuarios:
        uid = u["user_id"]
        docs_usuarios.append({
            "_id":             uid,          # mismo ID que PG para trazabilidad
            "postgres_id":     uid,
            "nombre_usuario":  u["nombre_usuario"],
            "email":           u["email"],
            "contrasena_hash": u["contrasena_hash"],
            "bio":             u["bio"],
            "activo":          u["activo"],
            "fecha_nacimiento": _a_datetime(u["fecha_nacimiento"]),
            "fecha_registro":  u["fecha_registro"],
            "rol":             u["rol_nombre"] or "usuario",
            # Subdocumentos embebidos (antes eran tablas separadas en PG)
            "fotos":           fotos_por_usuario.get(uid, []),
            "intereses":       intereses_por_usuario.get(uid, []),
            "_migrado_en":     datetime.utcnow(),
            "_origen":         "postgresql",
        })

    docs_categorias = []
    for c in categorias:
        docs_categorias.append({
            "_id":         c["category_id"],
            "postgres_id": c["category_id"],
            "nombre":      c["nombre"],
            "descripcion": c["descripcion"],
            "icono":       c["icono"],
            "_migrado_en": datetime.utcnow(),
        })

    docs_historial = []
    for h in historial:
        docs_historial.append({
            "postgres_id":     h["id"],
            "usuario_id":      h["usuario_id"],
            "accion":          h["accion"],
            "modulo":          h["modulo"],
            "ip_origen":       h["ip_origen"],
            "detalle":         h["detalle"],
            "fecha_actividad": h["fecha_actividad"],
            # Reemplaza el partition pruning: filtramos por anio/mes en Mongo
            "anio": h["fecha_actividad"].year  if h["fecha_actividad"] else None,
            "mes":  h["fecha_actividad"].month if h["fecha_actividad"] else None,
            "_migrado_en": datetime.utcnow(),
        })

    docs_logs = []
    for l in logs:
        docs_logs.append({
            "postgres_id":    l["id"],
            "usuario_id":     l["usuario_id"],
            "tipo_evento":    l["tipo_evento"],
            "ip_origen":      l["ip_origen"],
            "user_agent":     l["user_agent"],
            "duracion_ms":    l["duracion_ms"],
            "fecha_conexion": l["fecha_conexion"],
            "anio": l["fecha_conexion"].year  if l["fecha_conexion"] else None,
            "mes":  l["fecha_conexion"].month if l["fecha_conexion"] else None,
            "_migrado_en": datetime.utcnow(),
        })

    print(f"  ✓ {len(docs_usuarios)} usuarios | {len(docs_categorias)} categorías | "
          f"{len(docs_historial)} historial | {len(docs_logs)} logs")
    return docs_usuarios, docs_categorias, docs_historial, docs_logs


# ══════════════════════════════════════════════════════════════
# PASO 4 — Insertar en MongoDB
# ══════════════════════════════════════════════════════════════
def insertar_lote(col, docs, nombre):
    if not docs:
        print(f"  ⚠ Sin datos para '{nombre}'")
        return 0
    total = 0
    for i in range(0, len(docs), BATCH):
        lote = docs[i:i + BATCH]
        try:
            res = col.insert_many(lote, ordered=False)
            total += len(res.inserted_ids)
        except BulkWriteError as e:
            total += e.details.get("nInserted", 0)
            n_err = len(e.details.get("writeErrors", []))
            print(f"    ⚠ {n_err} duplicados ignorados en '{nombre}'")
    return total


def insertar_mongo(mongo, docs_u, docs_c, docs_h, docs_l):
    print("\n[4/5] Insertando en MongoDB...")

    for nombre_col in ["usuarios", "categorias", "historial_actividad", "logs_conexiones"]:
        mongo[nombre_col].drop()

    n_u = insertar_lote(mongo["usuarios"],            docs_u, "usuarios")
    n_c = insertar_lote(mongo["categorias"],          docs_c, "categorias")
    n_h = insertar_lote(mongo["historial_actividad"], docs_h, "historial_actividad")
    n_l = insertar_lote(mongo["logs_conexiones"],     docs_l, "logs_conexiones")

    print(f"  ✓ Insertados: {n_u} usuarios | {n_c} categorías | {n_h} historial | {n_l} logs")


# ══════════════════════════════════════════════════════════════
# PASO 5 — Crear índices (equivalentes a los de PostgreSQL)
# ══════════════════════════════════════════════════════════════
def crear_indices(mongo):
    print("\n[5/5] Creando índices...")

    col = mongo["usuarios"]
    col.create_index([("email", ASCENDING)],           unique=True, name="idx_email_unique")
    col.create_index([("activo", ASCENDING)],          name="idx_activo")
    col.create_index([("rol", ASCENDING)],             name="idx_rol")
    col.create_index([("fecha_registro", DESCENDING)], name="idx_fecha_registro")
    col.create_index([("intereses.categoria_nombre", ASCENDING)], name="idx_intereses_categoria")
    print("  ✓ usuarios")

    col = mongo["categorias"]
    col.create_index([("nombre", ASCENDING)], unique=True, name="idx_nombre_unique")
    print("  ✓ categorias")

    col = mongo["historial_actividad"]
    col.create_index([("usuario_id", ASCENDING)],          name="idx_usuario_id")
    col.create_index([("fecha_actividad", DESCENDING)],    name="idx_fecha_actividad")
    col.create_index([("anio", ASCENDING), ("mes", ASCENDING)], name="idx_anio_mes")
    col.create_index([("accion", ASCENDING)],              name="idx_accion")
    print("  ✓ historial_actividad")

    col = mongo["logs_conexiones"]
    col.create_index([("usuario_id", ASCENDING)],          name="idx_usuario_id")
    col.create_index([("fecha_conexion", DESCENDING)],     name="idx_fecha_conexion")
    col.create_index([("tipo_evento", ASCENDING)],         name="idx_tipo_evento")
    col.create_index([("anio", ASCENDING), ("mes", ASCENDING)], name="idx_anio_mes")
    col.create_index([("ip_origen", ASCENDING)],           name="idx_ip_origen")
    print("  ✓ logs_conexiones")


# ══════════════════════════════════════════════════════════════
# VERIFICACIÓN FINAL
# ══════════════════════════════════════════════════════════════
def verificar(mongo):
    print("\n" + "="*60)
    print("VERIFICACIÓN FINAL")
    print("="*60)

    for nombre_col in ["usuarios", "categorias", "historial_actividad", "logs_conexiones"]:
        total = mongo[nombre_col].count_documents({})
        print(f"  Colección '{nombre_col}': {total} documentos")

    usuario = mongo["usuarios"].find_one({}, {"contrasena_hash": 0})
    if usuario:
        print(f"\n  Ejemplo de documento usuario:")
        print(f"    nombre_usuario : {usuario.get('nombre_usuario')}")
        print(f"    email          : {usuario.get('email')}")
        print(f"    rol            : {usuario.get('rol')}")
        print(f"    fotos          : {len(usuario.get('fotos', []))} embebidas")
        print(f"    intereses      : {len(usuario.get('intereses', []))} embebidos")

    activos = mongo["usuarios"].count_documents({"activo": True, "intereses.0": {"$exists": True}})
    print(f"\n  Usuarios activos con al menos 1 interés: {activos}")

    logs_fallidos = mongo["logs_conexiones"].count_documents(
        {"tipo_evento": "FALLIDA", "anio": {"$gte": 2023}}
    )
    print(f"  Logs FALLIDA desde 2023: {logs_fallidos}")

    print("\n" + "="*60)
    print("✓ MIGRACIÓN COMPLETADA EXITOSAMENTE")
    print("="*60)
    print(f"\n  Para explorar los datos abrí MongoDB Compass y conectate a:")
    print(f"  {MONGO_URI}  →  base de datos: {MONGO_DB}\n")


# ══════════════════════════════════════════════════════════════
# MAIN
# ══════════════════════════════════════════════════════════════
if __name__ == "__main__":
    print("="*60)
    print("  MIGRACIÓN PostgreSQL → MongoDB — Nexus Grupo 16")
    print("="*60)

    pg, mongo = conectar()

    usuarios, fotos_por_usuario, intereses_por_usuario, categorias, historial, logs = leer_postgres(pg)
    docs_u, docs_c, docs_h, docs_l = transformar(
        usuarios, fotos_por_usuario, intereses_por_usuario, categorias, historial, logs
    )
    insertar_mongo(mongo, docs_u, docs_c, docs_h, docs_l)
    crear_indices(mongo)
    verificar(mongo)

    pg.close()