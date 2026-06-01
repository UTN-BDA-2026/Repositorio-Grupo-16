from datetime import datetime
from pydantic import BaseModel


class UserCreate(BaseModel):
    nombre: str
    email: str
    contrasena: str
    bio: str | None = None


class UserResponse(BaseModel):
    user_id: int
    nombre: str
    email: str
    bio: str | None = None
    fecha_registro: datetime


class User(UserResponse):
    activo: bool
