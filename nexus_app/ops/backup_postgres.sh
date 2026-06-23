#!/bin/bash
# Backup de PostgreSQL: lógico (pg_dump) + WAL continuo (PITR)

set -euo pipefail

# Cargamos las variables del .env para que POSTGRES_USER y POSTGRES_DB
# estén disponibles al correr desde el Makefile
set -a
source .env
set +a

BACKUP_DIR="./db/backups/postgres"
FECHA=$(date +"%Y%m%d_%H%M%S")
ARCHIVO_SALIDA="${BACKUP_DIR}/nexus_postgres_${FECHA}.dump"

mkdir -p "${BACKUP_DIR}"

# ── 1. BACKUP LÓGICO BASE (pg_dump) ──────────────────────────────────────────
echo "Iniciando volcado lógico de PostgreSQL..."
docker-compose exec -T postgres \
  pg_dump -U "${POSTGRES_USER}" -Fc "${POSTGRES_DB}" > "${ARCHIVO_SALIDA}"
echo "✓ Backup lógico guardado en: ${ARCHIVO_SALIDA}"

# ── 2. BASE WAL PARA PITR (pg_basebackup) ────────────────────────────────────
echo "Generando copia base WAL para PITR..."
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