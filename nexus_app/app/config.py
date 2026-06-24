import logging
import os
from typing import Optional, Tuple, Type
from pydantic_settings import BaseSettings, PydanticBaseSettingsSource

# Directorio estándar donde Docker monta los secrets (docker-compose / swarm).
# Cada secret se expone como un archivo: /run/secrets/<nombre_del_secret>
# El nombre del archivo debe coincidir con el nombre del campo de esta clase.
DIRECTORIO_SECRETS = "/run/secrets"


class Settings(BaseSettings):
    """
    Clase de configuración para la aplicación Nexus.
    Carga variables de entorno del archivo .env y las valida estrictamente.
    Las contraseñas se leen desde Docker Secrets (/run/secrets) cuando existen.
    Incluye configuración avanzada para SQLAlchemy y Neo4j con logging de auditoría.
    """

    # ============ Configuración de PostgreSQL ============
    postgres_host: str = "localhost"
    postgres_port: int = 5432
    postgres_db: str = "nexus_db"
    api_db_user: str = "nexus_app_user"
    api_db_password: str

    # Pool de conexiones SQLAlchemy
    sqlalchemy_pool_size: int = 5
    sqlalchemy_max_overflow: int = 10
    sqlalchemy_pool_timeout: int = 30
    sqlalchemy_echo: bool = True  # Log todas las sentencias SQL en DEBUG

    # ============ Configuración de Neo4j ============
    neo4j_host: str = "localhost"
    neo4j_port: int = 7687
    neo4j_user: str = "neo4j"
    neo4j_password: str
    neo4j_database: str = "neo4j"

    # Timeout para transacciones Neo4j
    neo4j_connection_timeout: int = 30
    neo4j_command_timeout: int = 60

    # ============ Configuración de FastAPI ============
    fastapi_host: str = "0.0.0.0"
    fastapi_port: int = 8000
    fastapi_debug: bool = False

    # ============ Configuración de Redis ============
    redis_host: str = "localhost"
    redis_port: int = 6379
    redis_password: Optional[str] = None
    redis_db: int = 0

    # ============ Entorno y Logging ============
    environment: str = "development"
    log_level: str = "DEBUG"
    clave_secreta_jwt: str = "clave_secreta_nexus_para_desarrollo"

    class Config:
        """Configuración de ajustes de Pydantic."""
        env_file = ".env"
        env_file_encoding = "utf-8"
        case_sensitive = False
        # Lee secrets montados por Docker en /run/secrets/<nombre_campo>.
        # Solo se activa si el directorio existe (en contenedor/producción),
        # de modo que en local sin Docker sigue funcionando con el .env.
        secrets_dir = DIRECTORIO_SECRETS if os.path.isdir(DIRECTORIO_SECRETS) else None

    @classmethod
    def settings_customise_sources(
        cls,
        settings_cls: Type[BaseSettings],
        init_settings: PydanticBaseSettingsSource,
        env_settings: PydanticBaseSettingsSource,
        dotenv_settings: PydanticBaseSettingsSource,
        file_secret_settings: PydanticBaseSettingsSource,
    ) -> Tuple[PydanticBaseSettingsSource, ...]:
        """
        Prioridad de fuentes (de mayor a menor):
          1. Argumentos pasados al instanciar (init)
          2. Secrets de Docker (/run/secrets/...)  <-- contraseñas
          3. Variables de entorno
          4. Archivo .env
        Así, si un secret existe, gana sobre el .env y las variables de entorno.
        """
        return (
            init_settings,
            file_secret_settings,
            env_settings,
            dotenv_settings,
        )

    def __init__(self, **data):
        super().__init__(**data)
        # Validaciones críticas
        if not self.api_db_password:
            raise ValueError(
                "api_db_password es obligatorio: definilo como secret en "
                "/run/secrets/api_db_password o como API_DB_PASSWORD en .env"
            )
        if not self.neo4j_password:
            raise ValueError(
                "neo4j_password es obligatorio: definilo como secret en "
                "/run/secrets/neo4j_password o como NEO4J_PASSWORD en .env"
            )

    @property
    def postgres_url_sqlalchemy(self) -> str:
        """
        Construir cadena de conexión con usuario de aplicación (permisos restringidos).
        """
        base_url = (
            f"postgresql+psycopg2://{self.api_db_user}:{self.api_db_password}@"
            f"{self.postgres_host}:{self.postgres_port}/{self.postgres_db}"
        )
        if self.environment == "production":
            base_url += "?sslmode=require"
        return base_url

    @property
    def neo4j_uri(self) -> str:
        """
        Construir URI de Neo4j para el driver.
        Formato: neo4j://host:port
        """
        return f"neo4j://{self.neo4j_host}:{self.neo4j_port}"

    @property
    def redis_url(self) -> str:
        """Construir URL de Redis con autenticación."""
        if self.redis_password:
            return f"redis://:{self.redis_password}@{self.redis_host}:{self.redis_port}/{self.redis_db}"
        return f"redis://{self.redis_host}:{self.redis_port}/{self.redis_db}"

    @staticmethod
    def configurar_logging():
        """
        Configura logging DEBUG detallado con auditoría de transacciones.
        Habilita logs de:
        - SQLAlchemy: sentencias SQL generadas
        - Neo4j: consultas Cypher ejecutadas
        - Límites transaccionales (BEGIN, COMMIT, ROLLBACK)
        """
        # Configurar formato de log con timestamp y módulo
        formato_log = (
            "%(asctime)s - %(name)s - %(levelname)s - "
            "[%(filename)s:%(lineno)d] - %(message)s"
        )

        # Configuración básica de logging
        logging.basicConfig(
            level=logging.DEBUG,
            format=formato_log,
            handlers=[
                logging.StreamHandler(),  # Salida estándar
                logging.FileHandler("nexus_audit.log")  # Archivo de auditoría
            ]
        )

        # Habilitar logs de SQLAlchemy (engine)
        logging.getLogger("sqlalchemy.engine").setLevel(logging.DEBUG)

        # Habilitar logs de SQLAlchemy ORM
        logging.getLogger("sqlalchemy.orm").setLevel(logging.DEBUG)

        # Habilitar logs de Neo4j driver
        logging.getLogger("neo4j").setLevel(logging.DEBUG)

        return logging.getLogger(__name__)


def get_settings() -> Settings:
    """Obtener instancia de configuración de la aplicación."""
    return Settings()