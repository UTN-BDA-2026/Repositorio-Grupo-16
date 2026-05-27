
-- TRIGGER 1: AUDITORÍA DE CAMBIO DE EMAIL

CREATE TABLE IF NOT EXISTS auditoria_emails (
    auditoria_id SERIAL PRIMARY KEY,
    user_id INT NOT NULL,
    email_anterior VARCHAR(320),
    email_nuevo VARCHAR(320),
    fecha_cambio TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

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