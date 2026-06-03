#!/bin/bash
# Backup de PostgreSQL utilizando formato custom (-Fc)

BACKUP_DIR="./db/backups/postgres"
FECHA=$(date +"%Y%m%d_%H%M%S")
ARCHIVO_SALIDA="${BACKUP_DIR}/nexus_postgres_${FECHA}.dump"

# Creamos la carpeta de destino automáticamente si no existe
mkdir -p ${BACKUP_DIR}

echo "Iniciando volcado de PostgreSQL..."
# Ejecutamos pg_dump dentro del contenedor de Postgres
# -T desactiva la asignación de terminal (necesario para redirigir el texto a un archivo)
# -Fc indica el formato custom (optimizado y comprimido, como pidió el profesor)
docker-compose exec -T postgres pg_dump -U postgres -Fc nexus_db > "${ARCHIVO_SALIDA}"

echo "✓ Backup relacional guardado exitosamente en: ${ARCHIVO_SALIDA}"