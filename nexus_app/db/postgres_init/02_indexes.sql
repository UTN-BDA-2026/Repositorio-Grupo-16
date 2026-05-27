-- ÍNDICE HASH 
-- Para buscar usuarios por su nombre exacto con un costo O(1).
CREATE INDEX idx_users_nombre_hash ON users USING hash (nombre);

-- ÍNDICE B-TREE
-- Para la analítica de la app.
CREATE INDEX idx_users_fecha_registro ON users USING btree (fecha_registro);

-- ÍNDICE PARCIAL Y CUBRIENTE 
-- Este índice solo guarda los activos e incluye la 'bio' 
CREATE INDEX idx_users_activos_bio ON users (user_id, bio) WHERE activo = TRUE;

-- ÍNDICE B-TREE COMPUESTO
-- Optimiza la tabla de intereses para cuando filtramos usuarios por categoría y nivel
CREATE INDEX idx_user_interests_busqueda ON user_interests (category_id, nivel_interes);