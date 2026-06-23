-- ============================================================
-- Script: 09_ajuste_users.sql
-- Propósito: Alinear tabla 'users' con modelo ORM UsuarioORM
-- IMPORTANTE: ejecutar con: docker compose down -v && make up
-- ============================================================

-- Agrega la columna nombre_usuario si no existe
-- Copia datos de 'nombre' para mantener integridad referencial
ALTER TABLE users ADD COLUMN IF NOT EXISTS nombre_usuario VARCHAR(100);
UPDATE users SET nombre_usuario = nombre WHERE nombre_usuario IS NULL;
ALTER TABLE users ALTER COLUMN nombre_usuario SET NOT NULL;

-- Agrega fecha_nacimiento: campo opcional (puede ser NULL)
ALTER TABLE users ADD COLUMN IF NOT EXISTS fecha_nacimiento TIMESTAMP;

-- Agrega sexo: campo opcional (puede ser NULL)
ALTER TABLE users ADD COLUMN IF NOT EXISTS sexo VARCHAR(20);

-- Agrega fecha_actualizacion: inicializa con NOW() y se actualiza automáticamente
ALTER TABLE users ADD COLUMN IF NOT EXISTS fecha_actualizacion TIMESTAMP NOT NULL DEFAULT NOW();

-- Renombra fecha_registro a fecha_creacion para coincidir con ORM (CRÍTICO)
ALTER TABLE users RENAME COLUMN fecha_registro TO fecha_creacion;

-- Agrega índice compuesto para búsquedas optimizadas (requisito académico)
CREATE INDEX IF NOT EXISTS idx_users_email_activo ON users(email, activo);
CREATE INDEX IF NOT EXISTS idx_users_fecha_creacion ON users(fecha_creacion);

-- Agrega restricción de validación de email (requisito académico)
ALTER TABLE users ADD CONSTRAINT ck_email_valido 
    CHECK (email LIKE '%@%') NOT VALID;