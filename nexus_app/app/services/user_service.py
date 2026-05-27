import os           
import bcrypt       # Para hashear contraseñas de forma segura
import psycopg2     # Driver para conectarse a PostgreSQL desde Python
from psycopg2.extras import RealDictCursor  # Para que los resultados vengan como diccionarios


# ============================================================
# CONEXIÓN A LA BASE DE DATOS: Las credenciales se leen de variables de entorno, nunca
# escritas directamente en el código (tema: Seguridad).
# ============================================================

def get_connection():
    """
    Crea y devuelve una conexión a PostgreSQL.
    Lee las credenciales desde variables de entorno (.env).
    """
    return psycopg2.connect(
        host=os.getenv("POSTGRES_HOST", "localhost"),
        port=os.getenv("POSTGRES_PORT", 5432),
        dbname=os.getenv("POSTGRES_DB", "nexus_db"),
        user=os.getenv("POSTGRES_USER", "postgres"),
        password=os.getenv("POSTGRES_PASSWORD")  # Sin valor por defecto: obliga a configurarla
    )


# ============================================================
# FUNCIÓN: crear_usuario Inserta un usuario nuevo en la base de datos.
# Usa transacción: si algo falla, no se guarda nada (rollback).
# ============================================================

def crear_usuario(nombre: str, email: str, contrasena: str, bio: str = None) -> dict:
    """
    Crea un usuario nuevo en PostgreSQL.
    - Hashea la contraseña antes de guardarla (nunca texto plano).
    - Usa consulta parametrizada para evitar SQL Injection.
    - Usa transacción: si falla, hace rollback automático.

    Retorna el usuario creado como diccionario, o None si el email ya existe.
    """

    # Hashear la contraseña con bcrypt (genera un hash distinto cada vez)
    salt = bcrypt.gensalt()
    contrasena_hash = bcrypt.hashpw(contrasena.encode("utf-8"), salt).decode("utf-8")

    sql = """
        INSERT INTO users (nombre, email, contrasena_hash, bio)
        VALUES (%s, %s, %s, %s)
        RETURNING user_id, nombre, email, bio, fecha_registro;
    """
    # RETURNING hace que PostgreSQL devuelva el registro recién creado

    conn = None
    try:
        conn = get_connection()
        with conn:  # 'with conn' maneja la transacción automáticamente
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                cur.execute(sql, (nombre, email, contrasena_hash, bio))
                usuario = cur.fetchone()
                return dict(usuario)

    except psycopg2.errors.UniqueViolation:
        # El email ya existe en la base de datos
        print(f"Error: el email '{email}' ya está registrado.")
        return None

    except Exception as e:
        print(f"Error inesperado al crear usuario: {e}")
        return None

    finally:
        if conn:
            conn.close()  # Siempre cerramos la conexión


# ============================================================
# FUNCIÓN: obtener_usuario. Busca un usuario por su ID.
# ============================================================

def obtener_usuario(user_id: int) -> dict:
    """
    Busca y retorna un usuario por su ID.
    No devuelve el hash de la contraseña por seguridad.
    """

    sql = """
        SELECT user_id, nombre, email, bio, fecha_registro, activo
        FROM users
        WHERE user_id = %s AND activo = TRUE;
    """

    conn = None
    try:
        conn = get_connection()
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(sql, (user_id,))  # La coma es necesaria para que sea una tupla
            usuario = cur.fetchone()
            return dict(usuario) if usuario else None

    except Exception as e:
        print(f"Error al obtener usuario {user_id}: {e}")
        return None

    finally:
        if conn:
            conn.close()


# ============================================================
# FUNCIÓN: obtener_por_email. Busca un usuario por email (se usa en el login).
# Aprovecha el índice idx_users_email creado en el schema.
# ============================================================

def obtener_por_email(email: str) -> dict:
    """
    Busca un usuario por su email.
    Se usa principalmente para el inicio de sesión.
    Aprovecha el índice idx_users_email para búsqueda rápida.
    """

    sql = """
        SELECT user_id, nombre, email, contrasena_hash, bio, fecha_registro
        FROM users
        WHERE email = %s AND activo = TRUE;
    """

    conn = None
    try:
        conn = get_connection()
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(sql, (email,))
            usuario = cur.fetchone()
            return dict(usuario) if usuario else None

    except Exception as e:
        print(f"Error al buscar usuario por email: {e}")
        return None

    finally:
        if conn:
            conn.close()


# ============================================================
# FUNCIÓN: verificar_contrasena Compara la contraseña ingresada con el hash guardado.
# Se usa junto con obtener_por_email() para el login.
# ============================================================

def verificar_contrasena(contrasena_ingresada: str, hash_guardado: str) -> bool:
    """
    Verifica si la contraseña ingresada coincide con el hash.
    bcrypt.checkpw() compara de forma segura sin exponer el hash.
    """
    return bcrypt.checkpw(
        contrasena_ingresada.encode("utf-8"),
        hash_guardado.encode("utf-8")
    )


# ============================================================
# FUNCIÓN: actualizar_bio Modifica la bio de un usuario. Usa transacción.
# ============================================================

def actualizar_bio(user_id: int, nueva_bio: str) -> dict:
    """
    Actualiza la bio de un usuario existente.
    Retorna el usuario actualizado, o None si no existe.
    """

    sql = """
        UPDATE users
        SET bio = %s
        WHERE user_id = %s AND activo = TRUE
        RETURNING user_id, nombre, email, bio;
    """

    conn = None
    try:
        conn = get_connection()
        with conn:  # Transacción automática
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                cur.execute(sql, (nueva_bio, user_id))
                usuario = cur.fetchone()
                return dict(usuario) if usuario else None

    except Exception as e:
        print(f"Error al actualizar bio del usuario {user_id}: {e}")
        return None

    finally:
        if conn:
            conn.close()


# ============================================================
# FUNCIÓN: listar_usuarios Trae todos los usuarios activos con paginación.
# ============================================================

def listar_usuarios(limite: int = 20, offset: int = 0) -> list:
    """
    Lista usuarios activos con paginación.
    - limite: cuántos usuarios traer (por defecto 20)
    - offset: desde qué posición empezar (para paginar)

    Ejemplo: página 2 con 20 por página → limite=20, offset=20
    """

    sql = """
        SELECT user_id, nombre, email, bio, fecha_registro
        FROM users
        WHERE activo = TRUE
        ORDER BY fecha_registro DESC
        LIMIT %s OFFSET %s;
    """

    conn = None
    try:
        conn = get_connection()
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(sql, (limite, offset))
            usuarios = cur.fetchall()
            return [dict(u) for u in usuarios]

    except Exception as e:
        print(f"Error al listar usuarios: {e}")
        return []

    finally:
        if conn:
            conn.close()


# ============================================================
# FUNCIÓN: desactivar_usuario Borrado lógico: no elimina la fila, solo marca activo=FALSE.
# Esto preserva la integridad de los datos históricos.
# ============================================================

def desactivar_usuario(user_id: int) -> bool:
    """
    Desactiva un usuario (borrado lógico).
    No se elimina el registro, solo se marca como inactivo.
    Esto preserva el historial y evita romper relaciones en Neo4j.
    Retorna True si se desactivó correctamente, False si no.
    """

    sql = """
        UPDATE users
        SET activo = FALSE
        WHERE user_id = %s AND activo = TRUE;
    """

    conn = None
    try:
        conn = get_connection()
        with conn:  # Transacción automática
            with conn.cursor() as cur:
                cur.execute(sql, (user_id,))
                # rowcount indica cuántas filas fueron afectadas
                return cur.rowcount > 0

    except Exception as e:
        print(f"Error al desactivar usuario {user_id}: {e}")
        return False

    finally:
        if conn:
            conn.close()