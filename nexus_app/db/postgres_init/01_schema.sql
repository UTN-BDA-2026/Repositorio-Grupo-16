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
