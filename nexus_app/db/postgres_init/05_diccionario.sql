-- ============================================================
-- DICCIONARIO DE DATOS - NEXUS (VERSIÓN ACTUALIZADA 2026)
-- Este archivo documenta todas las tablas, triggers, índices 
-- y funciones del esquema relacional y de auditoría.
-- ============================================================

-- ============================================================
-- TABLA: users
-- Propósito: Almacena el perfil básico de cada usuario.
--            Las relaciones sociales (seguir/ser seguido) se gestionan en Neo4j.
-- ============================================================
COMMENT ON TABLE users IS
'Perfil básico de cada usuario registrado en el sistema. Incluye autenticación, datos personales y estado de la cuenta.';

COMMENT ON COLUMN users.user_id IS
'[PK] [SERIAL] Identificador único autoincremental del usuario.';

COMMENT ON COLUMN users.nombre IS
'[VARCHAR(100)] [NOT NULL] Nombre completo del usuario. Obligatorio para identificación.';

COMMENT ON COLUMN users.email IS
'[VARCHAR(255)] [NOT NULL] [UNIQUE] Dirección de correo electrónico. Debe ser única en todo el sistema. Se usa para autenticación y comunicaciones. Validado con CHECK constraint.';

COMMENT ON COLUMN users.contrasena_hash IS
'[VARCHAR(255)] [NOT NULL] Hash bcrypt de la contraseña del usuario. Nunca se almacena la contraseña en texto plano. Algoritmo: bcrypt (cost=12).';

COMMENT ON COLUMN users.bio IS
'[TEXT] [NULLABLE] Descripción libre del perfil del usuario. Moderada por trigger fn_moderar_bio() para evitar lenguaje discriminatorio.';

COMMENT ON COLUMN users.fecha_registro IS
'[TIMESTAMP] [NOT NULL] [DEFAULT NOW()] Fecha y hora en que se creó la cuenta. Se asigna automáticamente en la inserción.';

COMMENT ON COLUMN users.activo IS
'[BOOLEAN] [NOT NULL] [DEFAULT TRUE] Indica si la cuenta está activa. FALSE = borrado lógico: el registro se conserva pero el usuario no puede operar. Protegido por trigger fn_bloquear_inactivos().';

COMMENT ON COLUMN users.rol_id IS
'[INT] [NOT NULL] [DEFAULT 1] [FK → roles.rol_id] Rol asignado al usuario (RBAC). Por defecto rol_id=1 (usuario). Trigger trg_auditoria_admins registra cambios de rol.';

-- ============================================================
-- TABLA: roles
-- Propósito: Define los niveles de acceso jerárquicos (RBAC).
--            Cada usuario tiene asignado exactamente un rol.
-- ============================================================
COMMENT ON TABLE roles IS
'Catálogo de roles del sistema (Role-Based Access Control). Define los niveles de acceso jerárquicos: usuario (1), operador (2), administrador (3).';

COMMENT ON COLUMN roles.rol_id IS
'[PK] [SERIAL] Identificador único autoincremental del rol. Valores: 1=usuario, 2=operador, 3=administrador.';

COMMENT ON COLUMN roles.nombre IS
'[VARCHAR(50)] [NOT NULL] [UNIQUE] Nombre del rol. Valores posibles: "usuario", "operador", "administrador". Define permisos en lógica de aplicación.';

COMMENT ON COLUMN roles.descripcion IS
'[TEXT] [NULLABLE] Descripción de los permisos y responsabilidades asociados al rol (informativo).';

-- ============================================================
-- TABLA: categories
-- Propósito: Diccionario maestro de intereses/etiquetas disponibles en la aplicación.
--            Contiene 36 categorías predefinidas (Tecnología, Música, Viajes, etc.)
-- ============================================================
COMMENT ON TABLE categories IS
'Catálogo centralizado de 36 intereses o etiquetas disponibles en la plataforma. Ejemplos: "Tecnología", "Música", "Fotografía", "Viajes".';

COMMENT ON COLUMN categories.category_id IS
'[PK] [SERIAL] Identificador único autoincremental de la categoría.';

COMMENT ON COLUMN categories.nombre IS
'[VARCHAR(100)] [NOT NULL] [UNIQUE] Nombre descriptivo de la categoría (ej: "Inteligencia Artificial"). No puede repetirse.';

COMMENT ON COLUMN categories.descripcion IS
'[TEXT] [NULLABLE] Explicación extendida del alcance de la categoría. Opcional. Máximo 500 caracteres.';

COMMENT ON COLUMN categories.icono IS
'[VARCHAR(50)] [NULLABLE] Nombre del ícono FontAwesome asociado a la categoría en el frontend (ej: "laptop", "music", "plane", "robot").';

-- ============================================================
-- TABLA: photos
-- Propósito: Registra las fotos subidas por los usuarios.
--            Cada foto pertenece a exactamente un usuario.
--            Si el usuario se elimina, sus fotos se eliminan en cascada.
-- ============================================================
COMMENT ON TABLE photos IS
'Fotos subidas por los usuarios. Relacionada con users mediante clave foránea. Protegida por trigger fn_limite_fotos_perfil() que limita máximo 6 fotos por usuario y fn_bloquear_inactivos() que bloquea carga en cuentas inactivas.';

COMMENT ON COLUMN photos.photo_id IS
'[PK] [SERIAL] Identificador único autoincremental de la foto.';

COMMENT ON COLUMN photos.user_id IS
'[INT] [NOT NULL] [FK → users.user_id] Identifica al usuario que subió la foto. ON DELETE CASCADE: si se elimina el usuario, se eliminan todas sus fotos automáticamente.';

COMMENT ON COLUMN photos.url_imagen IS
'[TEXT] [NOT NULL] URL completa donde está alojada la imagen (ej: bucket S3, CDN, servidor estático). No se almacena el archivo binario en la BD. Ejemplo: "https://cdn.nexus.app/photos/sofia_franco_1.jpg".';

COMMENT ON COLUMN photos.descripcion IS
'[TEXT] [NULLABLE] Pie de foto o descripción opcional ingresada por el usuario. Máximo 500 caracteres.';

COMMENT ON COLUMN photos.fecha_subida IS
'[TIMESTAMP] [NOT NULL] [DEFAULT NOW()] Fecha y hora en que se subió la foto. Se asigna automáticamente en la inserción.';

-- ============================================================
-- TABLA: user_interests
-- Propósito: Tabla intermedia (relación N:M) que vincula usuarios con categorías de interés.
--            Un usuario puede tener 1-15 intereses. Una categoría puede interesarle a muchos usuarios.
-- ============================================================
COMMENT ON TABLE user_interests IS
'Relación muchos-a-muchos entre usuarios y categorías de interés. Incluye el nivel de afinidad del usuario con cada categoría (1-5). Protegida por trigger fn_limite_intereses() que limita máximo 15 intereses por usuario.';

COMMENT ON COLUMN user_interests.user_id IS
'[INT] [NOT NULL] [PK] [FK → users.user_id] Referencia al usuario. Parte de la clave primaria compuesta. ON DELETE CASCADE: elimina todos los intereses si se borra el usuario.';

COMMENT ON COLUMN user_interests.category_id IS
'[INT] [NOT NULL] [PK] [FK → categories.category_id] Referencia a la categoría. Parte de la clave primaria compuesta. ON DELETE CASCADE: elimina la vinculación si se borra la categoría.';

COMMENT ON COLUMN user_interests.nivel_interes IS
'[SMALLINT] [DEFAULT 1] [CHECK 1–5] Grado de afinidad del usuario con la categoría. Escala: 1=interés leve, 3=interés moderado, 5=interés muy alto. Usado para personalizar recomendaciones en ServicioRecomendaciones.';

COMMENT ON COLUMN user_interests.fecha_agregado IS
'[TIMESTAMP] [NOT NULL] [DEFAULT NOW()] Fecha en que el usuario registró este interés. Se asigna automáticamente. Útil para auditoría temporal.';

-- ============================================================
-- TABLA: historial_actividad  [PARTICIONADA POR RANGO]
-- Propósito: Registra cada acción que un usuario realiza dentro del sistema.
--            Particionada por mes sobre fecha_actividad para optimizar consultas temporales.
--            Rango cubierto: Enero 2025 - Diciembre 2026.
-- ============================================================
COMMENT ON TABLE historial_actividad IS
'Auditoría de acciones de usuarios. Tabla particionada por rango mensual sobre fecha_actividad. Cubre 2025-2026 con partición DEFAULT para fechas fuera de rango. Registra: LOGIN, LOGOUT, EDICION, DESCARGA, CARGA, ELIMINACION.';

COMMENT ON COLUMN historial_actividad.id IS
'[SERIAL] [NOT NULL] [PK parcial] Identificador autoincremental del registro. Forma la PK junto con fecha_actividad (requisito de PostgreSQL para tablas particionadas).';

COMMENT ON COLUMN historial_actividad.usuario_id IS
'[INTEGER] [NOT NULL] Identificador del usuario que realizó la acción. No tiene FK explícita para no restringir las particiones. Referencia lógica a users.user_id.';

COMMENT ON COLUMN historial_actividad.accion IS
'[VARCHAR(100)] [NOT NULL] Tipo de acción ejecutada. Valores esperados: "LOGIN", "LOGOUT", "EDICION", "DESCARGA", "CARGA", "ELIMINACION", "VER_PERFIL", "LIKE", "MATCH". Facilita análisis de actividad.';

COMMENT ON COLUMN historial_actividad.modulo IS
'[VARCHAR(60)] [NULLABLE] Módulo o sección del sistema donde ocurrió la acción (ej: "Autenticacion", "Fotos", "Recomendaciones", "Admin"). Organiza auditoría por funcionalidad.';

COMMENT ON COLUMN historial_actividad.ip_origen IS
'[VARCHAR(45)] [NULLABLE] Dirección IP desde la que se originó la acción. Acepta formato IPv4 (máx 15 chars) e IPv6 (máx 45 chars). Usada para detectar accesos sospechosos.';

COMMENT ON COLUMN historial_actividad.detalle IS
'[TEXT] [NULLABLE] Descripción libre con información adicional sobre la acción (ej: nombre del archivo descargado, campo editado, motivo de bloqueo). Máximo 2000 caracteres.';

COMMENT ON COLUMN historial_actividad.fecha_actividad IS
'[TIMESTAMP] [NOT NULL] [PK parcial] [CLAVE DE PARTICIÓN] Fecha y hora exacta en que ocurrió la acción. Define en qué partición mensual se almacena el registro. Formato: TIMESTAMP (con timezone en aplicación).';

-- ============================================================
-- TABLA: logs_conexiones  [PARTICIONADA POR RANGO]
-- Propósito: Registra cada intento de conexión (exitoso o fallido).
--            Particionada por mes sobre fecha_conexion para auditoría de seguridad.
--            Rango cubierto: Enero 2025 - Diciembre 2026.
-- ============================================================
COMMENT ON TABLE logs_conexiones IS
'Log de intentos de conexión al sistema (auditoría de seguridad). Tabla particionada por rango mensual sobre fecha_conexion (2025-2026). Permite detectar patrones de acceso, ataques de fuerza bruta y amenazas. Incluye partición DEFAULT para fechas fuera de rango.';

COMMENT ON COLUMN logs_conexiones.id IS
'[SERIAL] [NOT NULL] [PK parcial] Identificador autoincremental del log. Forma la PK junto con fecha_conexion (requisito de PostgreSQL para tablas particionadas).';

COMMENT ON COLUMN logs_conexiones.usuario_id IS
'[INTEGER] [NULLABLE] Identificador del usuario que intentó conectarse. NULL si el intento fue anónimo, si no se pudo identificar, o si falló la autenticación inicial.';

COMMENT ON COLUMN logs_conexiones.tipo_evento IS
'[VARCHAR(30)] [NOT NULL] Resultado del intento de conexión. Valores posibles: "EXITOSA" (LOGIN OK), "FALLIDA" (credenciales incorrectas), "TIMEOUT" (conexión expiró), "BLOQUEADA" (IP en lista negra, cuenta suspendida).';

COMMENT ON COLUMN logs_conexiones.ip_origen IS
'[VARCHAR(45)] [NOT NULL] Dirección IP desde la que se originó el intento. Obligatoria para auditoría de seguridad. Acepta IPv4 (ej: 192.168.1.1) e IPv6 (ej: 2001:0db8:85a3::8a2e:0370:7334).';

COMMENT ON COLUMN logs_conexiones.user_agent IS
'[VARCHAR(255)] [NULLABLE] Cadena del agente de usuario del cliente HTTP (navegador, app mobile, script, bot). Útil para detectar clientes inusuales, bots maliciosos o vulnerabilidades de navegador.';

COMMENT ON COLUMN logs_conexiones.duracion_ms IS
'[INTEGER] [NULLABLE] Duración de la sesión en milisegundos. Solo aplica a conexiones EXITOSAS (tipo_evento="EXITOSA"). NULL para intentos fallidos, bloqueados o con timeout. Útil para detectar sesiones inusualmente largas.';

COMMENT ON COLUMN logs_conexiones.fecha_conexion IS
'[TIMESTAMP] [NOT NULL] [PK parcial] [CLAVE DE PARTICIÓN] Fecha y hora exacta del intento de conexión. Define en qué partición mensual se almacena el registro. Crítica para auditoría temporal.';

-- ============================================================
-- TABLA: auditoria_emails
-- Propósito: Registra automáticamente (via trigger trg_auditar_email) cada cambio de email.
--            Garantiza trazabilidad de cambios en datos críticos de autenticación.
--            Esta tabla se llena automáticamente, NUNCA se escribe manualmente.
-- ============================================================
COMMENT ON TABLE auditoria_emails IS
'Tabla de auditoría para cambios de email. Se llena automáticamente mediante el trigger trg_auditar_email cada vez que un usuario actualiza su email. Garantiza conformidad RGPD y trazabilidad de cambios en datos de autenticación.';

COMMENT ON COLUMN auditoria_emails.auditoria_id IS
'[PK] [SERIAL] Identificador único autoincremental del registro de auditoría de email.';

COMMENT ON COLUMN auditoria_emails.user_id IS
'[INT] [NOT NULL] [FK → users.user_id (implícita)] ID del usuario que cambió su email. Referencia lógica a users.user_id (sin constraint para no serializar auditoría).';

COMMENT ON COLUMN auditoria_emails.email_anterior IS
'[VARCHAR(320)] [NULLABLE] Valor anterior del email antes del cambio. Puede ser NULL si el registro es nuevo. Acepta RFC-5321 (máx 320 chars).';

COMMENT ON COLUMN auditoria_emails.email_nuevo IS
'[VARCHAR(320)] [NULLABLE] Nuevo valor del email después del cambio. Puede ser NULL en teóricos casos de eliminación. Acepta RFC-5321 (máx 320 chars).';

COMMENT ON COLUMN auditoria_emails.fecha_cambio IS
'[TIMESTAMPTZ] [NOT NULL] [DEFAULT CURRENT_TIMESTAMP] Fecha y hora exacta en que ocurrió el cambio de email. Incluye zona horaria para precisión global.';

-- ============================================================
-- TABLA: auditoria_admins
-- Propósito: Registra automáticamente (via trigger trg_auditoria_admins) cada cambio
--            realizado por un administrador sobre datos de otros usuarios.
--            Garantiza trazabilidad completa de operaciones RBAC (rol_id, activo, etc.).
--            Esta tabla nunca se escribe manualmente.
-- ============================================================
COMMENT ON TABLE auditoria_admins IS
'Tabla de trazabilidad RBAC. Se llena automáticamente mediante el trigger trg_auditoria_admins cada vez que un administrador modifica datos sensibles de otro usuario (rol_id, activo, etc.). Garantiza conformidad GDPR y auditoría de operaciones administrativas.';

COMMENT ON COLUMN auditoria_admins.auditoria_id IS
'[PK] [SERIAL] Identificador único autoincremental del registro de auditoría.';

COMMENT ON COLUMN auditoria_admins.fecha_hora IS
'[TIMESTAMPTZ] [NOT NULL] [DEFAULT CURRENT_TIMESTAMP] Fecha y hora exacta en que ocurrió la modificación. Incluye zona horaria para precisión global y auditoría temporal.';

COMMENT ON COLUMN auditoria_admins.admin_user_id IS
'[INT] [NOT NULL] ID del administrador que realizó el cambio. Referencia lógica a users.user_id (sin constraint para no serializar auditoría).';

COMMENT ON COLUMN auditoria_admins.usuario_id IS
'[INT] [NOT NULL] ID del usuario cuyos datos fueron modificados. Referencia lógica a users.user_id. Permite rastrear quién fue afectado por cambios administrativos.';

COMMENT ON COLUMN auditoria_admins.campo_modificado IS
'[VARCHAR(100)] [NULLABLE] Nombre de la columna que fue modificada. Ejemplos: "email", "rol_id", "activo", "bio", "nombre". Facilita filtrado de auditoría por tipo de cambio.';

COMMENT ON COLUMN auditoria_admins.valor_anterior IS
'[TEXT] [NULLABLE] Valor que tenía el campo antes de la modificación. Permite comparación y reversión de cambios. Almacenado como TEXT para flexibilidad de tipos.';

COMMENT ON COLUMN auditoria_admins.valor_nuevo IS
'[TEXT] [NULLABLE] Valor que quedó en el campo después de la modificación. Permite rastrear el cambio exacto realizado. Almacenado como TEXT para flexibilidad de tipos.';

-- ============================================================
-- FUNCIONES Y TRIGGERS - DOCUMENTACIÓN
-- ============================================================

COMMENT ON FUNCTION fn_auditar_cambio_email IS
'[TRIGGER FUNCTION] Se ejecuta AFTER UPDATE OF email ON users. Registra automáticamente en auditoria_emails cada cambio de email. Comparación con IS DISTINCT FROM evita ruido si el email no cambió. Lanzado por trigger trg_auditar_email.';

COMMENT ON FUNCTION fn_limite_fotos_perfil IS
'[TRIGGER FUNCTION] Se ejecuta BEFORE INSERT ON photos. Implementa regla de negocio: máximo 6 fotos por usuario. Usa FOR UPDATE para evitar race conditions. Si se excede el límite, lanza excepción ''P0001''. Lanzado por trigger trg_limite_fotos.';

COMMENT ON FUNCTION fn_moderar_bio IS
'[TRIGGER FUNCTION] Se ejecuta BEFORE INSERT OR UPDATE OF bio ON users (si bio IS NOT NULL). Filtra palabras discriminatorias/prejuiciosas usando regex (~*). Lanza excepción si detecta: feo, gord*, flac*, horrible, asqueros*. Fomenta comunidad ética. Lanzado por trigger trg_moderar_bio.';

COMMENT ON FUNCTION fn_limite_intereses IS
'[TRIGGER FUNCTION] Se ejecuta BEFORE INSERT ON user_interests. Implementa regla anti-spam: máximo 15 intereses por usuario. Usa FOR UPDATE para evitar race conditions. Si se excede el límite, lanza excepción ''P0001''. Lanzado por trigger trg_limite_intereses.';

COMMENT ON FUNCTION fn_bloquear_inactivos IS
'[TRIGGER FUNCTION] Se ejecuta BEFORE INSERT ON photos. Bloquea operaciones de usuarios inactivos (activo=FALSE). Verifica estado del usuario con FOR SHARE para no entorpecer transacciones paralelas. Lanza excepción si activo!=TRUE. Lanzado por trigger trg_bloquear_fotos_inactivos.';

-- Triggers
COMMENT ON TRIGGER trg_auditar_email ON users IS
'Trigger: Audita cambios de email. AFTER UPDATE OF email → fn_auditar_cambio_email() → auditoria_emails.';

COMMENT ON TRIGGER trg_limite_fotos ON photos IS
'Trigger: Enforce límite de 6 fotos por usuario. BEFORE INSERT → fn_limite_fotos_perfil() → excepción si user_id ya tiene 6+ fotos.';

COMMENT ON TRIGGER trg_moderar_bio ON users IS
'Trigger: Modera contenido de bio. BEFORE INSERT OR UPDATE OF bio → fn_moderar_bio() → excepción si contiene lenguaje discriminatorio.';

COMMENT ON TRIGGER trg_limite_intereses ON user_interests IS
'Trigger: Enforce límite de 15 intereses por usuario (anti-spam). BEFORE INSERT → fn_limite_intereses() → excepción si user_id ya tiene 15 intereses.';

COMMENT ON TRIGGER trg_bloquear_fotos_inactivos ON photos IS
'Trigger: Bloquea cargas de fotos de usuarios inactivos. BEFORE INSERT → fn_bloquear_inactivos() → excepción si usuario.activo=FALSE.';

-- ============================================================
-- RESUMEN DE ÍNDICES DEL ESQUEMA
-- ============================================================

COMMENT ON INDEX idx_photos_user_id IS
'[B-TREE] Acelera búsqueda de todas las fotos de un usuario. Consulta muy frecuente en perfiles. Columna: photos(user_id).';

COMMENT ON INDEX idx_ui_user_id IS
'[B-TREE] Acelera búsqueda de todos los intereses de un usuario. Usado en recomendaciones. Columna: user_interests(user_id).';

COMMENT ON INDEX idx_ui_category_id IS
'[B-TREE] Acelera búsqueda de todos los usuarios que tienen cierto interés. Usado en recomendaciones. Columna: user_interests(category_id).';

COMMENT ON INDEX idx_users_email IS
'[B-TREE] Acelera autenticación por email (login critical). Clave para el proceso de login. Columna: users(email).';

COMMENT ON INDEX idx_users_nombre IS
'[B-TREE] Acelera búsqueda de usuarios por nombre completo. Columna: users(nombre).';

COMMENT ON INDEX idx_users_fecha_registro IS
'[B-TREE] Acelera análisis de registros por fecha. Útil para auditoría temporal y análisis de crecimiento. Columna: users(fecha_registro).';

COMMENT ON INDEX idx_users_activos IS
'[PARTIAL+COVERING] Índice parcial en usuarios activos (activo=TRUE). Incluye nombre y bio. Optimiza búsquedas de usuarios activos. Columns: users(user_id) WHERE activo=TRUE, INCLUDE (nombre, bio).';

COMMENT ON INDEX idx_user_interests_busqueda IS
'[B-TREE COMPOSITE] Índice compuesto para recomendaciones. Optimiza búsquedas por categoría con ordenamiento por nivel_interes. Columns: user_interests(category_id, nivel_interes).';

COMMENT ON INDEX idx_auditoria_emails_user_id IS
'[B-TREE] Acelera búsqueda de historial de cambios de email por usuario. Columna: auditoria_emails(user_id).';

-- ============================================================
-- CONSTRAINTS Y VALIDACIONES
-- ============================================================

COMMENT ON CONSTRAINT ck_email_valido ON users IS
'[CHECK] Valida que email contenga al menos un @. Formato básico RFC-5321 completo se valida en aplicación.';

-- ============================================================
-- VERIFICACIÓN FINAL: CONSULTA DE INTEGRIDAD
-- ============================================================

/*
SELECT
    cols.table_name                             AS tabla,
    cols.column_name                            AS columna,
    cols.data_type                              AS tipo,
    cols.is_nullable                            AS acepta_null,
    pg_catalog.col_description(
        (cols.table_schema || '.' || cols.table_name)::regclass::oid,
        cols.ordinal_position
    )                                           AS descripcion
FROM information_schema.columns cols
WHERE cols.table_schema = 'public'
    AND cols.table_name IN (
    'users', 'roles', 'categories', 'photos', 'user_interests',
    'historial_actividad', 'logs_conexiones', 'auditoria_emails', 'auditoria_admins'
)
ORDER BY cols.table_name, cols.ordinal_position;
*/
