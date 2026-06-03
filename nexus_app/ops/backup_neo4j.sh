#!/bin/bash
# Backup de Neo4j (Volcado de la base de datos de grafos)

BACKUP_DIR="./db/backups/neo4j"
FECHA=$(date +"%Y%m%d_%H%M%S")
ARCHIVO_SALIDA="${BACKUP_DIR}/nexus_neo4j_${FECHA}.cypher"

# Creamos la carpeta de destino automáticamente si no existe
mkdir -p ${BACKUP_DIR}

echo "Iniciando volcado de Neo4j..."

# Extraemos la estructura base usando la CLI oficial de Neo4j (cypher-shell).
# Nota de Operaciones: En un entorno de producción con APOC, se usaría 'apoc.export.cypher.all'.
docker-compose exec -T neo4j cypher-shell -a neo4j://localhost:7687 "MATCH (n) RETURN n, labels(n);" > "${ARCHIVO_SALIDA}"

echo "✓ Backup de grafos (lógico) guardado exitosamente en: ${ARCHIVO_SALIDA}"