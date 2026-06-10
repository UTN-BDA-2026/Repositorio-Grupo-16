from datetime import datetime, timedelta
from typing import Optional
from jose import JWTError, jwt
from passlib.context import CryptContext
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from sqlalchemy.orm import Session


from app.models.relational import UsuarioORM
from app.config import get_settings

from app.main import get_db

settings = get_settings()

#  Configuración Criptográfica de Seguridad para JWT
# ---------------------------------------------------------------------------
CLAVE_SECRETA = settings.clave_secreta_jwt
ALGORITHM = "HS256"
MINUTOS_EXPIRACION_TOKEN = 1440  # 24 horas

contexto_crypt = CryptContext(schemes=["bcrypt"], deprecated="auto")
esquema_oauth2 = OAuth2PasswordBearer(tokenUrl="login")

router = APIRouter(tags=["Autenticación Segura"])


# Funciones Auxiliares de Verificación y Cifrado
# ---------------------------------------------------------------------------
def verificar_contrasena(plain_password: str, hashed_password: str) -> bool:
    """Compara la contraseña en texto plano con el hash de la BD."""
    return contexto_crypt.verify(plain_password, hashed_password)

def crear_token_acceso(data: dict, expires_delta: Optional[timedelta] = None) -> str:
    """Genera el token JWT (La pulsera VIP)."""
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=15)
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, CLAVE_SECRETA, algorithm=ALGORITHM)


#  Dependencia de Validación 
# ---------------------------------------------------------------------------
async def obtener_usuario_actual(token: str = Depends(esquema_oauth2), db: Session = Depends(get_db)) -> UsuarioORM:
    """Intercepta la petición, valida el JWT y devuelve el usuario."""
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="No se pudieron validar las credenciales de acceso.",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, CLAVE_SECRETA, algorithms=[ALGORITHM])
        email: str = payload.get("sub")
        if email is None:
            raise credentials_exception
    except JWTError:
        raise credentials_exception
        
    user = db.query(UsuarioORM).filter(UsuarioORM.email == email, UsuarioORM.activo == True).first()
    if user is None:
        raise credentials_exception
    return user


# Endpoint de Login 
# ---------------------------------------------------------------------------
@router.post("/login")
async def login(
    form_data: OAuth2PasswordRequestForm = Depends(), 
    db: Session = Depends(get_db)
):
    """Recibe email y password, y emite el Token JWT si son correctos."""
    user = db.query(UsuarioORM).filter(UsuarioORM.email == form_data.username).first()
    
    if not user or not verificar_contrasena(form_data.password, user.contrasena_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="El email o la contraseña son incorrectos.",
            headers={"WWW-Authenticate": "Bearer"},
        )
        
    if not user.activo:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Esta cuenta se encuentra temporalmente inactiva."
        )

    expiracion_token = timedelta(minutes=MINUTOS_EXPIRACION_TOKEN)
    datos_token = {"sub": user.email, "usuario_id": user.usuario_id}
    
    access_token = crear_token_acceso(data=datos_token, expires_delta=expiracion_token)
    
    return {
        "access_token": access_token, 
        "token_type": "bearer",
        "usuario": {
            "id": user.usuario_id,
            "nombre": user.nombre_usuario,
            "email": user.email
        }
    }

@router.get("/me")
async def leer_usuario_actual(usuario: UsuarioORM = Depends(obtener_usuario_actual)):
    """Devuelve los datos del usuario actual si el token es válido."""
    return {
        "usuario_id": usuario.usuario_id,
        "nombre_usuario": usuario.nombre_usuario,
        "email": usuario.email,
        "activo": usuario.activo,
        "fecha_creacion": usuario.fecha_creacion,
    }