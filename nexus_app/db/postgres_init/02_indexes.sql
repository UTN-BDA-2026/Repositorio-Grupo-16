-- ÍNDICE B-TREE para búsqueda exacta por nombre
-- PostgreSQL btree es más eficiente y estándar para búsquedas exactas que hash.
CREATE INDEX idx_users_nombre ON users USING btree (nombre);

-- ÍNDICE B-TREE para análisis por fecha de registro
CREATE INDEX idx_users_fecha_registro ON users USING btree (fecha_registro);

-- ÍNDICE PARCIAL para usuarios activos
-- Reduce el tamaño del índice al indexar solo filas activas.
CREATE INDEX idx_users_activos ON users (user_id) WHERE activo = TRUE;

-- ÍNDICE B-TREE COMPUESTO
-- Optimiza la tabla de intereses para cuando filtramos usuarios por categoría y nivel
CREATE INDEX idx_user_interests_busqueda ON user_interests (category_id, nivel_interes);