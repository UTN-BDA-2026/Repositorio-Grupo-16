-- ÍNDICE B-TREE para búsqueda exacta por nombre

CREATE INDEX IF NOT EXISTS idx_users_nombre ON users USING btree (nombre);

-- ÍNDICE B-TREE para análisis por fecha de registro
CREATE INDEX IF NOT EXISTS idx_users_fecha_registro ON users USING btree (fecha_registro);

-- ÍNDICE PARCIAL Y CUBRIENTE para usuarios activos

CREATE INDEX IF NOT EXISTS idx_users_activos ON users (user_id) INCLUDE (nombre, bio) WHERE activo = TRUE;

-- ÍNDICE B-TREE COMPUESTO

CREATE INDEX IF NOT EXISTS idx_user_interests_busqueda ON user_interests (category_id, nivel_interes);