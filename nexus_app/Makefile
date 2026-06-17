.PHONY: help up down logs build restart clean ps test lint shell-postgres backup restore

help:
	@echo "Comandos de Gestión de Docker para Nexus"
	@echo "========================================"
	@echo "make up       - Inicia todos los servicios (PostgreSQL, Neo4j, FastAPI)"
	@echo "make down     - Detiene todos los servicios"
	@echo "make build    - Construye la imagen de FastAPI"
	@echo "make restart  - Reinicia todos los servicios"
	@echo "make logs     - Ver registros de todos los servicios"
	@echo "make ps       - Mostrar contenedores en ejecución"
	@echo "make clean    - Elimina todos los contenedores y volúmenes"
	@echo "make test     - Ejecutar pruebas"
	@echo "make lint     - Ejecutar linters"
	@echo "make backup   - Genera respaldos de las bases de datos (PostgreSQL y Neo4j)"
	@echo "make restore  - Restaura las bases de datos desde los respaldos"

up:
	docker-compose up -d
	@echo "✓ ¡Todos los servicios iniciados correctamente!"
	@echo "  FastAPI: http://localhost:8000"
	@echo "  PostgreSQL: localhost:5432"
	@echo "  Navegador Neo4j: http://localhost:7474"

down:
	docker-compose down

build:
	docker-compose build

restart:
	docker-compose restart

logs:
	docker-compose logs -f

ps:
	docker-compose ps

clean:
	docker-compose down -v
	@echo "✓ ¡Todos los contenedores y volúmenes eliminados!"

test:
	docker-compose exec fastapi pytest

lint:
	docker-compose exec fastapi black . && docker-compose exec fastapi flake8 .

shell-postgres:
	docker-compose exec postgres psql -U postgres -d nexus_db

backup:
	@echo "Generando backup de PostgreSQL..."
	@bash ops/backup_postgres.sh
	@echo "Generando backup de Neo4j..."
	@bash ops/backup_neo4j.sh
	@echo "✓ ¡Backups finalizados!"

restore:
	@echo "ATENCIÓN: La restauración requerirá indicar qué archivo montar."
	@echo "Estructura base preparada para la defensa."