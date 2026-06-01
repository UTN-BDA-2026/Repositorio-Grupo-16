import os
from typing import Optional
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    """
    Clase de configuración para la aplicación Nexus.
    Carga variables de entorno del archivo .env y las valida estrictamente.
    """

    # Configuración de PostgreSQL
    postgres_host: str = "localhost"
    postgres_port: int = 5432
    postgres_db: str = "nexus_db"
    postgres_user: str = "postgres"
    postgres_password: str

    # Configuración de Neo4j
    neo4j_host: str = "localhost"
    neo4j_port: int = 7687
    neo4j_user: str = "neo4j"
    neo4j_password: str

    # Configuración de FastAPI
    fastapi_host: str = "0.0.0.0"
    fastapi_port: int = 8000
    fastapi_debug: bool = False

    # Entorno
    environment: str = "development"
    log_level: str = "INFO"

    class Config:
        """Configuración de ajustes de Pydantic."""
        env_file = ".env"
        env_file_encoding = "utf-8"
        case_sensitive = False

    @property
    def postgres_url(self) -> str:
        """Construir cadena de conexión de PostgreSQL."""
        return (
            f"postgresql://{self.postgres_user}:{self.postgres_password}@"
            f"{self.postgres_host}:{self.postgres_port}/{self.postgres_db}"
        )

    @property
    def neo4j_url(self) -> str:
        """Construir cadena de conexión de Neo4j."""
        return (
            f"neo4j://{self.neo4j_user}:{self.neo4j_password}@"
            f"{self.neo4j_host}:{self.neo4j_port}"
        )


def get_settings() -> Settings:
    """Obtener configuración de la aplicación."""
    return Settings()
