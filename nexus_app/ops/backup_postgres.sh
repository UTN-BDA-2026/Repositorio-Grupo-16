#!/bin/bash
# Backup de PostgreSQL: lógico (pg_dump) + WAL continuo (PITR)

set -euo pipefail

BACKUP_DIR="./db/backups/postgres"
WAL_ARCHIVE_DIR="./db/backups/wal_archive"
FECHA=$(date +"%Y%m%d_%H%M%S")
ARCHIVO_SALIDA="${BACKUP_DIR}/nexus_postgres_${FECHA}.dump"

# Creamos las carpetas de destino automáticamente si no existen
mkdir -p "${BACKUP_DIR}"
mkdir -p "${WAL_ARCHIVE_DIR}"

# ── 1. BACKUP LÓGICO BASE (pg_dump) ──────────────────────────────────────────
echo "Iniciando volcado lógico de PostgreSQL..."
# Usamos ${POSTGRES_USER} en lugar de 'postgres' hardcodeado
# El superusuario del proyecto es nexus_user (definido en POSTGRES_USER)
docker-compose exec -T postgres \
  pg_dump -U "${POSTGRES_USER}" -Fc "${POSTGRES_DB}" > "${ARCHIVO_SALIDA}"
echo "✓ Backup lógico guardado en: ${ARCHIVO_SALIDA}"

# ── 2. CHECKPOINT WAL (PITR) ──────────────────────────────────────────────────
echo "Forzando checkpoint WAL para garantizar consistencia..."
# pg_basebackup genera una copia base del cluster compatible con PITR
docker-compose exec -T postgres \
  pg_basebackup \
    -U "${POSTGRES_USER}" \
    -D /var/lib/postgresql/data/pg_archive/basebackup_${FECHA} \
    -Ft \
    -z \
    --checkpoint=fast
echo "✓ Base WAL guardada en pg_archive/basebackup_${FECHA}"

echo ""
echo "✓ Proceso de backup completo (lógico + WAL/PITR) finalizado."