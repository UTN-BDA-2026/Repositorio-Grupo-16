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

## Arquitectura

Nexus usa motores especializados : PostgreSQL gestiona la información relacional (perfiles de usuario, autenticación, galería de fotos y diccionario de categorías); Neo4j se encarga del grafo social y de los algoritmos de recomendación; Redis se utiliza para caché y para el control de intentos de login (rate limiter); Traefik actúa como la única puerta de entrada HTTP al sistema, exponiendo el API y el dashboard.

## Cómo levantar el proyecto

Sigue estos pasos exactos desde la raíz del repositorio para levantar el stack con Docker Compose.

Requisitos previos:
- Tener instalado Docker y Docker Compose.

Pasos:

1. Clonar el repositorio (si aún no lo hiciste) y situarte en la carpeta del proyecto:

```bash
git clone <url-del-repo>
cd Repositorio-Grupo-16
```

2. Ir al directorio de la app:

```bash
cd nexus_app
```

3. Copiar el archivo de variables de entorno de ejemplo:

Linux / macOS:
```bash
cp .env.example .env
```

PowerShell (Windows):
```powershell
Copy-Item .env.example .env
```

4. Crear la carpeta `secrets` y añadir los archivos que Docker monta como secrets. Reemplaza los valores entre comillas por las contraseñas reales que quieras usar.

Linux / macOS:
```bash
mkdir -p secrets
echo "tu_api_db_password" > secrets/api_db_password.txt
echo "tu_neo4j_password" > secrets/neo4j_password.txt
echo "tu_redis_password" > secrets/redis_password.txt
echo "tu_clave_secreta_jwt" > secrets/clave_secreta_jwt.txt
```

PowerShell (Windows):
```powershell
New-Item -ItemType Directory -Path secrets -Force
Set-Content -Path .\secrets\api_db_password.txt -Value "tu_api_db_password"
Set-Content -Path .\secrets\neo4j_password.txt -Value "tu_neo4j_password"
Set-Content -Path .\secrets\redis_password.txt -Value "tu_redis_password"
Set-Content -Path .\secrets\clave_secreta_jwt.txt -Value "tu_clave_secreta_jwt"
```

5. Levantar el stack (desde `nexus_app`):

```bash
docker compose up -d --build
```

6. Verificar que los contenedores están arriba:

```bash
docker compose ps
```

7. Endpoints útiles:
- API (servida a través de Traefik): http://localhost/
- Traefik dashboard: http://localhost:8080
- Neo4j Browser: http://localhost:7474
- PostgreSQL: puerto configurado en `.env` (variable `POSTGRES_PORT`)

8. Parar y eliminar contenedores y volúmenes (limpieza completa):

```bash
docker compose down -v
```

Si necesitas entrar en la base de datos PostgreSQL o revisar los scripts de inicialización, revisa `nexus_app/db/postgres_init`.

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
