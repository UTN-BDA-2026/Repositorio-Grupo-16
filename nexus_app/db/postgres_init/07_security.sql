-- ============================================================
-- Seguridad a Nivel Motor
-- Se ejecuta automáticamente al iniciar el contenedor porque está en /docker-entrypoint-initdb.d/
-- ============================================================
-- Crear el usuario que usará la API FastAPI NO es superusuario
-- ============================================================
-- CONFIGURACIÓN DE SEGURIDAD DEL SISTEMA
-- ============================================================
-- Deshabilitar el acceso como superusuario desde la red
ALTER SYSTEM SET password_encryption = 'scram-sha-256';

-- Recargar configuración
SELECT pg_reload_conf();

-- ============================================================
-- Usar el usuario que Docker ya creó (POSTGRES_USER)
-- El usuario nexus_user ya existe, solo necesita permisos
-- ============================================================
-- Crear usuario de solo lectura para Neo4j y reportes (OPCIONAL)
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'nexus_readonly') THEN
        -- La contraseña puede venir de variable de entorno o usar una por defecto
        CREATE ROLE nexus_readonly WITH LOGIN PASSWORD 'nexus_readonly_dev_change_in_prod';
    END IF;
END
$$;

-- Crear usuario para backups automatizados (OPCIONAL)
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'nexus_backup') THEN
        CREATE ROLE nexus_backup WITH LOGIN PASSWORD 'nexus_backup_dev_change_in_prod';
    END IF;
END
$$;


-- ============================================================
-- Revocar permisos peligrosos por defecto
-- ============================================================
REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM PUBLIC;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM PUBLIC;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA public FROM PUBLIC;


-- ============================================================
-- Configurar permisos para el usuario principal (nexus_user)
-- ============================================================

-- Obtener el nombre del usuario principal desde variable (si está disponible), 'nexus_user' por defecto
DO $$
DECLARE
    v_app_user VARCHAR := COALESCE(current_setting('app.postgres_user', true), 'nexus_user');
BEGIN
    -- Permiso para usar el esquema
    EXECUTE format('GRANT USAGE ON SCHEMA public TO %I', v_app_user);
    
    -- Tablas principales: SELECT, INSERT, UPDATE
    EXECUTE format(
        'GRANT SELECT, INSERT, UPDATE ON TABLE 
            users, photos, categories, user_interests,
            historial_actividad, logs_conexiones, user_connections,
            roles
        TO %I', v_app_user
    );
    
    -- Tablas de auditoría: solo INSERT (triggers escriben)
    EXECUTE format(
        'GRANT INSERT ON TABLE auditoria_emails, auditoria_admins TO %I',
        v_app_user
    );
    
    -- Secuencias: necesario para SERIAL/IDENTITY
    EXECUTE format(
        'GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO %I',
        v_app_user
    );
    
    -- IMPORTANTE: Permisos sobre PROCEDIMIENTOS ALMACENADOS
    EXECUTE format(
        'GRANT EXECUTE ON ROUTINE pr_actualizar_interes_seguro(int, int, smallint) TO %I',
        v_app_user
    );
    EXECUTE format(
        'GRANT EXECUTE ON ROUTINE pr_desactivar_cuenta_segura(int) TO %I',
        v_app_user
    );
    EXECUTE format(
        'GRANT EXECUTE ON ROUTINE pr_crear_conexion_segura(int, int) TO %I',
        v_app_user
    );
    EXECUTE format(
        'GRANT EXECUTE ON ROUTINE pr_actualizar_perfil_optimista(int, text, int) TO %I',
        v_app_user
    );
    
    -- Aplicar a tablas y secuencias FUTURAS
    EXECUTE format(
        'ALTER DEFAULT PRIVILEGES IN SCHEMA public
            GRANT SELECT, INSERT, UPDATE ON TABLES TO %I',
        v_app_user
    );
    EXECUTE format(
        'ALTER DEFAULT PRIVILEGES IN SCHEMA public
            GRANT USAGE, SELECT ON SEQUENCES TO %I',
        v_app_user
    );
    EXECUTE format(
        'ALTER DEFAULT PRIVILEGES IN SCHEMA public
            GRANT EXECUTE ON FUNCTIONS TO %I',
        v_app_user
    );
    
    RAISE NOTICE 'Permisos configurados para usuario: %', v_app_user;
END
$$;


-- ============================================================
-- PASO 4: Configurar permisos para nexus_readonly: (Neo4j, reportes, auditoría externa)
-- ============================================================

GRANT USAGE ON SCHEMA public TO nexus_readonly;

-- Solo SELECT en datos
GRANT SELECT ON TABLE
    users, photos, categories, user_interests, roles,
    historial_actividad, logs_conexiones, user_connections,
    auditoria_emails, auditoria_admins
TO nexus_readonly;

-- Aplicar a tablas futuras
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT SELECT ON TABLES TO nexus_readonly;

-- ============================================================
-- PASO 5: Configurar permisos para nexus_backup
-- ============================================================
GRANT USAGE ON SCHEMA public TO nexus_backup;

GRANT SELECT ON ALL TABLES IN SCHEMA public TO nexus_backup;

-- Permite ejecutar pg_dump/pg_restore
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT SELECT ON TABLES TO nexus_backup;

-- ============================================================
-- NOTA: el bloque de verificación (SELECT de control sobre pg_roles e
-- information_schema) fue removido porque referenciaba columnas
-- inexistentes (sequence_name / table_schema) y abortaba el init.
-- Los GRANT/REVOKE y la creación de roles ya se aplicaron arriba.
-- Para auditar permisos manualmente, usar \du y \dp desde psql.
-- ============================================================
