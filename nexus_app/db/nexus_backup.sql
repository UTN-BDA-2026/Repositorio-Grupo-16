--
-- PostgreSQL database dump
-- Dumped from database version 17.4
-- Dumped by pg_dump version 17.4
-- NEXUS - Red Social de Recomendaciones
--

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

SET default_tablespace = '';
SET default_table_access_method = heap;

-- ============================================================
-- SECCIÓN 1: ELIMINAR TABLAS ANTERIORES
-- ============================================================
DROP TABLE IF EXISTS auditoria_admins CASCADE;
DROP TABLE IF EXISTS auditoria_emails CASCADE;
DROP TABLE IF EXISTS user_connections CASCADE;
DROP TABLE IF EXISTS logs_conexiones CASCADE;
DROP TABLE IF EXISTS historial_actividad CASCADE;
DROP TABLE IF EXISTS user_interests CASCADE;
DROP TABLE IF EXISTS photos CASCADE;
DROP TABLE IF EXISTS users CASCADE;
DROP TABLE IF EXISTS categories CASCADE;

-- ============================================================
-- SECCIÓN 2: CREAR TABLAS PRINCIPALES
-- ============================================================

-- TABLA: users
CREATE TABLE users (
    user_id SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE,
    contrasena_hash VARCHAR(255) NOT NULL,
    bio TEXT,
    fecha_registro TIMESTAMP NOT NULL DEFAULT NOW(),
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    version INT NOT NULL DEFAULT 1
);

ALTER TABLE users OWNER TO postgres;

-- TABLA: categories
CREATE TABLE categories (
    category_id SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL UNIQUE,
    descripcion TEXT,
    icono VARCHAR(50)
);

ALTER TABLE categories OWNER TO postgres;

-- TABLA: photos
CREATE TABLE photos (
    photo_id SERIAL PRIMARY KEY,
    user_id INT NOT NULL,
    url_imagen TEXT NOT NULL,
    descripcion TEXT,
    fecha_subida TIMESTAMP NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_photos_user
        FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
);

ALTER TABLE photos OWNER TO postgres;

-- TABLA: user_interests
CREATE TABLE user_interests (
    user_id INT NOT NULL,
    category_id INT NOT NULL,
    nivel_interes SMALLINT DEFAULT 1 CHECK (nivel_interes BETWEEN 1 AND 5),
    fecha_agregado TIMESTAMP NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, category_id),
    CONSTRAINT fk_ui_user
        FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    CONSTRAINT fk_ui_category
        FOREIGN KEY (category_id) REFERENCES categories(category_id) ON DELETE CASCADE
);

ALTER TABLE user_interests OWNER TO postgres;

-- TABLA: user_connections
CREATE TABLE user_connections (
    user_id_1 INT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    user_id_2 INT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    fecha_conexion TIMESTAMP NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id_1, user_id_2)
);

ALTER TABLE user_connections OWNER TO postgres;

-- ============================================================
-- TABLA: historial_actividad (PARTICIONADA POR RANGO)
-- ============================================================
CREATE TABLE historial_actividad (
    id SERIAL NOT NULL,
    usuario_id INTEGER NOT NULL,
    accion VARCHAR(100) NOT NULL,
    modulo VARCHAR(60),
    ip_origen VARCHAR(45),
    detalle TEXT,
    fecha_actividad TIMESTAMP NOT NULL,
    PRIMARY KEY (id, fecha_actividad)
)
PARTITION BY RANGE (fecha_actividad);

ALTER TABLE historial_actividad OWNER TO postgres;

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

-- Partición DEFAULT
CREATE TABLE historial_actividad_default PARTITION OF historial_actividad DEFAULT;

-- ============================================================
-- TABLA: logs_conexiones (PARTICIONADA POR RANGO)
-- ============================================================
CREATE TABLE logs_conexiones (
    id SERIAL NOT NULL,
    usuario_id INTEGER,
    tipo_evento VARCHAR(30) NOT NULL,
    ip_origen VARCHAR(45) NOT NULL,
    user_agent VARCHAR(255),
    duracion_ms INTEGER,
    fecha_conexion TIMESTAMP NOT NULL,
    PRIMARY KEY (id, fecha_conexion)
)
PARTITION BY RANGE (fecha_conexion);

ALTER TABLE logs_conexiones OWNER TO postgres;

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
-- TABLA: auditoria_emails
-- ============================================================
CREATE TABLE auditoria_emails (
    auditoria_id SERIAL PRIMARY KEY,
    user_id INT NOT NULL,
    email_anterior VARCHAR(320),
    email_nuevo VARCHAR(320),
    fecha_cambio TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

ALTER TABLE auditoria_emails OWNER TO postgres;
CREATE INDEX idx_auditoria_emails_user_id ON auditoria_emails(user_id);

-- ============================================================
-- TABLA: auditoria_admins
-- ============================================================
CREATE TABLE auditoria_admins (
    auditoria_id SERIAL PRIMARY KEY,
    fecha_hora TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    admin_user_id INT NOT NULL,
    usuario_id INT NOT NULL,
    campo_modificado VARCHAR(100),
    valor_anterior TEXT,
    valor_nuevo TEXT
);

ALTER TABLE auditoria_admins OWNER TO postgres;
CREATE INDEX idx_auditoria_admins_admin ON auditoria_admins(admin_user_id);
CREATE INDEX idx_auditoria_admins_usuario ON auditoria_admins(usuario_id);

-- ============================================================
-- SECCIÓN 2.5: DOCUMENTACIÓN DE LA BASE DE DATOS
-- ============================================================

-- Comentarios sobre TABLA users
COMMENT ON TABLE users IS 'Perfil básico de cada usuario registrado en el sistema. Las relaciones sociales (seguir/ser seguido) se gestionan en Neo4j.';
COMMENT ON COLUMN users.user_id IS '[PK] Identificador único autoincremental del usuario.';
COMMENT ON COLUMN users.nombre IS '[VARCHAR(100)] Nombre completo del usuario. Obligatorio.';
COMMENT ON COLUMN users.email IS '[VARCHAR(255)] Email único. Se usa para autenticación y comunicaciones.';
COMMENT ON COLUMN users.contrasena_hash IS '[VARCHAR(255)] Hash bcrypt de la contraseña. Nunca texto plano.';
COMMENT ON COLUMN users.bio IS '[TEXT] Descripción opcional del perfil. Puede contener hasta ~1000 caracteres.';
COMMENT ON COLUMN users.fecha_registro IS '[TIMESTAMP] Fecha de creación de cuenta. Se asigna automáticamente.';
COMMENT ON COLUMN users.activo IS '[BOOLEAN] Estado de la cuenta. FALSE = borrado lógico (el usuario no puede operar).';
COMMENT ON COLUMN users.version IS '[INT] Control de concurrencia optimista. Se incrementa en cada UPDATE del perfil.';

-- Comentarios sobre TABLA categories
COMMENT ON TABLE categories IS 'Catálogo centralizado de intereses o etiquetas disponibles en la plataforma.';
COMMENT ON COLUMN categories.category_id IS '[PK] Identificador único autoincremental de la categoría.';
COMMENT ON COLUMN categories.nombre IS '[VARCHAR(100)] Nombre de la categoría. Único, sin duplicados.';
COMMENT ON COLUMN categories.descripcion IS '[TEXT] Explicación extendida del alcance de la categoría.';
COMMENT ON COLUMN categories.icono IS '[VARCHAR(50)] Nombre del ícono para el frontend (ej: "camera", "music", "gamepad").';

-- Comentarios sobre TABLA photos
COMMENT ON TABLE photos IS 'Fotos subidas por los usuarios. Cada foto pertenece a exactamente un usuario. ON DELETE CASCADE.';
COMMENT ON COLUMN photos.photo_id IS '[PK] Identificador único autoincremental de la foto.';
COMMENT ON COLUMN photos.user_id IS '[FK] Referencia al usuario propietario. Si se borra el usuario, se borran sus fotos.';
COMMENT ON COLUMN photos.url_imagen IS '[TEXT] URL completa donde está alojada la imagen (S3, CDN, etc).';
COMMENT ON COLUMN photos.descripcion IS '[TEXT] Pie de foto opcional ingresado por el usuario.';
COMMENT ON COLUMN photos.fecha_subida IS '[TIMESTAMP] Fecha de subida. Se asigna automáticamente.';

-- Comentarios sobre TABLA user_interests
COMMENT ON TABLE user_interests IS 'Tabla de relación muchos-a-muchos entre usuarios y categorías de interés.';
COMMENT ON COLUMN user_interests.user_id IS '[PK] [FK] Referencia al usuario. ON DELETE CASCADE.';
COMMENT ON COLUMN user_interests.category_id IS '[PK] [FK] Referencia a la categoría. ON DELETE CASCADE.';
COMMENT ON COLUMN user_interests.nivel_interes IS '[SMALLINT] Escala 1-5: grado de afinidad del usuario con la categoría.';
COMMENT ON COLUMN user_interests.fecha_agregado IS '[TIMESTAMP] Fecha en que el usuario registró este interés.';

-- Comentarios sobre TABLA user_connections
COMMENT ON TABLE user_connections IS 'Conexiones/matches entre usuarios. Relación bidireccional (siempre user_id_1 < user_id_2).';
COMMENT ON COLUMN user_connections.user_id_1 IS '[PK] [FK] Usuario con ID menor.';
COMMENT ON COLUMN user_connections.user_id_2 IS '[PK] [FK] Usuario con ID mayor.';
COMMENT ON COLUMN user_connections.fecha_conexion IS '[TIMESTAMP] Fecha en que se creó la conexión.';

-- Comentarios sobre tablas de auditoría
COMMENT ON TABLE auditoria_emails IS 'Registro de histórico de cambios de email. Se llena automáticamente con trigger.';
COMMENT ON COLUMN auditoria_emails.user_id IS 'Usuario cuyo email cambió.';
COMMENT ON COLUMN auditoria_emails.email_anterior IS 'Email anterior (antes del cambio).';
COMMENT ON COLUMN auditoria_emails.email_nuevo IS 'Email nuevo (después del cambio).';

COMMENT ON TABLE auditoria_admins IS 'Auditoría de cambios realizados por administradores. Trazabilidad de modificaciones sensibles.';
COMMENT ON COLUMN auditoria_admins.admin_user_id IS 'ID del administrador que realizó el cambio.';
COMMENT ON COLUMN auditoria_admins.usuario_id IS 'ID del usuario al que se le modificaron datos.';
COMMENT ON COLUMN auditoria_admins.campo_modificado IS 'Campo que cambió (ej: "nombre", "email", "activo").';
COMMENT ON COLUMN auditoria_admins.valor_anterior IS 'Valor anterior al cambio.';
COMMENT ON COLUMN auditoria_admins.valor_nuevo IS 'Valor después del cambio.';

-- Comentarios sobre tablas particionadas
COMMENT ON TABLE historial_actividad IS 'Historial de todas las acciones de usuarios. Particionada por mes para optimizar consultas. Retención: 24+ meses.';
COMMENT ON TABLE logs_conexiones IS 'Logs de conexiones/sesiones. Particionada por mes. Datos para análisis de seguridad y performance.';

-- ============================================================
-- SECCIÓN 3: CREAR ÍNDICES
-- ============================================================

CREATE INDEX idx_users_nombre ON users USING btree (nombre);
CREATE INDEX idx_users_email ON users USING btree (email);
CREATE INDEX idx_users_fecha_registro ON users USING btree (fecha_registro);
CREATE INDEX idx_users_activos ON users (user_id) INCLUDE (nombre, bio) WHERE activo = TRUE;
CREATE INDEX idx_photos_user_id ON photos(user_id);
CREATE INDEX idx_ui_user_id ON user_interests(user_id);
CREATE INDEX idx_ui_category_id ON user_interests(category_id);
CREATE INDEX idx_user_interests_busqueda ON user_interests (category_id, nivel_interes);

-- ============================================================
-- SECCIÓN 4: CREAR FUNCIONES Y TRIGGERS
-- ============================================================

-- TRIGGER 1: AUDITORÍA DE CAMBIO DE EMAIL
CREATE OR REPLACE FUNCTION fn_auditar_cambio_email()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.email IS DISTINCT FROM NEW.email THEN
        INSERT INTO auditoria_emails (user_id, email_anterior, email_nuevo)
        VALUES (OLD.user_id, OLD.email, NEW.email);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_auditar_email ON users;
CREATE TRIGGER trg_auditar_email
AFTER UPDATE OF email ON users
FOR EACH ROW
EXECUTE FUNCTION fn_auditar_cambio_email();

-- TRIGGER 2: LÍMITE DE FOTOS PERMITIDAS
CREATE OR REPLACE FUNCTION fn_limite_fotos_perfil()
RETURNS TRIGGER AS $$
DECLARE
    cantidad_actual INT;
BEGIN
    IF NEW.user_id IS NULL THEN
        RAISE EXCEPTION 'Regla de negocio: user_id no puede ser NULL en photos.';
    END IF;

    PERFORM 1 FROM users WHERE user_id = NEW.user_id FOR UPDATE;

    SELECT COUNT(*) INTO cantidad_actual
    FROM photos
    WHERE user_id = NEW.user_id;

    IF cantidad_actual >= 6 THEN
        RAISE EXCEPTION 'Regla de negocio: El usuario % ya alcanzó el límite máximo de 6 fotos.', NEW.user_id
        USING ERRCODE = 'P0001';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_limite_fotos ON photos;
CREATE TRIGGER trg_limite_fotos
BEFORE INSERT ON photos
FOR EACH ROW
EXECUTE FUNCTION fn_limite_fotos_perfil();

-- TRIGGER 3: FILTRO DE MODERACIÓN EN LA BIO
CREATE OR REPLACE FUNCTION fn_moderar_bio()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.bio ~* '(?<!\\w)(feo|fea|gord[oa]|flac[oa]|horrible|asqueros[oa])(?!\\w)' THEN
        RAISE EXCEPTION 'Regla de comunidad: Tu descripción contiene lenguaje no permitido. Fomentamos un espacio ético y libre de prejuicios sobre los cuerpos.'
        USING ERRCODE = 'P0001';
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_moderar_bio ON users;
CREATE TRIGGER trg_moderar_bio
BEFORE INSERT OR UPDATE OF bio ON users
FOR EACH ROW
WHEN (NEW.bio IS NOT NULL)
EXECUTE FUNCTION fn_moderar_bio();

-- TRIGGER 4: CONTROL ANTI-SPAM DE INTERESES
CREATE OR REPLACE FUNCTION fn_limite_intereses()
RETURNS TRIGGER AS $$
DECLARE
    cant_intereses INT;
BEGIN
    PERFORM 1 FROM users WHERE user_id = NEW.user_id FOR UPDATE;

    SELECT COUNT(*) INTO cant_intereses 
    FROM user_interests 
    WHERE user_id = NEW.user_id;

    IF cant_intereses >= 15 THEN
        RAISE EXCEPTION 'Regla anti-spam: El usuario % no puede exceder el límite de 15 intereses.', NEW.user_id
        USING ERRCODE = 'P0001';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_limite_intereses ON user_interests;
CREATE TRIGGER trg_limite_intereses
BEFORE INSERT ON user_interests
FOR EACH ROW
EXECUTE FUNCTION fn_limite_intereses();

-- TRIGGER 5: BLOQUEO DE ACCIONES PARA CUENTAS INACTIVAS
CREATE OR REPLACE FUNCTION fn_bloquear_inactivos()
RETURNS TRIGGER AS $$
DECLARE
    estado_activo BOOLEAN;
BEGIN
    SELECT activo INTO estado_activo 
    FROM users 
    WHERE user_id = NEW.user_id
    FOR SHARE;

    IF estado_activo IS NOT TRUE THEN
        RAISE EXCEPTION 'Seguridad: Operación denegada. La cuenta del usuario % se encuentra inactiva o no existe.', NEW.user_id
        USING ERRCODE = 'P0001';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_bloquear_fotos_inactivos ON photos;
CREATE TRIGGER trg_bloquear_fotos_inactivos
BEFORE INSERT ON photos
FOR EACH ROW
EXECUTE FUNCTION fn_bloquear_inactivos();

DROP TRIGGER IF EXISTS trg_bloquear_intereses_inactivos ON user_interests;
CREATE TRIGGER trg_bloquear_intereses_inactivos
BEFORE INSERT ON user_interests
FOR EACH ROW
EXECUTE FUNCTION fn_bloquear_inactivos();

-- TRIGGER 6: AUDITORÍA DE ACCIONES DE ADMINISTRADORES
-- Registra cambios realizados por admins en datos sensibles de otros usuarios
CREATE OR REPLACE FUNCTION fn_auditar_accion_admin()
RETURNS TRIGGER AS $$
DECLARE
    v_admin_id INT;
BEGIN
    -- Obtener el ID del admin desde la sesión (debe setearse en la app)
    BEGIN
        v_admin_id := current_setting('app.current_user_id')::INT;
    EXCEPTION WHEN OTHERS THEN
        v_admin_id := 0;  -- Si no está seteado, no auditamos
    END;
    
    -- Solo auditar si hay un admin logueado y está modificando a otro usuario
    IF v_admin_id > 0 AND v_admin_id != NEW.user_id THEN
        
        -- Auditar cambios en nombre
        IF OLD.nombre IS DISTINCT FROM NEW.nombre THEN
            INSERT INTO auditoria_admins (admin_user_id, usuario_id, campo_modificado, valor_anterior, valor_nuevo)
            VALUES (v_admin_id, NEW.user_id, 'nombre', OLD.nombre, NEW.nombre);
        END IF;
        
        -- Auditar cambios en email
        IF OLD.email IS DISTINCT FROM NEW.email THEN
            INSERT INTO auditoria_admins (admin_user_id, usuario_id, campo_modificado, valor_anterior, valor_nuevo)
            VALUES (v_admin_id, NEW.user_id, 'email', OLD.email, NEW.email);
        END IF;
        
        -- Auditar cambios en bio
        IF OLD.bio IS DISTINCT FROM NEW.bio THEN
            INSERT INTO auditoria_admins (admin_user_id, usuario_id, campo_modificado, valor_anterior, valor_nuevo)
            VALUES (v_admin_id, NEW.user_id, 'bio', OLD.bio, NEW.bio);
        END IF;
        
        -- Auditar cambios en estado activo (muy importante)
        IF OLD.activo IS DISTINCT FROM NEW.activo THEN
            INSERT INTO auditoria_admins (admin_user_id, usuario_id, campo_modificado, valor_anterior, valor_nuevo)
            VALUES (v_admin_id, NEW.user_id, 'activo', OLD.activo::TEXT, NEW.activo::TEXT);
        END IF;
        
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_auditar_accion_admin ON users;
CREATE TRIGGER trg_auditar_accion_admin
AFTER UPDATE ON users
FOR EACH ROW
EXECUTE FUNCTION fn_auditar_accion_admin();

-- ============================================================
-- SECCIÓN 5: PROCEDIMIENTOS ALMACENADOS (CONTROL DE CONCURRENCIA)
-- ============================================================

-- PROCEDIMIENTO 1: ACTUALIZACIÓN SEGURA DE INTERESES (PESIMISTA)
DROP PROCEDURE IF EXISTS pr_actualizar_interes_seguro;
CREATE OR REPLACE PROCEDURE pr_actualizar_interes_seguro(
    p_user_id INT,
    p_category_id INT,
    p_nuevo_nivel SMALLINT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_nivel_actual SMALLINT;
BEGIN
    SELECT nivel_interes INTO v_nivel_actual
    FROM user_interests
    WHERE user_id = p_user_id AND category_id = p_category_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Concurrencia: La categoría % no está asignada al usuario %.', p_category_id, p_user_id;
    END IF;

    IF p_nuevo_nivel < 1 OR p_nuevo_nivel > 5 THEN
        RAISE EXCEPTION 'Regla de negocio: El nivel de interés debe estar entre 1 y 5.';
    END IF;

    UPDATE user_interests
    SET nivel_interes = p_nuevo_nivel,
        fecha_agregado = NOW()
    WHERE user_id = p_user_id AND category_id = p_category_id;

    RAISE NOTICE 'Transacción Segura: Interés en categoría % actualizado.', p_category_id;
END;
$$;

-- PROCEDIMIENTO 2: DESACTIVACIÓN AISLADA DE CUENTA
DROP PROCEDURE IF EXISTS pr_desactivar_cuenta_segura;
CREATE OR REPLACE PROCEDURE pr_desactivar_cuenta_segura(
    p_user_id INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_estado_actual BOOLEAN;
BEGIN
    SELECT activo INTO v_estado_actual
    FROM users
    WHERE user_id = p_user_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'La cuenta del usuario % no existe.', p_user_id;
    ELSIF v_estado_actual IS NOT TRUE THEN
        RAISE EXCEPTION 'La cuenta del usuario % ya se encuentra inactiva.', p_user_id;
    END IF;

    UPDATE users
    SET activo = FALSE
    WHERE user_id = p_user_id;

    RAISE NOTICE 'Transacción Segura: Cuenta del usuario % desactivada.', p_user_id;
END;
$$;

-- PROCEDIMIENTO 3: CREACIÓN DE CONEXIÓN SEGURA
DROP PROCEDURE IF EXISTS pr_crear_conexion_segura;
CREATE OR REPLACE PROCEDURE pr_crear_conexion_segura(
    p_user_a INT,
    p_user_b INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_menor_id INT;
    v_mayor_id INT;
    v_existe BOOLEAN;
BEGIN
    v_menor_id := LEAST(p_user_a, p_user_b);
    v_mayor_id := GREATEST(p_user_a, p_user_b);

    PERFORM 1 FROM users WHERE user_id IN (v_menor_id, v_mayor_id) ORDER BY user_id FOR UPDATE;

    SELECT EXISTS (
        SELECT 1 FROM user_connections 
        WHERE user_id_1 = v_menor_id AND user_id_2 = v_mayor_id
    ) INTO v_existe;

    IF v_existe THEN
        RAISE NOTICE 'Concurrencia: La conexión entre % y % ya fue registrada.', v_menor_id, v_mayor_id;
        RETURN;
    END IF;

    INSERT INTO user_connections (user_id_1, user_id_2)
    VALUES (v_menor_id, v_mayor_id);

    RAISE NOTICE 'Transacción Segura: Conexión creada entre % y %.', v_menor_id, v_mayor_id;
END;
$$;

-- PROCEDIMIENTO 4: ACTUALIZACIÓN DE PERFIL (OPTIMISTA)
DROP PROCEDURE IF EXISTS pr_actualizar_perfil_optimista;
CREATE OR REPLACE PROCEDURE pr_actualizar_perfil_optimista(
    p_user_id INT,
    p_nueva_bio TEXT,
    p_version_leida INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_filas_afectadas INT;
BEGIN
    UPDATE users
    SET bio = p_nueva_bio,
        version = version + 1
    WHERE user_id = p_user_id 
      AND version = p_version_leida;

    GET DIAGNOSTICS v_filas_afectadas = ROW_COUNT;

    IF v_filas_afectadas = 0 THEN
        RAISE EXCEPTION 'Conflicto de concurrencia: El perfil fue modificado desde otro dispositivo. Recargá la vista e intentá nuevamente.';
    END IF;

    RAISE NOTICE 'Transacción Optimista: Bio de usuario % actualizada a versión %.', p_user_id, p_version_leida + 1;
END;
$$;

-- ============================================================
-- SECCIÓN 5.5: CONFIGURACIÓN DE SEGURIDAD Y USUARIOS
-- ============================================================

-- Crear usuario de aplicación (si no existe)
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'nexus_user') THEN
        CREATE ROLE nexus_user WITH LOGIN PASSWORD 'nexus_dev_password_change_in_prod';
        RAISE NOTICE 'Usuario nexus_user creado exitosamente.';
    ELSE
        RAISE NOTICE 'Usuario nexus_user ya existe.';
    END IF;
END
$$;

-- Crear usuario de solo lectura (para reportes/auditoría)
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'nexus_readonly') THEN
        CREATE ROLE nexus_readonly WITH LOGIN PASSWORD 'nexus_readonly_dev_change_in_prod';
        RAISE NOTICE 'Usuario nexus_readonly creado exitosamente.';
    ELSE
        RAISE NOTICE 'Usuario nexus_readonly ya existe.';
    END IF;
END
$$;

-- Crear usuario para backups automáticos
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'nexus_backup') THEN
        CREATE ROLE nexus_backup WITH LOGIN PASSWORD 'nexus_backup_dev_change_in_prod';
        RAISE NOTICE 'Usuario nexus_backup creado exitosamente.';
    ELSE
        RAISE NOTICE 'Usuario nexus_backup ya existe.';
    END IF;
END
$$;

-- Asignar permisos a nexus_user (usuario de aplicación)
GRANT USAGE ON SCHEMA public TO nexus_user;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA public TO nexus_user;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO nexus_user;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO nexus_user;

-- Asignar permisos a nexus_readonly (reportes)
GRANT USAGE ON SCHEMA public TO nexus_readonly;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO nexus_readonly;

-- Asignar permisos a nexus_backup (backups)
GRANT USAGE ON SCHEMA public TO nexus_backup;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO nexus_backup;

-- Aplicar permisos por defecto a tablas futuras
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE ON TABLES TO nexus_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO nexus_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO nexus_readonly;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO nexus_backup;

-- ============================================================
-- SECCIÓN 6: INSERTAR DATOS DE SEED - CATEGORÍAS
-- ============================================================

TRUNCATE TABLE user_interests RESTART IDENTITY CASCADE;
TRUNCATE TABLE photos RESTART IDENTITY CASCADE;
TRUNCATE TABLE users RESTART IDENTITY CASCADE;
TRUNCATE TABLE categories RESTART IDENTITY CASCADE;

INSERT INTO categories (nombre, descripcion, icono) VALUES
('Tecnología', 'Todo sobre software, hardware y tendencias tech', 'laptop'),
('Inteligencia Artificial', 'Machine learning, modelos de lenguaje y automatización', 'robot'),
('Programación', 'Lenguajes, frameworks y buenas prácticas de código', 'code'),
('Ciberseguridad', 'Seguridad informática, hacking ético y privacidad', 'shield'),
('Videojuegos', 'Gaming, desarrollo de juegos y cultura gamer', 'gamepad'),
('Arte Digital', 'Ilustración, diseño gráfico y arte generado por IA', 'palette'),
('Fotografía', 'Técnicas, equipos y edición fotográfica', 'camera'),
('Música', 'Géneros musicales, producción y artistas', 'music'),
('Cine y Series', 'Películas, series, análisis y recomendaciones', 'film'),
('Literatura', 'Libros, autores, géneros y clubes de lectura', 'book'),
('Animación', 'Anime, cartoons, motion graphics y stop motion', 'tv'),
('Moda', 'Tendencias, diseño de indumentaria y estilo personal', 'shirt'),
('Deportes', 'Fútbol, básquet, tenis y deportes en general', 'trophy'),
('Fitness', 'Entrenamiento, gimnasio, rutinas y nutrición deportiva', 'dumbbell'),
('Yoga y Meditación', 'Mindfulness, bienestar mental y práctica espiritual', 'heart'),
('Outdoor', 'Senderismo, escalada, camping y deportes al aire libre', 'mountain'),
('Fútbol', 'La pasión argentina: partidos, equipos y jugadores', 'soccer-ball'),
('Viajes', 'Destinos, tips de viaje y experiencias alrededor del mundo', 'plane'),
('Gastronomía', 'Recetas, restaurantes, cocina internacional y foodie', 'utensils'),
('Café y Barismo', 'Cultura del café, métodos de preparación y variedades', 'coffee'),
('Vinos y Bodegas', 'Enología, catas, regiones vitivinícolas y maridajes', 'wine-glass'),
('Ciencia', 'Física, química, biología y divulgación científica', 'flask'),
('Astronomía', 'Cosmos, telescopios, misiones espaciales y astrofísica', 'star'),
('Medio Ambiente', 'Ecología, cambio climático y sustentabilidad', 'leaf'),
('Historia', 'Historia universal, argentina y arqueología', 'landmark'),
('Filosofía', 'Pensamiento crítico, ética y grandes preguntas', 'brain'),
('Educación', 'Pedagogía, recursos didácticos y aprendizaje continuo', 'graduation-cap'),
('Emprendimiento', 'Startups, modelos de negocio e innovación', 'rocket'),
('Marketing Digital', 'SEO, redes sociales, contenido y publicidad online', 'megaphone'),
('Finanzas Personales', 'Ahorro, inversión, criptomonedas y educación financiera', 'dollar-sign'),
('Diseño UX/UI', 'Experiencia de usuario, interfaces y prototipado', 'layout'),
('Mascotas', 'Perros, gatos, cuidado animal y adopción responsable', 'paw'),
('Jardinería', 'Plantas de interior, huerta urbana y paisajismo', 'sprout'),
('DIY y Manualidades', 'Hazlo tú mismo, crafts, woodworking y upcycling', 'scissors'),
('Coleccionismo', 'Figuras, monedas, cartas y objetos de colección', 'archive'),
('Astrología', 'Signos del zodíaco, cartas natales y horóscopo', 'moon');

-- ============================================================
-- SECCIÓN 7: INSERTAR DATOS DE SEED - USUARIOS (Muestra de 30 usuarios)
-- ============================================================

INSERT INTO users (nombre, email, contrasena_hash, bio, fecha_registro, activo) VALUES
('Sofia Franco', 'sofia.franco1@example.com', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMaJobMEV.G3v8s5L4oBo6kS2i', 'Techie de corazón. Python lover.', NOW(), TRUE),
('Mia Soria', 'mia.soria2@example.com', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMaJobMEV.G3v8s5L4oBo6kS2i', 'Gamer y amante del anime.', NOW(), TRUE),
('Lautaro Nicolas Ruiz', 'lautaronicolas.ruiz3@example.com', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMaJobMEV.G3v8s5L4oBo6kS2i', 'Lectora voraz. Café obligatorio.', NOW(), TRUE),
('Geronimo Fernandez', 'geronimo.fernandez4@example.com', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMaJobMEV.G3v8s5L4oBo6kS2i', 'Techie de corazón. Python lover.', NOW(), TRUE),
('Renata Medina', 'renata.medina5@example.com', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMaJobMEV.G3v8s5L4oBo6kS2i', 'Fotógrafo/a aficionado/a y cinéfilo/a.', NOW(), TRUE),
('Dylan Rodriguez', 'dylan.rodriguez6@example.com', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMaJobMEV.G3v8s5L4oBo6kS2i', 'Amante de la música y los viajes.', NOW(), TRUE),
('Maximo Dominguez', 'maximo.dominguez7@example.com', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMaJobMEV.G3v8s5L4oBo6kS2i', 'Fotógrafo/a aficionado/a y cinéfilo/a.', NOW(), TRUE),
('Francesco Molina', 'francesco.molina8@example.com', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMaJobMEV.G3v8s5L4oBo6kS2i', 'Lectora voraz. Café obligatorio.', NOW(), TRUE),
('Joaquin Diaz', 'joaquin.diaz9@example.com', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMaJobMEV.G3v8s5L4oBo6kS2i', 'Apasionado/a por aprender cosas nuevas cada día.', NOW(), TRUE),
('Nicolas Molina', 'nicolas.molina10@example.com', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMaJobMEV.G3v8s5L4oBo6kS2i', 'Emprendedor/a en construcción. Sueño en grande.', NOW(), TRUE),
('Ciro Garcia', 'ciro.garcia11@example.com', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMaJobMEV.G3v8s5L4oBo6kS2i', 'Runner, yoga y mindfulness.', NOW(), TRUE),
('Justina Sanchez', 'justina.sanchez12@example.com', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMaJobMEV.G3v8s5L4oBo6kS2i', 'Sommelier en formación. Vinos mendocinos ❤️', NOW(), TRUE),
('Lautaro Ezequiel Duarte', 'lautaroezequiel.duarte13@example.com', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMaJobMEV.G3v8s5L4oBo6kS2i', 'Apasionado/a por aprender cosas nuevas cada día.', NOW(), TRUE),
('Miguel Angel Gomez', 'miguelangel.gomez14@example.com', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMaJobMEV.G3v8s5L4oBo6kS2i', 'Runner, yoga y mindfulness.', NOW(), TRUE),
('Sofia Belen Gomez', 'sofiabelen.gomez15@example.com', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMaJobMEV.G3v8s5L4oBo6kS2i', 'Gamer y amante del anime.', NOW(), TRUE),
('Felicitas Toledo', 'felicitas.toledo16@example.com', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMaJobMEV.G3v8s5L4oBo6kS2i', 'Emprendedor/a en construcción. Sueño en grande.', NOW(), TRUE),
('Benjamin Navarro', 'benjamin.navarro17@example.com', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMaJobMEV.G3v8s5L4oBo6kS2i', 'Techie de corazón. Python lover.', NOW(), TRUE),
('Nina Garcia', 'nina.garcia18@example.com', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMaJobMEV.G3v8s5L4oBo6kS2i', 'Cocinero/a de fin de semana. Asador/a de alma.', NOW(), TRUE),
('Joaquin Ledesma', 'joaquin.ledesma19@example.com', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMaJobMEV.G3v8s5L4oBo6kS2i', 'Filosofando desde el sillón.', NOW(), TRUE),
('Isabella Romero', 'isabella.romero20@example.com', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMaJobMEV.G3v8s5L4oBo6kS2i', 'Gamer y amante del anime.', NOW(), TRUE),
('Ludmila Castro', 'ludmila.castro21@example.com', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMaJobMEV.G3v8s5L4oBo6kS2i', 'Sommelier en formación. Vinos mendocinos ❤️', NOW(), TRUE),
('Benicio Gomez', 'benicio.gomez22@example.com', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMaJobMEV.G3v8s5L4oBo6kS2i', 'Techie de corazón. Python lover.', NOW(), TRUE),
('Joaquín Correa', 'joaquin.correa23@example.com', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMaJobMEV.G3v8s5L4oBo6kS2i', 'Fotógrafo/a aficionado/a y cinéfilo/a.', NOW(), TRUE),
('Benjamin Rodriguez', 'benjamin.rodriguez24@example.com', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMaJobMEV.G3v8s5L4oBo6kS2i', 'Diseñador/a UX con alma de artista.', NOW(), TRUE),
('Catalina Gonzalez', 'catalina.gonzalez25@example.com', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMaJobMEV.G3v8s5L4oBo6kS2i', 'Emprendedor/a en construcción. Sueño en grande.', NOW(), TRUE),
('Matias Escobar', 'matias.escobar26@example.com', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMaJobMEV.G3v8s5L4oBo6kS2i', 'Amante de la música y los viajes.', NOW(), TRUE),
('Pedro Lopez', 'pedro.lopez27@example.com', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMaJobMEV.G3v8s5L4oBo6kS2i', 'Diseñador/a UX con alma de artista.', NOW(), TRUE),
('Lorenzo Sosa', 'lorenzo.sosa28@example.com', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMaJobMEV.G3v8s5L4oBo6kS2i', 'Lectora voraz. Café obligatorio.', NOW(), TRUE),
('Juan Martin Gonzalez', 'juanmartin.gonzalez29@example.com', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMaJobMEV.G3v8s5L4oBo6kS2i', 'Cocinero/a de fin de semana. Asador/a de alma.', NOW(), TRUE),
('Bruno Molina', 'bruno.molina30@example.com', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMaJobMEV.G3v8s5L4oBo6kS2i', 'Sommelier en formación. Vinos mendocinos ❤️', NOW(), TRUE);

-- ============================================================
-- SECCIÓN 8: INSERTAR DATOS DE SEED - INTERESES DE USUARIOS
-- ============================================================

INSERT INTO user_interests (user_id, category_id, nivel_interes, fecha_agregado) VALUES
-- Sofia Franco (usuario 1)
(1, 1, 5, NOW()),
(1, 2, 4, NOW()),
(1, 3, 5, NOW()),

-- Mia Soria (usuario 2)
(2, 5, 5, NOW()),
(2, 11, 5, NOW()),
(2, 8, 3, NOW()),
(2, 9, 4, NOW()),

-- Lautaro Nicolas Ruiz (usuario 3)
(3, 10, 5, NOW()),
(3, 19, 4, NOW()),
(3, 20, 3, NOW()),

-- Geronimo Fernandez (usuario 4)
(4, 1, 4, NOW()),
(4, 3, 5, NOW()),

-- Renata Medina (usuario 5)
(5, 7, 5, NOW()),
(5, 9, 4, NOW()),
(5, 8, 3, NOW()),

-- Dylan Rodriguez (usuario 6)
(6, 8, 5, NOW()),
(6, 18, 4, NOW()),

-- Maximo Dominguez (usuario 7)
(7, 7, 4, NOW()),
(7, 9, 5, NOW()),

-- Francesco Molina (usuario 8)
(8, 10, 5, NOW()),
(8, 24, 3, NOW()),

-- Joaquin Diaz (usuario 9)
(9, 27, 4, NOW()),
(9, 28, 5, NOW()),

-- Nicolas Molina (usuario 10)
(10, 28, 5, NOW()),
(10, 13, 4, NOW());

-- ============================================================
-- SECCIÓN 9: RESETEAR SECUENCIAS AUTOINCREMENTAL
-- ============================================================

SELECT pg_catalog.setval('users_user_id_seq', 31, true);
SELECT pg_catalog.setval('categories_category_id_seq', 36, true);
SELECT pg_catalog.setval('photos_photo_id_seq', 1, false);
SELECT pg_catalog.setval('auditoria_emails_auditoria_id_seq', 1, false);
SELECT pg_catalog.setval('auditoria_admins_auditoria_id_seq', 1, false);

-- ============================================================
-- PostgreSQL database dump complete
-- ============================================================