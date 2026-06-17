-- Eliminar las tablas si ya existe
DROP TABLE IF EXISTS user_interests CASCADE;
DROP TABLE IF EXISTS photos CASCADE;
DROP TABLE IF EXISTS users CASCADE;
DROP TABLE IF EXISTS categories CASCADE;

-- TABLA: users: Guarda los datos básicos del perfil de cada usuario.
-- Los datos de relaciones (quién sigue a quién) van en Neo4j.

CREATE TABLE users (
    user_id       SERIAL PRIMARY KEY,               -- ID autoincremental, clave primaria
    nombre        VARCHAR(100) NOT NULL,             -- Nombre completo, obligatorio
    email         VARCHAR(255) NOT NULL UNIQUE,      -- Email único por usuario
    contrasena_hash VARCHAR(255) NOT NULL,           -- NUNCA guardamos la contraseña en texto plano
    bio           TEXT,                              -- Descripción opcional del perfil
    fecha_registro TIMESTAMP NOT NULL DEFAULT NOW(), -- Se llena automáticamente al crear el registro
    activo        BOOLEAN NOT NULL DEFAULT TRUE      -- Para "borrado lógico" (no eliminamos filas)
);

-- TABLA: categories: Diccionario maestro de intereses/etiquetas de la aplicación.
-- Ejemplos: "Tecnología", "Música", "Fotografía", "Viajes"

CREATE TABLE categories (
    category_id  SERIAL PRIMARY KEY,
    nombre       VARCHAR(100) NOT NULL UNIQUE,       -- El nombre de la categoría, sin duplicados
    descripcion  TEXT,                               -- Descripción larga opcional
    icono        VARCHAR(50)                         -- Nombre del ícono (ej: "camera", "music")
);


-- TABLA: photos: Fotos subidas por los usuarios.
-- Cada foto pertenece a un usuario (clave foránea user_id).

CREATE TABLE photos (
    photo_id     SERIAL PRIMARY KEY,
    user_id      INT NOT NULL,                       -- Qué usuario subió la foto
    url_imagen   TEXT NOT NULL,                      -- URL donde está guardada la imagen
    descripcion  TEXT,                               -- Pie de foto opcional
    fecha_subida TIMESTAMP NOT NULL DEFAULT NOW(),

    -- Si se borra el usuario, se borran sus fotos también (CASCADE)
    CONSTRAINT fk_photos_user
        FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
);

-- TABLA: user_interests: Tabla intermedia (N:M) que conecta usuarios con categorías.
-- Un usuario puede tener muchos intereses. Una categoría puede interesarle a muchos usuarios.

CREATE TABLE user_interests (
    user_id      INT NOT NULL,
    category_id  INT NOT NULL,
    nivel_interes SMALLINT DEFAULT 1 CHECK (nivel_interes BETWEEN 1 AND 5), -- Del 1 al 5 qué tanto le gusta
    fecha_agregado TIMESTAMP NOT NULL DEFAULT NOW(),

    -- La clave primaria es la combinación de ambas FK (no puede repetirse el mismo par)
    PRIMARY KEY (user_id, category_id),

    CONSTRAINT fk_ui_user
        FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,

    CONSTRAINT fk_ui_category
        FOREIGN KEY (category_id) REFERENCES categories(category_id) ON DELETE CASCADE
);

-- ÍNDICES PK y UNIQUE ya se crean automáticamente.
-- Estos son ADICIONALES, diseñados para las consultas de la app.

-- Buscar todas las fotos de un usuario (consulta muy frecuente)
CREATE INDEX idx_photos_user_id ON photos(user_id);

-- Buscar todos los intereses de un usuario
CREATE INDEX idx_ui_user_id ON user_interests(user_id);

-- Buscar todos los usuarios que tienen cierto interés
CREATE INDEX idx_ui_category_id ON user_interests(category_id);

-- Buscar usuarios por email (login)
CREATE INDEX idx_users_email ON users(email);


-- ============================================================
-- PARTICIONADO POR RANGO (Range Partitioning)
-- ============================================================
-- TABLA: historial_actividad Registra cada acción que realiza un usuario en el sistema.
-- PK: (id, fecha_actividad) — la columna de partición debe estar incluida en la PK (requisito de PostgreSQL).
-- ============================================================

DROP TABLE IF EXISTS historial_actividad CASCADE;

CREATE TABLE historial_actividad (
    id                SERIAL          NOT NULL,
    usuario_id        INTEGER         NOT NULL,
    accion            VARCHAR(100)    NOT NULL,   -- ej: 'LOGIN', 'DESCARGA', 'EDICION'
    modulo            VARCHAR(60),                -- módulo del sistema afectado
    ip_origen         VARCHAR(45),               -- IPv4 o IPv6
    detalle           TEXT,
    fecha_actividad   TIMESTAMP       NOT NULL,
    PRIMARY KEY (id, fecha_actividad)
)
PARTITION BY RANGE (fecha_actividad);

-- Particiones mensuales 2023
CREATE TABLE historial_actividad_2023_01 PARTITION OF historial_actividad FOR VALUES FROM ('2023-01-01') TO ('2023-02-01');
CREATE TABLE historial_actividad_2023_02 PARTITION OF historial_actividad FOR VALUES FROM ('2023-02-01') TO ('2023-03-01');
CREATE TABLE historial_actividad_2023_03 PARTITION OF historial_actividad FOR VALUES FROM ('2023-03-01') TO ('2023-04-01');
CREATE TABLE historial_actividad_2023_04 PARTITION OF historial_actividad FOR VALUES FROM ('2023-04-01') TO ('2023-05-01');
CREATE TABLE historial_actividad_2023_05 PARTITION OF historial_actividad FOR VALUES FROM ('2023-05-01') TO ('2023-06-01');
CREATE TABLE historial_actividad_2023_06 PARTITION OF historial_actividad FOR VALUES FROM ('2023-06-01') TO ('2023-07-01');
CREATE TABLE historial_actividad_2023_07 PARTITION OF historial_actividad FOR VALUES FROM ('2023-07-01') TO ('2023-08-01');
CREATE TABLE historial_actividad_2023_08 PARTITION OF historial_actividad FOR VALUES FROM ('2023-08-01') TO ('2023-09-01');
CREATE TABLE historial_actividad_2023_09 PARTITION OF historial_actividad FOR VALUES FROM ('2023-09-01') TO ('2023-10-01');
CREATE TABLE historial_actividad_2023_10 PARTITION OF historial_actividad FOR VALUES FROM ('2023-10-01') TO ('2023-11-01');
CREATE TABLE historial_actividad_2023_11 PARTITION OF historial_actividad FOR VALUES FROM ('2023-11-01') TO ('2023-12-01');
CREATE TABLE historial_actividad_2023_12 PARTITION OF historial_actividad FOR VALUES FROM ('2023-12-01') TO ('2024-01-01');

-- Particiones mensuales 2024
CREATE TABLE historial_actividad_2024_01 PARTITION OF historial_actividad FOR VALUES FROM ('2024-01-01') TO ('2024-02-01');
CREATE TABLE historial_actividad_2024_02 PARTITION OF historial_actividad FOR VALUES FROM ('2024-02-01') TO ('2024-03-01');
CREATE TABLE historial_actividad_2024_03 PARTITION OF historial_actividad FOR VALUES FROM ('2024-03-01') TO ('2024-04-01');
CREATE TABLE historial_actividad_2024_04 PARTITION OF historial_actividad FOR VALUES FROM ('2024-04-01') TO ('2024-05-01');
CREATE TABLE historial_actividad_2024_05 PARTITION OF historial_actividad FOR VALUES FROM ('2024-05-01') TO ('2024-06-01');
CREATE TABLE historial_actividad_2024_06 PARTITION OF historial_actividad FOR VALUES FROM ('2024-06-01') TO ('2024-07-01');
CREATE TABLE historial_actividad_2024_07 PARTITION OF historial_actividad FOR VALUES FROM ('2024-07-01') TO ('2024-08-01');
CREATE TABLE historial_actividad_2024_08 PARTITION OF historial_actividad FOR VALUES FROM ('2024-08-01') TO ('2024-09-01');
CREATE TABLE historial_actividad_2024_09 PARTITION OF historial_actividad FOR VALUES FROM ('2024-09-01') TO ('2024-10-01');
CREATE TABLE historial_actividad_2024_10 PARTITION OF historial_actividad FOR VALUES FROM ('2024-10-01') TO ('2024-11-01');
CREATE TABLE historial_actividad_2024_11 PARTITION OF historial_actividad FOR VALUES FROM ('2024-11-01') TO ('2024-12-01');
CREATE TABLE historial_actividad_2024_12 PARTITION OF historial_actividad FOR VALUES FROM ('2024-12-01') TO ('2025-01-01');

-- Partición DEFAULT: captura fechas fuera de los rangos definidos
CREATE TABLE historial_actividad_default  PARTITION OF historial_actividad DEFAULT;


-- ============================================================
-- TABLA: logs_conexiones Registra cada intento de conexión al sistema.
-- PK: (id, fecha_conexion) — ídem, incluye la columna de partición.
-- ============================================================

DROP TABLE IF EXISTS logs_conexiones CASCADE;

CREATE TABLE logs_conexiones (
    id                SERIAL          NOT NULL,
    usuario_id        INTEGER,                   -- NULL si el intento fue anónimo
    tipo_evento       VARCHAR(30)     NOT NULL,  -- 'EXITOSA', 'FALLIDA', 'TIMEOUT', 'BLOQUEADA'
    ip_origen         VARCHAR(45)     NOT NULL,
    user_agent        VARCHAR(255),
    duracion_ms       INTEGER,                   -- duración de la sesión en milisegundos
    fecha_conexion    TIMESTAMP       NOT NULL,
    PRIMARY KEY (id, fecha_conexion)
)
PARTITION BY RANGE (fecha_conexion);

-- Particiones mensuales 2023
CREATE TABLE logs_conexiones_2023_01 PARTITION OF logs_conexiones FOR VALUES FROM ('2023-01-01') TO ('2023-02-01');
CREATE TABLE logs_conexiones_2023_02 PARTITION OF logs_conexiones FOR VALUES FROM ('2023-02-01') TO ('2023-03-01');
CREATE TABLE logs_conexiones_2023_03 PARTITION OF logs_conexiones FOR VALUES FROM ('2023-03-01') TO ('2023-04-01');
CREATE TABLE logs_conexiones_2023_04 PARTITION OF logs_conexiones FOR VALUES FROM ('2023-04-01') TO ('2023-05-01');
CREATE TABLE logs_conexiones_2023_05 PARTITION OF logs_conexiones FOR VALUES FROM ('2023-05-01') TO ('2023-06-01');
CREATE TABLE logs_conexiones_2023_06 PARTITION OF logs_conexiones FOR VALUES FROM ('2023-06-01') TO ('2023-07-01');
CREATE TABLE logs_conexiones_2023_07 PARTITION OF logs_conexiones FOR VALUES FROM ('2023-07-01') TO ('2023-08-01');
CREATE TABLE logs_conexiones_2023_08 PARTITION OF logs_conexiones FOR VALUES FROM ('2023-08-01') TO ('2023-09-01');
CREATE TABLE logs_conexiones_2023_09 PARTITION OF logs_conexiones FOR VALUES FROM ('2023-09-01') TO ('2023-10-01');
CREATE TABLE logs_conexiones_2023_10 PARTITION OF logs_conexiones FOR VALUES FROM ('2023-10-01') TO ('2023-11-01');
CREATE TABLE logs_conexiones_2023_11 PARTITION OF logs_conexiones FOR VALUES FROM ('2023-11-01') TO ('2023-12-01');
CREATE TABLE logs_conexiones_2023_12 PARTITION OF logs_conexiones FOR VALUES FROM ('2023-12-01') TO ('2024-01-01');

-- Particiones mensuales 2024
CREATE TABLE logs_conexiones_2024_01 PARTITION OF logs_conexiones FOR VALUES FROM ('2024-01-01') TO ('2024-02-01');
CREATE TABLE logs_conexiones_2024_02 PARTITION OF logs_conexiones FOR VALUES FROM ('2024-02-01') TO ('2024-03-01');
CREATE TABLE logs_conexiones_2024_03 PARTITION OF logs_conexiones FOR VALUES FROM ('2024-03-01') TO ('2024-04-01');
CREATE TABLE logs_conexiones_2024_04 PARTITION OF logs_conexiones FOR VALUES FROM ('2024-04-01') TO ('2024-05-01');
CREATE TABLE logs_conexiones_2024_05 PARTITION OF logs_conexiones FOR VALUES FROM ('2024-05-01') TO ('2024-06-01');
CREATE TABLE logs_conexiones_2024_06 PARTITION OF logs_conexiones FOR VALUES FROM ('2024-06-01') TO ('2024-07-01');
CREATE TABLE logs_conexiones_2024_07 PARTITION OF logs_conexiones FOR VALUES FROM ('2024-07-01') TO ('2024-08-01');
CREATE TABLE logs_conexiones_2024_08 PARTITION OF logs_conexiones FOR VALUES FROM ('2024-08-01') TO ('2024-09-01');
CREATE TABLE logs_conexiones_2024_09 PARTITION OF logs_conexiones FOR VALUES FROM ('2024-09-01') TO ('2024-10-01');
CREATE TABLE logs_conexiones_2024_10 PARTITION OF logs_conexiones FOR VALUES FROM ('2024-10-01') TO ('2024-11-01');
CREATE TABLE logs_conexiones_2024_11 PARTITION OF logs_conexiones FOR VALUES FROM ('2024-11-01') TO ('2024-12-01');
CREATE TABLE logs_conexiones_2024_12 PARTITION OF logs_conexiones FOR VALUES FROM ('2024-12-01') TO ('2025-01-01');

-- Partición DEFAULT
CREATE TABLE logs_conexiones_default PARTITION OF logs_conexiones DEFAULT;


-- ============================================================
-- VERIFICACIÓN: listar todas las particiones creadas
-- ============================================================

SELECT
    parent.relname      AS tabla_padre,
    child.relname       AS particion,
    pg_get_expr(child.relpartbound, child.oid) AS rango
FROM pg_inherits
JOIN pg_class parent ON pg_inherits.inhparent = parent.oid
JOIN pg_class child  ON pg_inherits.inhrelid  = child.oid
WHERE parent.relname IN ('historial_actividad', 'logs_conexiones')
ORDER BY tabla_padre, child.relname;


-- ============================================================
-- DATOS DE PRUEBA
-- ============================================================

INSERT INTO historial_actividad (usuario_id, accion, modulo, ip_origen, detalle, fecha_actividad)
VALUES
    (101, 'LOGIN',    'Autenticacion', '192.168.1.10', 'Acceso exitoso',           '2023-03-14 08:22:00'),
    (205, 'EDICION',  'Documentos',   '10.0.0.55',    'Modificó archivo contrato', '2023-09-05 11:45:00'),
    (308, 'DESCARGA', 'Reportes',     '172.16.0.3',   'Exportó reporte mensual',  '2024-02-20 16:10:00'),
    (101, 'LOGOUT',   'Autenticacion','192.168.1.10', 'Sesión cerrada',            '2024-07-31 18:00:00');

INSERT INTO logs_conexiones (usuario_id, tipo_evento, ip_origen, user_agent, duracion_ms, fecha_conexion)
VALUES
    (101,  'EXITOSA',   '192.168.1.10', 'Mozilla/5.0 Chrome/120',  3600000, '2023-03-14 08:22:00'),
    (NULL, 'FALLIDA',   '45.33.32.156', 'curl/7.68.0',             NULL,    '2023-06-01 03:11:00'),
    (205,  'TIMEOUT',   '10.0.0.55',    'Mozilla/5.0 Firefox/119', 1800000, '2024-04-10 14:05:00'),
    (308,  'BLOQUEADA', '200.55.10.22', 'python-requests/2.28',    NULL,    '2024-11-22 22:30:00');

-- Verificar en qué partición cayó cada fila
SELECT tableoid::regclass AS particion_fisica, id, usuario_id, accion, fecha_actividad
FROM historial_actividad ORDER BY fecha_actividad;

SELECT tableoid::regclass AS particion_fisica, id, usuario_id, tipo_evento, fecha_conexion
FROM logs_conexiones ORDER BY fecha_conexion;


-- ============================================================
-- DEMOSTRACIÓN DE PARTITION PRUNING: El motor accede solo a las particiones necesarias
-- ============================================================

EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM historial_actividad
WHERE fecha_actividad BETWEEN '2024-01-01' AND '2024-06-30';

EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM logs_conexiones
WHERE fecha_conexion BETWEEN '2023-06-01' AND '2023-08-31'
    AND tipo_evento = 'FALLIDA';

<<<<<<< HEAD
    -- ============================================================
-- TABLA: roles
=======
-- ============================================================
--  AGREGADO DE ROLES (RBAC) - agregar al final de 01_schema.sql
-- ============================================================
>>>>>>> b54d424109ac4051134cf8276cd2bea11876bcd0
-- Define los niveles de acceso jerárquicos de la aplicación.
-- ============================================================
CREATE TABLE roles (
    rol_id      SERIAL PRIMARY KEY,
    nombre      VARCHAR(50) NOT NULL UNIQUE,  -- 'usuario', 'operador', 'administrador'
    descripcion TEXT
);

<<<<<<< HEAD

=======
-- Tres roles posibles
>>>>>>> b54d424109ac4051134cf8276cd2bea11876bcd0
INSERT INTO roles (nombre, descripcion) VALUES
('usuario',        'Acceso básico: ver perfiles, subir fotos y agregar intereses'),
('operador',       'Acceso intermedio: todo lo anterior más moderación de contenido'),
('administrador',  'Acceso total: puede modificar datos de cualquier usuario');

-- ============================================================
-- MODIFICACIÓN: tabla users
<<<<<<< HEAD
-- La columna rol_id con valor por defecto 'usuario'
=======
-- Se agrega la columna rol_id con valor por defecto 'usuario'
-- (rol_id = 1 según el INSERT anterior).
>>>>>>> b54d424109ac4051134cf8276cd2bea11876bcd0
-- ============================================================
ALTER TABLE users
    ADD COLUMN rol_id INT NOT NULL DEFAULT 1
        REFERENCES roles(rol_id) ON DELETE RESTRICT;
-- ON DELETE RESTRICT: no permite borrar un rol que tenga usuarios asignados
-- Índice para consultas por rol (ej: "traer todos los administradores")
CREATE INDEX idx_users_rol ON users(rol_id);