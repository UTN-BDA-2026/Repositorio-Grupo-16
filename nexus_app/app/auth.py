from datetime import datetime, timedelta
from typing import Optional
from jose import JWTError, jwt
from passlib.context import CryptContext
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from sqlalchemy.orm import Session
from redis.asyncio import Redis as AsyncRedis
from app.models.relational import UsuarioORM, PhotoORM, UsuarioConFotoResponse
from app.config import get_settings
from app.services.rate_limiter import RateLimiterLoginRedis
from app.dependencies import get_db, get_redis 
import logging

logger = logging.getLogger(__name__)
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


# ============ ENDPOINT DE LOGIN CON RATE LIMITER ============

@router.post("/login")
async def login(
    form_data: OAuth2PasswordRequestForm = Depends(),
    db: Session = Depends(get_db),
    redis: AsyncRedis = Depends(get_redis)
):
    
    email = form_data.username
    logger.info(f"Intento de login: {email}")
    
    rate_limiter = RateLimiterLoginRedis(redis)
    
    # PASO 1: Verificar si está bloqueado
    if await rate_limiter.está_bloqueado(email):
        tiempo_restante = await rate_limiter.obtener_tiempo_bloqueo_restante(email)
        minutos = tiempo_restante // 60
        segundos = tiempo_restante % 60
        
        logger.warning(f"login rechazado: {email} está bloqueado ({minutos}m {segundos}s)")
        
        raise HTTPException(
            status_code=429,
            detail=f"Cuenta bloqueada por intentos fallidos. Intente en {minutos}m {segundos}s."
        )
    
    # PASO 2: Validar credenciales
    usuario = db.query(UsuarioORM).filter(
        UsuarioORM.email == email
    ).first()
    
    if not usuario or not verificar_contrasena(form_data.password, usuario.contrasena_hash):
        intentos, bloqueado = await rate_limiter.registrar_intento_fallido(email)
        intentos_restantes = await rate_limiter.obtener_intentos_restantes(email)
        
        logger.warning(f"Credenciales incorrectas: {email} (intento {intentos}/{5})")
        
        if bloqueado:
            raise HTTPException(
                status_code=429,
                detail="Demasiados intentos fallidos. Cuenta bloqueada por 15 minutos."
            )
        else:
            raise HTTPException(
                status_code=401,
                detail=f"Email o contraseña incorrectos. Intentos restantes: {intentos_restantes}"
            )
    
    # PASO 3: Verificar si cuenta está activa
    if not usuario.activo:
        logger.warning(f"Cuenta inactiva: {email}")
        raise HTTPException(
            status_code=403,
            detail="Esta cuenta se encuentra temporalmente inactiva."
        )
    
    # PASO 4: Login exitoso → limpiar intentos fallidos
    await rate_limiter.registrar_intento_exitoso(email)
    logger.info(f"Login exitoso: {email}")
    
    # PASO 5: Obtener la primera foto del usuario (foto de perfil)
    from app.models.relational import PhotoORM
    primera_foto = db.query(PhotoORM).filter(
        PhotoORM.user_id == usuario.usuario_id
    ).order_by(PhotoORM.fecha_subida).first()
    
    foto_perfil_url = primera_foto.url_imagen if primera_foto else None
    
    # PASO 6: Generar token JWT
    expiracion_token = timedelta(minutes=MINUTOS_EXPIRACION_TOKEN)
    datos_token = {"sub": usuario.email, "usuario_id": usuario.usuario_id}
    access_token = crear_token_acceso(data=datos_token, expires_delta=expiracion_token)
    
    return {
        "access_token": access_token,
        "token_type": "bearer",
        "usuario": {
            "usuario_id": usuario.usuario_id,
            "email": usuario.email,
            "nombre_usuario": usuario.nombre_usuario,
            "bio": usuario.bio,
            "foto_perfil_url": foto_perfil_url,
            "rol": "usuario"
        }
    }

async def obtener_usuario_actual(
    token: str = Depends(esquema_oauth2),
    db: Session = Depends(get_db)
) -> UsuarioORM:
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
    
    user = db.query(UsuarioORM).filter(
        UsuarioORM.email == email,
        UsuarioORM.activo == True
    ).first()
    
    if user is None:
        raise credentials_exception
    
    return user


@router.get("/me", response_model=UsuarioConFotoResponse)
async def obtener_mi_usuario(
    actual: UsuarioORM = Depends(obtener_usuario_actual),
    db: Session = Depends(get_db)
):
    """Retorna los datos del usuario actual incluyendo su foto de perfil (primera foto subida)."""
    
    # Obtener la primera foto del usuario (ordenada por fecha_subida)
    primera_foto = db.query(PhotoORM).filter(
        PhotoORM.user_id == actual.usuario_id
    ).order_by(PhotoORM.fecha_subida).first()
    
    foto_perfil_url = primera_foto.url_imagen if primera_foto else None
    
    return {
        "usuario_id": actual.usuario_id,
        "email": actual.email,
        "nombre_usuario": actual.nombre_usuario,
        "bio": actual.bio,
        "fecha_creacion": actual.fecha_creacion,
        "activo": actual.activo,
        "foto_perfil_url": foto_perfil_url,
        "rol": "usuario",
    }