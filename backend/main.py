from fastapi import FastAPI, HTTPException, Depends, Query, status, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.gzip import GZipMiddleware
from fastapi.responses import JSONResponse
from sqlalchemy.orm import Session
import os
from datetime import datetime, timezone, timedelta
from dotenv import load_dotenv
from jose import jwt, JWTError
from typing import List, Optional
import logging
from contextlib import asynccontextmanager
import time
import uuid

from database import get_db, init_db, hash_password
from models import (
    UsuarioCreate, UsuarioResponse, UserLogin, AuthResponse,
    PacienteCreate, PacienteResponse, PacienteUpdate,
    VacunaCreate, VacunaResponse, VacunaUpdate,
    MessageResponse, SyncResponse, BulkSyncData, BulkSyncResponse,
    HealthCheck, Usuario, Paciente, Vacuna
)
from repositories import UsuarioRepository, PacienteRepository, VacunaRepository

# ==================== CONFIGURACIÓN ====================

# Configurar logging para producción
logging.basicConfig(
    level=logging.INFO if os.environ.get('ENVIRONMENT') == 'production' else logging.DEBUG,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)
logger = logging.getLogger(__name__)

load_dotenv()

# Configuración de JWT (optimizada para móvil)
SECRET_KEY = os.environ.get("SECRET_KEY", "healthshield_secret_key_for_development")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_DAYS = 30  # Token de larga duración para apps móviles
REFRESH_TOKEN_EXPIRE_DAYS = 90  # Refresh token aún más largo

def create_access_token(data: dict, expires_delta: Optional[timedelta] = None):
    """Crear token JWT con expiración"""
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.now(timezone.utc) + expires_delta
    else:
        expire = datetime.now(timezone.utc) + timedelta(days=ACCESS_TOKEN_EXPIRE_DAYS)
    
    to_encode.update({
        "exp": expire,
        "iat": datetime.now(timezone.utc),
        "jti": str(uuid.uuid4())  # ID único para el token
    })
    
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt

def create_refresh_token(data: dict):
    """Crear refresh token (más largo)"""
    to_encode = data.copy()
    expire = datetime.now(timezone.utc) + timedelta(days=REFRESH_TOKEN_EXPIRE_DAYS)
    to_encode.update({
        "exp": expire,
        "iat": datetime.now(timezone.utc),
        "type": "refresh",
        "jti": str(uuid.uuid4())
    })
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)

def verify_token(token: str):
    """Verificar token JWT"""
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        return payload
    except JWTError as e:
        logger.error(f"Error verificando token: {e}")
        return None

async def get_current_user(
    request: Request,
    db: Session = Depends(get_db),
    authorization: Optional[str] = None
):
    """Middleware para obtener usuario actual desde token"""
    # Obtener token del header Authorization
    auth_header = request.headers.get("Authorization")
    if not auth_header or not auth_header.startswith("Bearer "):
        return None
    
    token = auth_header.split(" ")[1]
    
    payload = verify_token(token)
    if not payload:
        return None
    
    # Verificar si es un token de acceso (no refresh)
    if payload.get("type") == "refresh":
        return None
    
    username = payload.get("sub")
    user_id = payload.get("user_id")
    
    if not username or not user_id:
        return None
    
    # Obtener usuario desde la base de datos
    user = UsuarioRepository.get_by_id(db, user_id)
    if not user or user.username != username:
        return None
    
    return user

# ==================== LIFESPAN ====================

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Gestión del ciclo de vida de la aplicación"""
    # Startup
    startup_time = datetime.now(timezone.utc)
    logger.info("🚀 Iniciando HealthShield API para Render...")
    
    try:
        # 1. Inicializar base de datos (creará DB y tablas si no existen)
        logger.info("🗄️  Inicializando base de datos...")
        init_db()
        logger.info("✅ Base de datos inicializada")
        
        # 2. Crear usuario admin por defecto
        logger.info("👤 Creando usuario admin por defecto...")
        db = next(get_db())
        create_default_admin(db)
        
        logger.info("✅ HealthShield API iniciada correctamente")
        
    except Exception as e:
        logger.error(f"❌ Error durante el inicio: {e}")
        # No re-lanzar, dejar que la app inicie igual
        # (en Render, el health check fallará si hay error grave)
    
    yield
    
    # Shutdown
    logger.info("🛑 Deteniendo HealthShield API...")

def create_default_admin(db: Session):
    """Crear usuario admin por defecto si no existe"""
    try:
        existing_admin = UsuarioRepository.get_by_username(db, "admin")
        if existing_admin:
            logger.info("✅ Usuario admin ya existe")
            return
        
        admin_data = UsuarioCreate(
            username="admin",
            email="admin@healthshield.com",
            password="admin123",
            telefono="0000000000",
            is_professional=True,
            professional_license="ADMIN-001"
        )
        
        db_admin = UsuarioRepository.create(db, admin_data)
        db_admin.is_verified = True
        db.commit()
        
        logger.info("✅ Usuario admin creado exitosamente")
        logger.info("👤 Credenciales por defecto:")
        logger.info("   Usuario: admin")
        logger.info("   Contraseña: admin123")
        
    except Exception as e:
        logger.error(f"⚠️ Error creando usuario admin: {e}")
        db.rollback()

# ==================== APLICACIÓN FASTAPI ====================

app = FastAPI(
    title="HealthShield API",
    version="1.0.0",
    description="API REST para aplicación móvil de gestión de vacunas",
    docs_url="/docs",
    redoc_url="/redoc",
    lifespan=lifespan
)

# ==================== MIDDLEWARES ====================

# Configuración CORS optimizada para apps móviles
allowed_origins = os.environ.get("ALLOWED_ORIGINS", "").split(",")
if not allowed_origins or allowed_origins == [""]:
    allowed_origins = ["*"]  # Permitir todos para desarrollo móvil

logger.info(f"🌐 Orígenes CORS permitidos: {allowed_origins}")

app.add_middleware(
    CORSMiddleware,
    allow_origins=allowed_origins,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS", "PATCH"],
    allow_headers=[
        "Authorization",
        "Content-Type",
        "Accept",
        "Origin",
        "X-Requested-With",
        "X-Device-ID",
        "X-App-Version"
    ],
    expose_headers=["X-Total-Count", "X-Page", "X-Per-Page"],
    max_age=86400  # Cache preflight requests for 24 hours
)

# Middleware de compresión GZIP para ahorrar datos móviles
app.add_middleware(
    GZipMiddleware, 
    minimum_size=1000,  # Comprimir respuestas mayores a 1KB
    compresslevel=6
)

# Middleware de logging para todas las peticiones
@app.middleware("http")
async def log_requests(request: Request, call_next):
    """Middleware para loggear todas las peticiones"""
    request_id = str(uuid.uuid4())
    start_time = time.time()
    
    # Headers útiles para debugging móvil
    device_id = request.headers.get("X-Device-ID", "unknown")
    app_version = request.headers.get("X-App-Version", "unknown")
    
    logger.info(
        f"[{request_id}] 📱 Device: {device_id} | App: {app_version} | "
        f"📥 {request.method} {request.url.path}"
    )
    
    try:
        response = await call_next(request)
        
        process_time = (time.time() - start_time) * 1000
        formatted_time = f"{process_time:.2f}ms"
        
        # Loggear respuesta
        logger.info(
            f"[{request_id}] ✅ {response.status_code} | "
            f"Time: {formatted_time} | "
            f"Size: {response.headers.get('content-length', '?')} bytes"
        )
        
        # Añadir headers útiles para el cliente móvil
        response.headers["X-Request-ID"] = request_id
        response.headers["X-Response-Time"] = formatted_time
        
        return response
        
    except Exception as e:
        process_time = (time.time() - start_time) * 1000
        logger.error(
            f"[{request_id}] ❌ Error: {str(e)} | "
            f"Time: {process_time:.2f}ms"
        )
        raise

# ==================== MANEJO DE EXCEPCIONES ====================

@app.exception_handler(HTTPException)
async def http_exception_handler(request: Request, exc: HTTPException):
    """Manejar excepciones HTTP para respuesta móvil amigable"""
    logger.error(
        f"HTTP {exc.status_code}: {exc.detail} | "
        f"Path: {request.url.path} | "
        f"Device: {request.headers.get('X-Device-ID', 'unknown')}"
    )
    
    return JSONResponse(
        status_code=exc.status_code,
        content={
            "success": False,
            "message": exc.detail,
            "error_code": exc.status_code,
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "path": request.url.path
        },
        headers={
            "X-Error-Type": "HTTP",
            "X-Error-Code": str(exc.status_code)
        }
    )

@app.exception_handler(Exception)
async def general_exception_handler(request: Request, exc: Exception):
    """Manejar excepciones generales"""
    logger.error(
        f"❌ Error no manejado: {exc} | "
        f"Path: {request.url.path} | "
        f"Device: {request.headers.get('X-Device-ID', 'unknown')}"
    )
    
    return JSONResponse(
        status_code=500,
        content={
            "success": False,
            "message": "Error interno del servidor",
            "error_code": 500,
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "path": request.url.path
        },
        headers={
            "X-Error-Type": "Internal",
            "X-Error-Code": "500"
        }
    )

# ==================== ENDPOINTS DE AUTENTICACIÓN ====================

@app.post("/api/auth/register", response_model=AuthResponse, status_code=201)
async def register(usuario: UsuarioCreate, db: Session = Depends(get_db)):
    """Registrar un nuevo usuario desde la app móvil"""
    logger.info(f"📝 Registro de usuario: {usuario.username}")
    
    # Validar si el usuario ya existe
    if UsuarioRepository.get_by_username(db, usuario.username):
        logger.warning(f"Usuario {usuario.username} ya existe")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="El nombre de usuario ya está registrado"
        )
    
    # Validar si el email ya existe
    if UsuarioRepository.get_by_email(db, usuario.email):
        logger.warning(f"Email {usuario.email} ya registrado")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="El email ya está registrado"
        )
    
    try:
        # Crear usuario
        db_usuario = UsuarioRepository.create(db, usuario)
        
        # Crear tokens
        access_token = create_access_token({
            "sub": usuario.username, 
            "user_id": db_usuario.id,
            "email": usuario.email,
            "is_professional": usuario.is_professional
        })
        
        refresh_token = create_refresh_token({
            "sub": usuario.username,
            "user_id": db_usuario.id
        })
        
        logger.info(f"✅ Usuario {usuario.username} registrado exitosamente (ID: {db_usuario.id})")
        
        return AuthResponse(
            message="Usuario registrado exitosamente",
            user=UsuarioResponse(
                id=db_usuario.id,
                username=db_usuario.username,
                email=db_usuario.email,
                telefono=db_usuario.telefono,
                is_professional=db_usuario.is_professional,
                professional_license=db_usuario.professional_license,
                is_verified=db_usuario.is_verified,
                created_at=db_usuario.created_at,
                updated_at=db_usuario.updated_at
            ),
            token=access_token
        )
        
    except Exception as e:
        logger.error(f"❌ Error registrando usuario: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error del servidor: {str(e)}"
        )

@app.post("/api/auth/login", response_model=AuthResponse)
async def login(login_data: UserLogin, db: Session = Depends(get_db)):
    """Iniciar sesión desde la app móvil"""
    logger.info(f"🔐 Intento de login: {login_data.username}")
    
    usuario = UsuarioRepository.authenticate(db, login_data.username, login_data.password)
    if not usuario:
        logger.warning(f"Login fallido para: {login_data.username}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Credenciales incorrectas",
            headers={"WWW-Authenticate": "Bearer"}
        )
    
    # Crear tokens
    access_token = create_access_token({
        "sub": usuario.username, 
        "user_id": usuario.id,
        "email": usuario.email,
        "is_professional": usuario.is_professional
    })
    
    refresh_token = create_refresh_token({
        "sub": usuario.username,
        "user_id": usuario.id
    })
    
    logger.info(f"✅ Login exitoso: {usuario.username} (ID: {usuario.id})")
    
    return AuthResponse(
        message="Login exitoso",
        user=UsuarioResponse(
            id=usuario.id,
            username=usuario.username,
            email=usuario.email,
            telefono=usuario.telefono,
            is_professional=usuario.is_professional,
            professional_license=usuario.professional_license,
            is_verified=usuario.is_verified,
            created_at=usuario.created_at,
            updated_at=usuario.updated_at
        ),
        token=access_token
    )

@app.post("/api/auth/refresh")
async def refresh_token(
    refresh_token: str = Query(..., description="Refresh token"),
    db: Session = Depends(get_db)
):
    """Renovar access token usando refresh token"""
    logger.info("🔄 Solicitando renovación de token")
    
    payload = verify_token(refresh_token)
    if not payload or payload.get("type") != "refresh":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Refresh token inválido"
        )
    
    username = payload.get("sub")
    user_id = payload.get("user_id")
    
    if not username or not user_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token inválido"
        )
    
    # Verificar que el usuario aún existe
    user = UsuarioRepository.get_by_id(db, user_id)
    if not user or user.username != username:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Usuario no encontrado"
        )
    
    # Crear nuevo access token
    new_access_token = create_access_token({
        "sub": user.username,
        "user_id": user.id,
        "email": user.email,
        "is_professional": user.is_professional
    })
    
    logger.info(f"✅ Token renovado para: {username}")
    
    return {
        "success": True,
        "message": "Token renovado exitosamente",
        "access_token": new_access_token,
        "token_type": "bearer"
    }

@app.get("/api/auth/me", response_model=UsuarioResponse)
async def get_current_user_endpoint(current_user: Usuario = Depends(get_current_user)):
    """Obtener información del usuario actual"""
    if not current_user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="No autenticado"
        )
    
    logger.info(f"📋 Obteniendo información de usuario: {current_user.username}")
    
    return UsuarioResponse(
        id=current_user.id,
        username=current_user.username,
        email=current_user.email,
        telefono=current_user.telefono,
        is_professional=current_user.is_professional,
        professional_license=current_user.professional_license,
        is_verified=current_user.is_verified,
        created_at=current_user.created_at,
        updated_at=current_user.updated_at
    )

# ==================== ENDPOINTS DE USUARIOS ====================

@app.get("/api/users", response_model=List[UsuarioResponse])
async def get_usuarios(
    skip: int = Query(0, ge=0, description="Número de registros a saltar"),
    limit: int = Query(100, ge=1, le=1000, description="Límite de registros"),
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    """Obtener usuarios con paginación"""
    if not current_user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="No autorizado"
        )
    
    try:
        usuarios = UsuarioRepository.get_all(db, skip=skip, limit=limit)
        total = db.query(Usuario).count()
        
        logger.info(f"📊 Obteniendo {len(usuarios)} usuarios (skip={skip}, limit={limit}, total={total})")
        
        # Crear respuesta con headers de paginación
        response = JSONResponse(
            content=[
                UsuarioResponse(
                    id=usuario.id,
                    username=usuario.username,
                    email=usuario.email,
                    telefono=usuario.telefono,
                    is_professional=usuario.is_professional,
                    professional_license=usuario.professional_license,
                    is_verified=usuario.is_verified,
                    created_at=usuario.created_at,
                    updated_at=usuario.updated_at
                ) for usuario in usuarios
            ]
        )
        
        # Headers útiles para paginación en móvil
        response.headers["X-Total-Count"] = str(total)
        response.headers["X-Page"] = str(skip // limit + 1 if limit > 0 else 1)
        response.headers["X-Per-Page"] = str(limit)
        response.headers["X-Total-Pages"] = str((total + limit - 1) // limit if limit > 0 else 1)
        
        return response
        
    except Exception as e:
        logger.error(f"❌ Error obteniendo usuarios: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error del servidor: {str(e)}"
        )

@app.post("/api/users/change-password", response_model=MessageResponse)
async def change_password(
    current_password: str = Query(..., description="Contraseña actual"),
    new_password: str = Query(..., description="Nueva contraseña"),
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    """Cambiar contraseña del usuario actual"""
    if not current_user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="No autorizado"
        )
    
    logger.info(f"🔑 Cambio de contraseña para usuario: {current_user.username}")
    
    try:
        from database import verify_password, hash_password
        
        # Verificar contraseña actual
        if not verify_password(current_password, current_user.password):
            logger.warning(f"Contraseña incorrecta para usuario: {current_user.username}")
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Contraseña actual incorrecta"
            )
        
        # Validar nueva contraseña
        if len(new_password) < 6:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="La nueva contraseña debe tener al menos 6 caracteres"
            )
        
        # Actualizar contraseña
        current_user.password = hash_password(new_password)
        db.commit()
        
        logger.info(f"✅ Contraseña actualizada para usuario: {current_user.username}")
        
        return MessageResponse(
            message="Contraseña actualizada exitosamente",
            id=current_user.id
        )
        
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        logger.error(f"❌ Error cambiando contraseña: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error del servidor: {str(e)}"
        )

# ==================== ENDPOINTS DE PACIENTES ====================

@app.post("/api/pacientes", response_model=MessageResponse, status_code=201)
async def add_paciente(
    paciente: PacienteCreate,
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    """Agregar un nuevo paciente"""
    if not current_user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="No autorizado"
        )
    
    logger.info(f"👤 Agregando paciente: {paciente.nombre} - Cédula: {paciente.cedula}")
    
    # Validar formato de cédula (puedes personalizar según tu país)
    if not paciente.cedula or len(paciente.cedula) < 3:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="La cédula es inválida"
        )
    
    # Verificar si la cédula ya existe
    if PacienteRepository.get_by_cedula(db, paciente.cedula):
        logger.warning(f"Cédula {paciente.cedula} ya registrada")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="La cédula ya está registrada"
        )
    
    try:
        db_paciente = PacienteRepository.create(db, paciente)
        
        logger.info(f"✅ Paciente {paciente.nombre} agregado con ID: {db_paciente.id}")
        
        return MessageResponse(
            message='Paciente agregado correctamente',
            id=db_paciente.id,
            local_id=paciente.local_id
        )
        
    except Exception as e:
        logger.error(f"❌ Error agregando paciente: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error del servidor: {str(e)}"
        )

@app.get("/api/pacientes", response_model=List[PacienteResponse])
async def get_pacientes(
    search: Optional[str] = Query(None, description="Buscar por nombre o cédula"),
    skip: int = Query(0, ge=0, description="Número de registros a saltar"),
    limit: int = Query(100, ge=1, le=1000, description="Límite de registros"),
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    """Obtener pacientes con búsqueda y paginación"""
    if not current_user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="No autorizado"
        )
    
    try:
        # Obtener todos los pacientes o filtrar por búsqueda
        if search:
            pacientes = db.query(Paciente).filter(
                (Paciente.nombre.ilike(f"%{search}%")) | 
                (Paciente.cedula.ilike(f"%{search}%"))
            ).offset(skip).limit(limit).all()
            total = db.query(Paciente).filter(
                (Paciente.nombre.ilike(f"%{search}%")) | 
                (Paciente.cedula.ilike(f"%{search}%"))
            ).count()
        else:
            pacientes = PacienteRepository.get_all(db, skip=skip, limit=limit)
            total = db.query(Paciente).count()
        
        logger.info(f"📊 Obteniendo {len(pacientes)} pacientes (search='{search}', skip={skip}, limit={limit}, total={total})")
        
        # Crear respuesta
        response_content = [
            PacienteResponse(
                id=paciente.id,
                cedula=paciente.cedula,
                nombre=paciente.nombre,
                fecha_nacimiento=paciente.fecha_nacimiento,
                telefono=paciente.telefono,
                direccion=paciente.direccion,
                created_at=paciente.created_at.isoformat() if paciente.created_at else None,
                updated_at=paciente.updated_at.isoformat() if paciente.updated_at else None
            ) for paciente in pacientes
        ]
        
        response = JSONResponse(content=response_content)
        
        # Headers de paginación
        response.headers["X-Total-Count"] = str(total)
        response.headers["X-Page"] = str(skip // limit + 1 if limit > 0 else 1)
        response.headers["X-Per-Page"] = str(limit)
        
        return response
        
    except Exception as e:
        logger.error(f"❌ Error obteniendo pacientes: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error del servidor: {str(e)}"
        )

@app.get("/api/pacientes/{paciente_id}", response_model=PacienteResponse)
async def get_paciente(
    paciente_id: int,
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    """Obtener un paciente específico"""
    if not current_user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="No autorizado"
        )
    
    try:
        paciente = PacienteRepository.get_by_id(db, paciente_id)
        if not paciente:
            logger.warning(f"Paciente ID {paciente_id} no encontrado")
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Paciente no encontrado"
            )
        
        logger.info(f"✅ Obteniendo paciente ID {paciente_id}: {paciente.nombre}")
        
        return PacienteResponse(
            id=paciente.id,
            cedula=paciente.cedula,
            nombre=paciente.nombre,
            fecha_nacimiento=paciente.fecha_nacimiento,
            telefono=paciente.telefono,
            direccion=paciente.direccion,
            created_at=paciente.created_at.isoformat() if paciente.created_at else None,
            updated_at=paciente.updated_at.isoformat() if paciente.updated_at else None
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"❌ Error obteniendo paciente: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error del servidor: {str(e)}"
        )

# ==================== ENDPOINTS DE VACUNAS ====================

@app.post("/api/vacunas", response_model=MessageResponse, status_code=201)
async def add_vacuna(
    vacuna: VacunaCreate,
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    """Registrar una nueva vacuna"""
    if not current_user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="No autorizado"
        )
    
    logger.info(f"💉 Agregando vacuna: {vacuna.nombre_vacuna} para paciente ID: {vacuna.paciente_id}")
    
    # Validar que el paciente existe
    paciente = PacienteRepository.get_by_id(db, vacuna.paciente_id)
    if not paciente:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Paciente no encontrado"
        )
    
    try:
        # Si no se especifica usuario_id, usar el usuario actual
        if not vacuna.usuario_id:
            vacuna.usuario_id = current_user.id
        
        db_vacuna = VacunaRepository.create(db, vacuna)
        
        logger.info(f"✅ Vacuna {vacuna.nombre_vacuna} registrada con ID: {db_vacuna.id} para paciente: {paciente.nombre}")
        
        return MessageResponse(
            message='Vacuna registrada correctamente',
            id=db_vacuna.id,
            local_id=vacuna.local_id
        )
        
    except ValueError as e:
        logger.error(f"❌ Error de validación: {e}")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )
    except Exception as e:
        logger.error(f"❌ Error registrando vacuna: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error del servidor: {str(e)}"
        )

@app.get("/api/pacientes/{paciente_id}/vacunas", response_model=List[VacunaResponse])
async def get_vacunas_paciente(
    paciente_id: int,
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=1000),
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    """Obtener todas las vacunas de un paciente con paginación"""
    if not current_user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="No autorizado"
        )
    
    try:
        # Verificar que el paciente existe
        paciente = PacienteRepository.get_by_id(db, paciente_id)
        if not paciente:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Paciente no encontrado"
            )
        
        # Obtener vacunas del paciente
        vacunas = db.query(Vacuna).filter(
            Vacuna.paciente_id == paciente_id
        ).offset(skip).limit(limit).all()
        
        total = db.query(Vacuna).filter(
            Vacuna.paciente_id == paciente_id
        ).count()
        
        logger.info(f"📊 Obteniendo {len(vacunas)} vacunas para paciente ID: {paciente_id} (total: {total})")
        
        # Crear respuesta
        response_content = [
            VacunaResponse(
                id=vacuna.id,
                paciente_id=vacuna.paciente_id,
                nombre_vacuna=vacuna.nombre_vacuna,
                fecha_aplicacion=vacuna.fecha_aplicacion,
                lote=vacuna.lote,
                proxima_dosis=vacuna.proxima_dosis,
                usuario_id=vacuna.usuario_id,
                created_at=vacuna.created_at.isoformat() if vacuna.created_at else None,
                paciente_nombre=paciente.nombre,
                usuario_nombre=vacuna.usuario.username if vacuna.usuario else None
            ) for vacuna in vacunas
        ]
        
        response = JSONResponse(content=response_content)
        response.headers["X-Total-Count"] = str(total)
        response.headers["X-Page"] = str(skip // limit + 1 if limit > 0 else 1)
        response.headers["X-Per-Page"] = str(limit)
        
        return response
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"❌ Error obteniendo vacunas: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error del servidor: {str(e)}"
        )

@app.get("/api/vacunas", response_model=List[VacunaResponse])
async def get_all_vacunas(
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=1000),
    paciente_id: Optional[int] = Query(None, description="Filtrar por paciente"),
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    """Obtener todas las vacunas con filtros y paginación"""
    if not current_user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="No autorizado"
        )
    
    try:
        # Construir query base
        query = db.query(Vacuna)
        
        # Aplicar filtros
        if paciente_id:
            query = query.filter(Vacuna.paciente_id == paciente_id)
        
        # Obtener total
        total = query.count()
        
        # Aplicar paginación
        vacunas = query.offset(skip).limit(limit).all()
        
        logger.info(f"📊 Obteniendo {len(vacunas)} vacunas (filters: paciente_id={paciente_id}, skip={skip}, limit={limit}, total={total})")
        
        # Crear respuesta
        response_content = []
        for vacuna in vacunas:
            # Obtener nombres relacionados
            paciente_nombre = None
            usuario_nombre = None
            
            if vacuna.paciente:
                paciente_nombre = vacuna.paciente.nombre
            if vacuna.usuario:
                usuario_nombre = vacuna.usuario.username
            
            response_content.append(
                VacunaResponse(
                    id=vacuna.id,
                    paciente_id=vacuna.paciente_id,
                    nombre_vacuna=vacuna.nombre_vacuna,
                    fecha_aplicacion=vacuna.fecha_aplicacion,
                    lote=vacuna.lote,
                    proxima_dosis=vacuna.proxima_dosis,
                    usuario_id=vacuna.usuario_id,
                    created_at=vacuna.created_at.isoformat() if vacuna.created_at else None,
                    paciente_nombre=paciente_nombre,
                    usuario_nombre=usuario_nombre
                )
            )
        
        response = JSONResponse(content=response_content)
        response.headers["X-Total-Count"] = str(total)
        response.headers["X-Page"] = str(skip // limit + 1 if limit > 0 else 1)
        response.headers["X-Per-Page"] = str(limit)
        
        return response
        
    except Exception as e:
        logger.error(f"❌ Error obteniendo todas las vacunas: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error del servidor: {str(e)}"
        )

# ==================== ENDPOINTS DE SINCRONIZACIÓN ====================

@app.post("/api/sync/bulk", response_model=BulkSyncResponse)
async def bulk_sync(
    sync_data: BulkSyncData,
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    """Sincronización masiva para app móvil offline/online"""
    if not current_user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="No autorizado"
        )
    
    logger.info(f"🔄 Sincronización masiva iniciada por {current_user.username}")
    logger.info(f"📦 Datos a sincronizar: {len(sync_data.pacientes)} pacientes, {len(sync_data.vacunas)} vacunas")
    
    pacientes_ids = {}
    vacunas_ids = {}
    pacientes_sincronizados = 0
    vacunas_sincronizadas = 0
    errores = []
    
    try:
        # Sincronizar pacientes
        for paciente in sync_data.pacientes:
            try:
                existing_paciente = PacienteRepository.get_by_cedula(db, paciente.cedula)
                if not existing_paciente:
                    db_paciente = PacienteRepository.create(db, paciente)
                    if db_paciente:
                        pacientes_ids[paciente.local_id] = db_paciente.id
                        pacientes_sincronizados += 1
                        logger.debug(f"✅ Paciente sincronizado: {paciente.nombre}")
                else:
                    pacientes_ids[paciente.local_id] = existing_paciente.id
                    logger.debug(f"ℹ️  Paciente ya existía: {paciente.nombre}")
                    
            except Exception as e:
                error_msg = f"Paciente {paciente.local_id}: {str(e)}"
                errores.append(error_msg)
                logger.error(f"❌ Error sincronizando paciente {paciente.local_id}: {e}")
        
        # Sincronizar vacunas
        for vacuna in sync_data.vacunas:
            try:
                # Mapear ID local a ID del servidor
                paciente_server_id = pacientes_ids.get(vacuna.paciente_id, vacuna.paciente_id)
                
                # Crear objeto de vacuna para sincronizar
                vacuna_data = VacunaCreate(
                    paciente_id=paciente_server_id,
                    nombre_vacuna=vacuna.nombre_vacuna,
                    fecha_aplicacion=vacuna.fecha_aplicacion,
                    lote=vacuna.lote,
                    proxima_dosis=vacuna.proxima_dosis,
                    usuario_id=vacuna.usuario_id or current_user.id,
                    local_id=vacuna.local_id
                )
                
                db_vacuna = VacunaRepository.create(db, vacuna_data)
                if db_vacuna:
                    vacunas_ids[vacuna.local_id] = db_vacuna.id
                    vacunas_sincronizadas += 1
                    logger.debug(f"✅ Vacuna sincronizada: {vacuna.nombre_vacuna}")
                    
            except Exception as e:
                error_msg = f"Vacuna {vacuna.local_id}: {str(e)}"
                errores.append(error_msg)
                logger.error(f"❌ Error sincronizando vacuna {vacuna.local_id}: {e}")
        
        logger.info(f"✅ Sincronización completada: {pacientes_sincronizados} pacientes, {vacunas_sincronizadas} vacunas")
        
        return BulkSyncResponse(
            message="Sincronización masiva completada",
            pacientes_sincronizados=pacientes_sincronizados,
            vacunas_sincronizadas=vacunas_sincronizadas,
            pacientes_ids=pacientes_ids,
            vacunas_ids=vacunas_ids
        )
        
    except Exception as e:
        db.rollback()
        logger.error(f"❌ Error en sincronización masiva: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f'Error en sincronización masiva: {str(e)}'
        )

@app.get("/api/sync/updates", response_model=SyncResponse)
async def get_updates(
    last_sync: str = Query("1970-01-01T00:00:00Z", description="Fecha de última sincronización en formato ISO"),
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    """Obtener actualizaciones desde la última sincronización"""
    if not current_user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="No autorizado"
        )
    
    logger.info(f"📡 Obteniendo actualizaciones desde: {last_sync} para usuario: {current_user.username}")
    
    try:
        updates = []
        
        # Obtener pacientes creados o actualizados después de last_sync
        pacientes = db.query(Paciente).filter(
            (Paciente.created_at > last_sync) | 
            (Paciente.updated_at > last_sync)
        ).all()
        
        for paciente in pacientes:
            paciente_data = {
                'tipo': 'paciente',
                'id': paciente.id,
                'cedula': paciente.cedula,
                'nombre': paciente.nombre,
                'fecha_nacimiento': paciente.fecha_nacimiento,
                'telefono': paciente.telefono,
                'direccion': paciente.direccion,
                'created_at': paciente.created_at.isoformat() if paciente.created_at else None,
                'updated_at': paciente.updated_at.isoformat() if paciente.updated_at else None,
                'action': 'created' if paciente.created_at and paciente.created_at > last_sync else 'updated'
            }
            updates.append(paciente_data)
        
        # Obtener vacunas creadas o actualizadas después de last_sync
        vacunas = db.query(Vacuna).filter(
            (Vacuna.created_at > last_sync) | 
            (Vacuna.updated_at > last_sync)
        ).all()
        
        for vacuna in vacunas:
            vacuna_data = {
                'tipo': 'vacuna',
                'id': vacuna.id,
                'paciente_id': vacuna.paciente_id,
                'nombre_vacuna': vacuna.nombre_vacuna,
                'fecha_aplicacion': vacuna.fecha_aplicacion,
                'lote': vacuna.lote,
                'proxima_dosis': vacuna.proxima_dosis,
                'usuario_id': vacuna.usuario_id,
                'created_at': vacuna.created_at.isoformat() if vacuna.created_at else None,
                'updated_at': vacuna.updated_at.isoformat() if vacuna.updated_at else None,
                'action': 'created' if vacuna.created_at and vacuna.created_at > last_sync else 'updated'
            }
            updates.append(vacuna_data)
        
        logger.info(f"📊 {len(updates)} actualizaciones encontradas")
        
        return SyncResponse(
            message="Actualizaciones obtenidas correctamente",
            updates_count=len(updates),
            last_sync=datetime.now(timezone.utc).isoformat(),
            updates=updates
        )
        
    except Exception as e:
        logger.error(f"❌ Error obteniendo actualizaciones: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f'Error del servidor: {str(e)}'
        )

# ==================== ENDPOINTS DE UTILIDAD ====================

@app.get("/", response_model=HealthCheck)
async def root():
    """Endpoint raíz - Información básica del API"""
    return HealthCheck(
        status="healthy",
        timestamp=datetime.now(timezone.utc).isoformat(),
        environment=os.environ.get('ENVIRONMENT', 'development'),
        database="PostgreSQL (Render)",
        metrics={
            "service": "HealthShield API",
            "version": "1.0.0",
            "cliente": "Flutter Mobile App",
            "endpoints_available": [
                "/api/auth/*",
                "/api/pacientes/*",
                "/api/vacunas/*",
                "/api/sync/*",
                "/health",
                "/docs"
            ]
        }
    )

@app.get("/health", response_model=HealthCheck)
async def health_check(db: Session = Depends(get_db)):
    """Health check completo para Render y monitoreo"""
    check_start = time.time()
    
    try:
        # Verificar conexión a la base de datos
        db_start = time.time()
        db.execute('SELECT 1')
        db_latency = (time.time() - db_start) * 1000
        
        # Contar registros
        pacientes_count = db.query(Paciente).count()
        vacunas_count = db.query(Vacuna).count()
        usuarios_count = db.query(Usuario).count()
        
        db_status = f"connected ({db_latency:.2f}ms)"
        overall_status = "healthy"
        
    except Exception as e:
        db_status = f"error: {str(e)}"
        pacientes_count = 0
        vacunas_count = 0
        usuarios_count = 0
        overall_status = "degraded"
        logger.error(f"❌ Health check falló: {e}")
    
    total_time = (time.time() - check_start) * 1000
    
    return HealthCheck(
        status=overall_status,
        timestamp=datetime.now(timezone.utc).isoformat(),
        environment=os.environ.get('ENVIRONMENT', 'development'),
        database=db_status,
        metrics={
            "pacientes_count": pacientes_count,
            "vacunas_count": vacunas_count,
            "usuarios_count": usuarios_count,
            "response_time_ms": f"{total_time:.2f}",
            "service": "healthshield-api",
            "platform": "Render"
        }
    )

@app.get("/info")
async def get_info():
    """Obtener información de la API para el cliente Flutter"""
    return {
        "service": "HealthShield API",
        "version": "1.0.0",
        "environment": os.environ.get('ENVIRONMENT', 'development'),
        "deployment": "Render",
        "client": "Flutter Mobile App",
        "authentication": "JWT Bearer Token",
        "base_url": "/api",
        "endpoints": {
            "auth": {
                "register": "POST /api/auth/register",
                "login": "POST /api/auth/login",
                "refresh": "POST /api/auth/refresh",
                "me": "GET /api/auth/me"
            },
            "pacientes": {
                "create": "POST /api/pacientes",
                "list": "GET /api/pacientes",
                "get": "GET /api/pacientes/{id}"
            },
            "vacunas": {
                "create": "POST /api/vacunas",
                "list": "GET /api/vacunas",
                "by_patient": "GET /api/pacientes/{id}/vacunas"
            },
            "sync": {
                "bulk": "POST /api/sync/bulk",
                "updates": "GET /api/sync/updates"
            }
        },
        "docs": "/docs",
        "health": "/health"
    }

# ==================== MAIN ====================

if __name__ == "__main__":
    import uvicorn
    
    port = int(os.environ.get("PORT", 5001))
    
    uvicorn.run(
        app,
        host="0.0.0.0",
        port=port,
        log_level="info",
        access_log=True,
        timeout_keep_alive=30,
        proxy_headers=True  # Importante para Render
    )