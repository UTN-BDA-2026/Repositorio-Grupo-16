import logging
from typing import Optional
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    """
    Clase de configuración para la aplicación Nexus.
    Carga variables de entorno del archivo .env y las valida estrictamente.
    Incluye configuración avanzada para SQLAlchemy y Neo4j con logging de auditoría.
    """

    # ============ Configuración de PostgreSQL ============
    postgres_host: str = "localhost"
    postgres_port: int = 5432
    postgres_db: str = "nexus_db"
    postgres_user: str = "postgres"
    postgres_password: str
    
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

    # ============ Entorno y Logging ============
    environment: str = "development"
    log_level: str = "DEBUG"

    class Config:
        """Configuración de ajustes de Pydantic."""
        env_file = ".env"
        env_file_encoding = "utf-8"
        case_sensitive = False

    @property
    def postgres_url_sqlalchemy(self) -> str:
        """
        Construir cadena de conexión de PostgreSQL para SQLAlchemy.
        Formato: postgresql+psycopg2://user:password@host:port/db
        """
        return (
            f"postgresql+psycopg2://{self.postgres_user}:{self.postgres_password}@"
            f"{self.postgres_host}:{self.postgres_port}/{self.postgres_db}"
        )

    @property
    def neo4j_uri(self) -> str:
        """
        Construir URI de Neo4j para el driver.
        Formato: neo4j://host:port
        """
        return f"neo4j://{self.neo4j_host}:{self.neo4j_port}"

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