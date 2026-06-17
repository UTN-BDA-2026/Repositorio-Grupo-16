-- TRIGGER 1: AUDITORÍA DE CAMBIO DE EMAIL

CREATE TABLE IF NOT EXISTS auditoria_emails (
    auditoria_id SERIAL PRIMARY KEY,
    user_id INT NOT NULL,
    email_anterior VARCHAR(320),
    email_nuevo VARCHAR(320),
    fecha_cambio TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- índice para consultas por usuario
CREATE INDEX IF NOT EXISTS idx_auditoria_emails_user_id ON auditoria_emails(user_id);
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


-- TRIGGER 2: REGLA DE NEGOCIO - LÍMITE DE FOTOS PERMITIDAS

CREATE OR REPLACE FUNCTION fn_limite_fotos_perfil()
RETURNS TRIGGER AS $$
DECLARE
    cantidad_actual INT;
BEGIN
    IF NEW.user_id IS NULL THEN
        RAISE EXCEPTION 'Regla de negocio: user_id no puede ser NULL en photos.';
    END IF;

    -- Evitar condiciones de carrera: bloquear la fila del usuario antes de contar
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

    -- Usar límites de palabra robustos para evitar falsos positivos/negativos
    IF NEW.bio ~* '(?<!\\w)(feo|fea|gord[oa]|flac[oa]|horrible|asqueros[oa])(?!\\w)' THEN
        RAISE EXCEPTION 'Regla de comunidad: Tu descripción contiene lenguaje no permitido. Fomentamos un espacio ético y libre de prejuicios sobre los cuerpos.'
        USING ERRCODE = 'P0001';
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Asegurar idempotencia: eliminar trigger previo si existe y (re)crear
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

--  para proteger múltiples tablas
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

-- ============================================================
--  Auditoría de acciones de Administradores (RBAC)
--  Trazabilidad: registra cuando un admin modifica datos de otro usuario
-- ============================================================
-- TABLA: auditoria_admins
-- Se llena automáticamente cuando un ADMINISTRADOR modifica
-- datos sensibles de otro usuario (nombre, email, bio, rol, activo).
-- Esta tabla nunca se edita manualmente.
-- ============================================================
CREATE TABLE IF NOT EXISTS auditoria_admins (
    auditoria_id     SERIAL PRIMARY KEY,
    fecha_hora       TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    admin_user_id    INT NOT NULL,        -- Quién hizo el cambio
    usuario_id       INT NOT NULL,        -- A quién le modificaron los datos
    campo_modificado VARCHAR(100),        -- Qué campo cambió (ej: 'email', 'rol_id')
    valor_anterior   TEXT,               -- Cómo estaba antes
    valor_nuevo      TEXT                -- Cómo quedó después
);

CREATE INDEX IF NOT EXISTS idx_auditoria_admins_admin   ON auditoria_admins(admin_user_id);
CREATE INDEX IF NOT EXISTS idx_auditoria_admins_usuario ON auditoria_admins(usuario_id);


-- ============================================================
-- FUNCIÓN: fn_auditar_accion_admin
-- Se ejecuta automáticamente al hacer UPDATE en users.
-- Solo registra si quien modifica es un ADMINISTRADOR (rol_id = 3)
-- y está tocando los datos de OTRO usuario (no los propios).
--
-- La app debe setear antes del UPDATE:
--   SET LOCAL app.current_user_id = '<id_del_admin>';
-- ============================================================
CREATE OR REPLACE FUNCTION fn_auditar_accion_admin()
RETURNS TRIGGER AS $$
DECLARE
    v_admin_id  INT;
    v_rol_admin INT;
BEGIN
    -- Lee el ID del usuario que está haciendo el cambio desde la sesión.
    -- Si no está seteado (ej: migraciones), usamos 0 y no auditamos.
    BEGIN
        v_admin_id := current_setting('app.current_user_id')::INT;
    EXCEPTION WHEN OTHERS THEN
        v_admin_id := 0;
    END;

    -- Solo audita si es un admin modificando a OTRO usuario
    IF v_admin_id != 0 AND v_admin_id != NEW.user_id THEN

        SELECT rol_id INTO v_rol_admin
        FROM users WHERE user_id = v_admin_id;

        -- rol_id = 3 → administrador (según tabla roles)
        IF v_rol_admin = 3 THEN

            IF OLD.nombre IS DISTINCT FROM NEW.nombre THEN
                INSERT INTO auditoria_admins
                    (admin_user_id, usuario_id, campo_modificado, valor_anterior, valor_nuevo)
                VALUES (v_admin_id, NEW.user_id, 'nombre', OLD.nombre, NEW.nombre);
            END IF;

            IF OLD.email IS DISTINCT FROM NEW.email THEN
                INSERT INTO auditoria_admins
                    (admin_user_id, usuario_id, campo_modificado, valor_anterior, valor_nuevo)
                VALUES (v_admin_id, NEW.user_id, 'email', OLD.email, NEW.email);
            END IF;

            IF OLD.bio IS DISTINCT FROM NEW.bio THEN
                INSERT INTO auditoria_admins
                    (admin_user_id, usuario_id, campo_modificado, valor_anterior, valor_nuevo)
                VALUES (v_admin_id, NEW.user_id, 'bio', OLD.bio, NEW.bio);
            END IF;

            IF OLD.rol_id IS DISTINCT FROM NEW.rol_id THEN
                INSERT INTO auditoria_admins
                    (admin_user_id, usuario_id, campo_modificado, valor_anterior, valor_nuevo)
                VALUES (v_admin_id, NEW.user_id, 'rol_id',
                        OLD.rol_id::TEXT, NEW.rol_id::TEXT);
            END IF;

            IF OLD.activo IS DISTINCT FROM NEW.activo THEN
                INSERT INTO auditoria_admins
                    (admin_user_id, usuario_id, campo_modificado, valor_anterior, valor_nuevo)
                VALUES (v_admin_id, NEW.user_id, 'activo',
                        OLD.activo::TEXT, NEW.activo::TEXT);
            END IF;

        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- TRIGGER: trg_auditoria_admins
-- Se dispara DESPUÉS de cada UPDATE en users.
-- este registra SOLO los que hace un administrador sobre otro usuario.
-- ============================================================
DROP TRIGGER IF EXISTS trg_auditoria_admins ON users;
CREATE TRIGGER trg_auditoria_admins
    AFTER UPDATE ON users
    FOR EACH ROW
    EXECUTE FUNCTION fn_auditar_accion_admin();