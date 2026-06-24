# Repositorio-Grupo-16
Integrantes: Bettiol, Giuliana - Martínez Oldani, Jimena - Rossi, Emiliano - Ruiz Andeola, Alejandro - Sanchez, Juan Ignacio
 
 Contexto de "Nexus":
 -una plataforma social diseñada para conectar personas basándose en la afinidad de sus intereses y hobbies.

Arquitectura de Datos:
-PostgreSQL:  gestionando los perfiles de usuario, autenticación, galería de fotos y el diccionario de categorías de interés. 

-Neo4j: Motor de grafos encargado exclusivamente de procesar las interacciones sociales.

Autenticación JWT:
- `POST /login`: endpoint de inicio de sesión que recibe email y password y devuelve un token JWT.
- `GET /me`: endpoint protegido que valida el token Bearer y retorna los datos del usuario autenticado.

La autenticación está implementada en `nexus_app/app/auth.py` y se integra con el resto del proyecto mediante `nexus_app/app/main.py`.

## Configuración y arranque del proyecto

1. Entrar en el directorio de la app:
   ```bash
   cd nexus_app
   ```
2. Copiar el archivo de ejemplo de variables de entorno:
   ```bash
   cp .env.example .env
   ```
3. Crear el directorio `secrets` y los archivos que Docker monta como secrets:
   ```bash
   mkdir -p secrets
   echo "tu_api_db_password" > secrets/api_db_password.txt
   echo "tu_neo4j_password" > secrets/neo4j_password.txt
   echo "tu_redis_password" > secrets/redis_password.txt
   echo "tu_clave_secreta_jwt" > secrets/clave_secreta_jwt.txt
   ```
4. Limpiar todos los datos existentes y levantar el stack desde cero:
   ```bash
   
   ``` `docker compose down -v` en vez de `make clean`.

## Qué se validó

- En `nexus_app/db/postgres_init/06_concurrency.sql` existen los procedimientos:
  - `pr_actualizar_interes_seguro(int, int, smallint)`
  - `pr_desactivar_cuenta_segura(int)`
  - `pr_crear_conexion_segura(int, int)`
  - `pr_actualizar_perfil_optimista(int, text, int)`
- En `nexus_app/db/postgres_init/03_triggers.sql` están definidos los triggers y funciones de auditoría/reglas de negocio.
- `nexus_app_user` es el rol usado por la API y se configura en `nexus_app/db/postgres_init/08_app_user.sql`.

## Redis y rate limiter de login

- Redis arranca con contraseña usando `REDIS_PASSWORD` en `nexus_app/docker-compose.yml`.
- `nexus_app/app/config.py` genera la URL de Redis con contraseña cuando `redis_password` está definida.
- El rate limiter está implementado en `nexus_app/app/services/rate_limiter.py` y usado desde `nexus_app/app/auth.py`.
- Comportamiento actual:
  - máximo de 5 intentos fallidos
  - bloqueo de 15 minutos
  - claves Redis usadas:
    - `login_intentos:<email>`
    - `login_bloqueado:<email>`
  - al iniciar sesión con éxito, se borran los intentos acumulados.

## Recomendaciones de validación

1. Abrir PostgreSQL:
   ```bash
   make shell-postgres
   ```
2. Ver permisos por tabla para `nexus_app_user`:
   ```sql
   SELECT grantee, table_name, string_agg(privilege_type, ', ' ORDER BY privilege_type) AS permisos
   FROM information_schema.role_table_grants
   WHERE table_schema = 'public'
     AND grantee = 'nexus_app_user'
   GROUP BY grantee, table_name
   ORDER BY grantee, table_name;
   ```
3. Ver permisos de ejecución de funciones:
   ```sql
   SELECT grantee, routine_name, privilege_type
   FROM information_schema.role_routine_grants
   WHERE routine_schema = 'public'
     AND grantee = 'nexus_app_user'
   ORDER BY grantee, routine_name;
   ```
4. Probar `/login` con contraseña incorrecta 5 veces para confirmar que el bloqueo por intentos fallidos funciona.
