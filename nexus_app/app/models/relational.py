from datetime import datetime
from sqlalchemy import Column, Integer, String, DateTime, Boolean, Text, Index, CheckConstraint
from sqlalchemy.ext.declarative import declarative_base
from pydantic import BaseModel, EmailStr
from typing import Optional, List

# Base para todos los modelos SQLAlchemy
Base = declarative_base()


class UsuarioORM(Base):
    """
    Modelo ORM de SQLAlchemy para la tabla 'usuarios' en PostgreSQL.
    Mapea directamente a la tabla relacional con validaciones en BD.
    
    Requisito académico: Demuestra uso de índices (B-Tree en email),
    constraints, y timestamps de auditoría.
    """
    __tablename__ = "usuarios"

    # Columnas primarias
    usuario_id = Column(Integer, primary_key=True, autoincrement=True)
    email = Column(String(255), unique=True, nullable=False, index=True)
    nombre_usuario = Column(String(100), nullable=False)
    contrasena_hash = Column(String(255), nullable=False)
    
    # Datos de perfil
    fecha_nacimiento = Column(DateTime, nullable=True)
    sexo = Column(String(20), nullable=True)
    bio = Column(Text, nullable=True)
    
    # Estado y auditoría
    activo = Column(Boolean, default=True, nullable=False)
    fecha_creacion = Column(DateTime, default=datetime.utcnow, nullable=False)
    fecha_actualizacion = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)
    
    # Índices compuestos para optimización
    __table_args__ = (
        Index('idx_usuarios_email_activo', 'email', 'activo'),  # Para búsquedas por email activo
        Index('idx_usuarios_fecha_creacion', 'fecha_creacion'),  # Para auditoría y paginación
        CheckConstraint("email LIKE '%@%'", name='ck_email_valido'),  # Validación básica
    )

    def __repr__(self):
        return f"<UsuarioORM(usuario_id={self.usuario_id}, email='{self.email}', nombre_usuario='{self.nombre_usuario}')>"


# ============ Modelos Pydantic para API (Validación de entrada/salida) ============

class RegistroUsuarioRequest(BaseModel):
    """
    Esquema de solicitud para POST /usuarios/registro.
    Valida los datos de entrada antes de la transacción híbrida.
    """
    email: EmailStr  # Valida que sea un email válido
    nombre_usuario: str
    contrasena: str
    fecha_nacimiento: Optional[datetime] = None
    sexo: Optional[str] = None
    bio: Optional[str] = None
    etiquetas_interes: List[int] = []  # IDs de etiquetas de interés (Neo4j)

    class Config:
        json_schema_extra = {
            "example": {
                "email": "juan@example.com",
                "nombre_usuario": "juan_tech",
                "contrasena": "secura_pass_123",
                "fecha_nacimiento": "1995-05-15T00:00:00",
                "sexo": "Masculino",
                "bio": "Amante de la tecnología y música",
                "etiquetas_interes": [1, 3, 5]
            }
        }


class RegistroUsuarioResponse(BaseModel):
    """
    Esquema de respuesta para POST /usuarios/registro.
    Retorna los datos del usuario creado (sin contraseña).
    """
    usuario_id: int
    email: str
    nombre_usuario: str
    bio: Optional[str]
    fecha_creacion: datetime
    nodo_neo4j_creado: bool
    etiquetas_vinculadas: int

    class Config:
        from_attributes = True


class UsuarioResponse(BaseModel):
    """Esquema de respuesta general de usuario (sin datos sensibles)."""
    usuario_id: int
    email: str
    nombre_usuario: str
    bio: Optional[str]
    fecha_creacion: datetime
    activo: bool

    class Config:
        from_attributes = True