-- Diccionario de Datos
-- Este archivo documenta todas las tablas del esquema relacional
-- definido en 01_schema.sql. Para cada columna se especifica:
--   · Tipo de dato
--   · Restricciones
--   · Descripción funcional
-- ============================================================
-- TABLA: users
-- Propósito: Almacena el perfil básico de cada usuario.
--            Las relaciones sociales (seguir/ser seguido) se gestionan en Neo4j, no en esta tabla.
-- ============================================================
COMMENT ON TABLE users IS
'Perfil básico de cada usuario registrado en el sistema.';

COMMENT ON COLUMN users.user_id IS
'[PK] [SERIAL] Identificador único autoincremental del usuario.';

COMMENT ON COLUMN users.nombre IS
'[VARCHAR(100)] [NOT NULL] Nombre completo del usuario. Obligatorio.';

COMMENT ON COLUMN users.email IS
'[VARCHAR(255)] [NOT NULL] [UNIQUE] Dirección de correo electrónico. Debe ser única en todo el sistema. Se usa para autenticación y comunicaciones.';

COMMENT ON COLUMN users.contrasena_hash IS
'[VARCHAR(255)] [NOT NULL] Hash de la contraseña del usuario. Nunca se almacena la contraseña en texto plano.';

COMMENT ON COLUMN users.bio IS
'[TEXT] [NULLABLE] Descripción libre del perfil. El usuario puede dejarlo vacío.';

COMMENT ON COLUMN users.fecha_registro IS
'[TIMESTAMP] [NOT NULL] [DEFAULT NOW()] Fecha y hora en que se creó la cuenta. Se asigna automáticamente.';

COMMENT ON COLUMN users.activo IS
'[BOOLEAN] [NOT NULL] [DEFAULT TRUE] Indica si la cuenta está activa. FALSE representa un borrado lógico: el registro se conserva pero el usuario no puede operar.';

-- ============================================================
-- TABLA: categories
-- Propósito: Diccionario maestro de intereses o etiquetas disponibles en la aplicación.
-- ============================================================
COMMENT ON TABLE categories IS
'Catálogo centralizado de intereses o etiquetas disponibles en la plataforma.';

COMMENT ON COLUMN categories.category_id IS
'[PK] [SERIAL] Identificador único autoincremental de la categoría.';

COMMENT ON COLUMN categories.nombre IS
'[VARCHAR(100)] [NOT NULL] [UNIQUE] Nombre descriptivo de la categoría. No puede repetirse.';

COMMENT ON COLUMN categories.descripcion IS
'[TEXT] [NULLABLE] Explicación extendida del alcance de la categoría. Opcional.';

COMMENT ON COLUMN categories.icono IS
'[VARCHAR(50)] [NULLABLE] Nombre del ícono asociado a la categoría en el frontend (ej: "camera", "music", "travel").';

-- ============================================================
-- TABLA: photos
-- Propósito: Registra las fotos subidas por los usuarios.
--            Cada foto pertenece a exactamente un usuario.
--            Si el usuario se elimina, sus fotos se eliminan en cascada.
-- ============================================================
COMMENT ON TABLE photos IS
'Fotos subidas por los usuarios. Relacionada con users mediante clave foránea.';

COMMENT ON COLUMN photos.photo_id IS
'[PK] [SERIAL] Identificador único autoincremental de la foto.';

COMMENT ON COLUMN photos.user_id IS
'[INT] [NOT NULL] [FK → users.user_id] Identifica al usuario que subió la foto. ON DELETE CASCADE: si se elimina el usuario, se eliminan sus fotos.';

COMMENT ON COLUMN photos.url_imagen IS
'[TEXT] [NOT NULL] URL completa donde está alojada la imagen (ej: bucket S3, CDN). No se almacena el archivo binario en la base de datos.';

COMMENT ON COLUMN photos.descripcion IS
'[TEXT] [NULLABLE] Pie de foto o descripción opcional ingresada por el usuario.';

COMMENT ON COLUMN photos.fecha_subida IS
'[TIMESTAMP] [NOT NULL] [DEFAULT NOW()] Fecha y hora en que se subió la foto. Se asigna automáticamente.';

-- ============================================================
-- TABLA: user_interests
-- Propósito: Tabla intermedia (relación N:M) que vincula usuarios con categorías de interés.
--            Un usuario puede tener múltiples intereses, y una categoría puede interesarle a muchos usuarios.
-- ============================================================
COMMENT ON TABLE user_interests IS
'Relación muchos-a-muchos entre usuarios y categorías de interés. Incluye el nivel de afinidad del usuario con cada categoría.';

COMMENT ON COLUMN user_interests.user_id IS
'[INT] [NOT NULL] [PK] [FK → users.user_id] Referencia al usuario. Parte de la clave primaria compuesta. ON DELETE CASCADE.';

COMMENT ON COLUMN user_interests.category_id IS
'[INT] [NOT NULL] [PK] [FK → categories.category_id] Referencia a la categoría. Parte de la clave primaria compuesta. ON DELETE CASCADE.';

COMMENT ON COLUMN user_interests.nivel_interes IS
'[SMALLINT] [DEFAULT 1] [CHECK 1–5] Grado de afinidad del usuario con la categoría. Escala: 1 = interés leve, 5 = interés muy alto.';

COMMENT ON COLUMN user_interests.fecha_agregado IS
'[TIMESTAMP] [NOT NULL] [DEFAULT NOW()] Fecha en que el usuario registró este interés. Se asigna automáticamente.';

-- ============================================================
-- TABLA: historial_actividad  [PARTICIONADA POR RANGO]
-- Propósito: Registra cada acción que un usuario realiza dentro del sistema (login, edición, descarga, etc.).
--            Particionada por mes sobre fecha_actividad para optimizar consultas temporales y mantenimiento.
-- ============================================================
COMMENT ON TABLE historial_actividad IS
'Auditoría de acciones de usuarios. Tabla particionada por rango mensual sobre fecha_actividad (2023–2024). Incluye partición DEFAULT para fechas fuera de rango.';

COMMENT ON COLUMN historial_actividad.id IS
'[SERIAL] [NOT NULL] [PK parcial] Identificador autoincremental del registro. Forma la PK junto con fecha_actividad (requisito de PostgreSQL para tablas particionadas).';

COMMENT ON COLUMN historial_actividad.usuario_id IS
'[INTEGER] [NOT NULL] Identificador del usuario que realizó la acción. No tiene FK explícita para no restringir la partición.';

COMMENT ON COLUMN historial_actividad.accion IS
'[VARCHAR(100)] [NOT NULL] Tipo de acción ejecutada. Valores esperados: LOGIN, LOGOUT, EDICION, DESCARGA, CARGA, ELIMINACION, entre otros.';

COMMENT ON COLUMN historial_actividad.modulo IS
'[VARCHAR(60)] [NULLABLE] Módulo o sección del sistema donde ocurrió la acción (ej: "Autenticacion", "Documentos", "Reportes").';

COMMENT ON COLUMN historial_actividad.ip_origen IS
'[VARCHAR(45)] [NULLABLE] Dirección IP desde la que se originó la acción. Acepta formato IPv4 (15 chars) e IPv6 (hasta 45 chars).';

COMMENT ON COLUMN historial_actividad.detalle IS
'[TEXT] [NULLABLE] Descripción libre con información adicional sobre la acción (ej: nombre del archivo descargado, campo editado).';

COMMENT ON COLUMN historial_actividad.fecha_actividad IS
'[TIMESTAMP] [NOT NULL] [PK parcial] [CLAVE DE PARTICIÓN] Fecha y hora exacta en que ocurrió la acción. Define en qué partición mensual se almacena el registro.';

-- ============================================================
-- TABLA: logs_conexiones  [PARTICIONADA POR RANGO]
-- Propósito: Registra cada intento de conexión al sistema, exitoso o fallido. Útil para auditoría de seguridad,
--            detección de intrusiones y análisis de sesiones. Particionada por mes sobre fecha_conexion.
-- ============================================================
COMMENT ON TABLE logs_conexiones IS
'Log de intentos de conexión al sistema. Tabla particionada por rango mensual sobre fecha_conexion (2023–2024). Permite detectar patrones de acceso y amenazas de seguridad.';

COMMENT ON COLUMN logs_conexiones.id IS
'[SERIAL] [NOT NULL] [PK parcial] Identificador autoincremental del log. Forma la PK junto con fecha_conexion.';

COMMENT ON COLUMN logs_conexiones.usuario_id IS
'[INTEGER] [NULLABLE] Identificador del usuario que intentó conectarse. Puede ser NULL si el intento fue anónimo o si no se pudo identificar al usuario.';

COMMENT ON COLUMN logs_conexiones.tipo_evento IS
'[VARCHAR(30)] [NOT NULL] Resultado del intento de conexión. Valores posibles: EXITOSA, FALLIDA, TIMEOUT, BLOQUEADA.';

COMMENT ON COLUMN logs_conexiones.ip_origen IS
'[VARCHAR(45)] [NOT NULL] Dirección IP desde la que se originó el intento. Obligatoria para auditoría de seguridad. Acepta IPv4 e IPv6.';

COMMENT ON COLUMN logs_conexiones.user_agent IS
'[VARCHAR(255)] [NULLABLE] Cadena del agente de usuario del cliente (navegador, app, script). Útil para detectar bots o clientes inusuales.';

COMMENT ON COLUMN logs_conexiones.duracion_ms IS
'[INTEGER] [NULLABLE] Duración de la sesión en milisegundos. Solo aplica a conexiones EXITOSAS. NULL para intentos fallidos, bloqueados o con timeout.';

COMMENT ON COLUMN logs_conexiones.fecha_conexion IS
'[TIMESTAMP] [NOT NULL] [PK parcial] [CLAVE DE PARTICIÓN] Fecha y hora exacta del intento de conexión. Define en qué partición mensual se almacena el registro.';


-- ============================================================
-- RESUMEN DE ÍNDICES DEL ESQUEMA
-- ============================================================
COMMENT ON INDEX idx_photos_user_id IS
'Acelera la búsqueda de todas las fotos de un usuario. Consulta muy frecuente en el perfil.';

COMMENT ON INDEX idx_ui_user_id IS
'Acelera la búsqueda de todos los intereses de un usuario.';

COMMENT ON INDEX idx_ui_category_id IS
'Acelera la búsqueda de todos los usuarios que comparten un mismo interés.';

COMMENT ON INDEX idx_users_email IS
'Acelera la autenticación por email. Clave para el proceso de login.';

-- ============================================================
-- VERIFICAR QUE LOS COMENTARIOS SE APLICARON
-- ============================================================
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
    'users', 'categories', 'photos',
    'user_interests', 'historial_actividad', 'logs_conexiones'
)
ORDER BY cols.table_name, cols.ordinal_position;