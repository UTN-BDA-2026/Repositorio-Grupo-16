-- Rol de aplicacion con permisos restringidos que usa la API FastAPI.
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'nexus_app_user') THEN
        CREATE ROLE nexus_app_user WITH LOGIN PASSWORD 'nexus_app_pass_123';
    END IF;
END
$$;
 
GRANT USAGE ON SCHEMA public TO nexus_app_user;
 
GRANT SELECT, INSERT, UPDATE ON TABLE
    users, photos, categories, user_interests,
    historial_actividad, logs_conexiones, user_connections, roles
TO nexus_app_user;
 
GRANT INSERT ON TABLE auditoria_emails, auditoria_admins TO nexus_app_user;
 
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO nexus_app_user;
 
-- Permisos sobre tablas/secuencias/funciones FUTURAS
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT SELECT, INSERT, UPDATE ON TABLES TO nexus_app_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT USAGE, SELECT ON SEQUENCES TO nexus_app_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT EXECUTE ON FUNCTIONS TO nexus_app_user;
