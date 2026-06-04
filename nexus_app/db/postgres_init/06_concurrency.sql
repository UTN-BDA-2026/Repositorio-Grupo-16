--  CONTROL DE CONCURRENCIA PESIMISTA 

-- 1. PROCEDIMIENTO: ACTUALIZACIÓN SEGURA DE INTERESES
--  Un usuario actualiza su "nivel_interes" en una categoría específica. La solución es implementar un Bloqueo pesimista a nivel de fila  para evitar "Lost Updates".

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


-- 2. PROCEDIMIENTO: DESACTIVACIÓN AISLADA DE CUENTA
-- El usuario solicita eliminar su cuenta.Bloqueo pesimista para evitar inconsistencias durante la baja.

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


-- 3. PROCEDIMIENTO: CREACIÓN DE MATCH / CONEXIÓN SEGURA
--  Dos usuarios se dan "Conectar" en el exacto mismo milisegundo. Bloqueo de las filas padre ordenadas para evitar Deadlocks y duplicados.


CREATE TABLE IF NOT EXISTS user_connections (
    user_id_1 INT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    user_id_2 INT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    fecha_conexion TIMESTAMP NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id_1, user_id_2)
);

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

-- CONTROL DE CONCURRENCIA OPTIMISTA
-- 2.A. ADAPTACIÓN DEL ESQUEMA
-- Nota: este cambio de esquema es un ejemplo; en un entorno real conviene migrarlo desde un script de DDL/migración independiente.
ALTER TABLE users ADD COLUMN IF NOT EXISTS version INT NOT NULL DEFAULT 1;
COMMENT ON COLUMN users.version IS 'Control de concurrencia optimista. Se incrementa en cada actualización del perfil.';

-- 4. PROCEDIMIENTO: ACTUALIZACIÓN DE PERFIL CON CONTROL OPTIMISTA
-- Edición de la biografía del usuario. Sin candados. Se actualiza solo si la versión leída por la app coincide con la BD.

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