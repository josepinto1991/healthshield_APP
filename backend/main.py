from fastapi import FastAPI, HTTPException, Depends, Query, status, Header
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.orm import Session
from sqlalchemy import text
import os
from datetime import datetime
from dotenv import load_dotenv
from jose import jwt, JWTError
from typing import List, Optional, Dict, Any
import logging
import sys
from contextlib import asynccontextmanager

# ==================== CONFIGURACIÓN INICIAL ====================

# Mostrar información de inicio
print("\n" + "="*70)
print("🚀 HEALTHSHIELD API - VERCEL + NEON POSTGRESQL")
print("="*70)

# Configurar logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Determinar entorno
is_vercel = os.environ.get('VERCEL') is not None

if is_vercel:
    logger.info("✅ Ejecutando en Vercel (producción)")
    if os.path.exists('.env'):
        load_dotenv()
        logger.info("📁 .env cargado para desarrollo")
else:
    load_dotenv()
    logger.info("💻 Modo desarrollo local")

# Configuración JWT
SECRET_KEY = os.environ.get("SECRET_KEY")
if not SECRET_KEY:
    if is_vercel:
        logger.error("❌ SECRET_KEY no configurada en Vercel")
        SECRET_KEY = "temp_secret_key_change_in_production_32_chars"
        logger.warning("⚠️  Usando secreto temporal - CAMBIAR EN PRODUCCIÓN")
    else:
        SECRET_KEY = "dev_secret_key_32_chars_minimum_here"
        logger.info("🔑 Usando secreto de desarrollo")

ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60 * 24 * 7  # 7 días

# Security
security = HTTPBearer(auto_error=False)

def create_access_token(data: dict):
    """Crear token JWT"""
    to_encode = data.copy()
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt

def verify_token(token: str):
    """Verificar token JWT"""
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        return payload
    except JWTError:
        return None

# Importar módulos de la aplicación
try:
    from database import get_db, init_db, hash_password, verify_password
    from models import (
        UsuarioCreate, UsuarioResponse, UserLogin, AuthResponse,
        PacienteCreate, PacienteResponse, PacienteUpdate,
        VacunaCreate, VacunaResponse, VacunaUpdate,
        MessageResponse, HealthCheck, BulkSyncData, BulkSyncResponse,
        SyncResponse, Usuario, Paciente, Vacuna
    )
    from repositories import UsuarioRepository, PacienteRepository, VacunaRepository
    logger.info("✅ Módulos de la aplicación importados correctamente")
except ImportError as e:
    logger.error(f"❌ Error importando módulos: {e}")
    logger.error("💡 Verifica que todos los archivos estén presentes:")
    logger.error("   - database.py")
    logger.error("   - models.py") 
    logger.error("   - repositories.py")
    sys.exit(1)

# ==================== FUNCIONES AUXILIARES ====================

def create_default_admin(db: Session):
    """Crear usuario administrador por defecto si no existe"""
    try:
        existing_admin = UsuarioRepository.get_by_username(db, "admin")
        if existing_admin:
            logger.info("✅ Usuario admin ya existe")
            return existing_admin
        
        admin_password = os.environ.get('ADMIN_PASSWORD', 'Admin123!')
        
        admin_data = UsuarioCreate(
            username="admin",
            email="admin@healthshield.com",
            password=admin_password,
            telefono="0000000000",
            is_professional=True,
            professional_license="ADMIN-001"
        )
        
        db_admin = UsuarioRepository.create(db, admin_data)
        if db_admin:
            db_admin.is_verified = True
            db.commit()
            db.refresh(db_admin)
            logger.info(f"✅ Usuario admin creado: {db_admin.username}")
            return db_admin
        else:
            logger.error("❌ No se pudo crear usuario admin")
            return None
            
    except Exception as e:
        logger.error(f"❌ Error creando usuario admin: {e}")
        db.rollback()
        return None

def get_current_user(
    token: Optional[str] = Query(None),
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(security),
    db: Session = Depends(get_db)
):
    """
    Obtener usuario actual desde token JWT
    Acepta token como query param (?token=) o header (Authorization: Bearer)
    """
    jwt_token = None
    
    # 1. Intentar obtener de query parameter
    if token:
        jwt_token = token
    # 2. Intentar obtener de header
    elif credentials and credentials.credentials:
        jwt_token = credentials.credentials
    
    if not jwt_token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token no proporcionado",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    payload = verify_token(jwt_token)
    if not payload:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token inválido o expirado",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    username = payload.get("sub")
    if not username:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token inválido",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    user = UsuarioRepository.get_by_username(db, username)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Usuario no encontrado",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    return user

# ==================== LIFESPAN (STARTUP/SHUTDOWN) ====================

@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    Manejar eventos de inicio y apagado de la aplicación.
    Se ejecuta al iniciar y antes de cerrar.
    """
    # ========== STARTUP ==========
    logger.info("🔄 Iniciando HealthShield API...")
    
    # Inicializar base de datos
    logger.info("🛠️  Inicializando base de datos...")
    db_initialized = init_db()
    
    if db_initialized:
        logger.info("✅ Base de datos inicializada correctamente")
        
        # Crear usuario admin
        try:
            db = next(get_db())
            admin = create_default_admin(db)
            if admin:
                logger.info(f"✅ Usuario admin: {admin.username} ({admin.email})")
            else:
                logger.warning("⚠️  No se pudo crear usuario admin")
        except Exception as e:
            logger.warning(f"⚠️  Error al crear admin: {e}")
            logger.info("💡 El admin se creará en el primer inicio")
    else:
        logger.error("❌ Error inicializando base de datos")
        logger.info("💡 La API funcionará en modo limitado")
    
    logger.info("✅ HealthShield API lista para recibir peticiones")
    
    yield  # La aplicación corre aquí
    
    # ========== SHUTDOWN ==========
    logger.info("🛑 Deteniendo HealthShield API...")
    # Limpieza si es necesaria

# ==================== APLICACIÓN FASTAPI ====================

app = FastAPI(
    title="HealthShield API",
    version="2.0.0",
    description="""
    API para gestión de pacientes y registros de vacunación.
    
    🚀 Desplegado en Vercel con Neon PostgreSQL
    🔐 Autenticación JWT (Header o Query param)
    📱 Sincronización offline/online
    """,
    docs_url="/docs",
    redoc_url="/redoc",
    openapi_url="/openapi.json",
    lifespan=lifespan
)

# ==================== CONFIGURACIÓN CORS ====================

# Orígenes permitidos
allowed_origins = [
    "http://localhost:3000",
    "http://localhost:5173", 
    "http://localhost:8080",
    "http://127.0.0.1:3000",
    "http://127.0.0.1:5173",
    "http://127.0.0.1:8080",
    "http://localhost:5000", 
    "http://127.0.0.1:5000",
    "http://10.0.2.2:8000",
    "http://10.0.2.2:3000",
    "http://localhost:8000",
    "https://healthshield-app.vercel.app",
    "https://*.vercel.app",
    "https://*.github.io",
    "http://localhost",
]

# También permitir si se especifica en variables de entorno
if os.environ.get('ALLOWED_ORIGINS'):
    custom_origins = [origin.strip() for origin in os.environ.get('ALLOWED_ORIGINS').split(",")]
    allowed_origins.extend(custom_origins)

# Filtrar duplicados
allowed_origins = list(dict.fromkeys([origin for origin in allowed_origins if origin]))

logger.info(f"🌐 CORS configurado para {len(allowed_origins)} orígenes")

# Middleware CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=allowed_origins,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS", "PATCH"],
    allow_headers=["*"],
    expose_headers=["*"],
    max_age=600,
)

# ==================== ENDPOINTS DE DIAGNÓSTICO ====================

@app.get("/", response_model=HealthCheck, tags=["Diagnóstico"])
async def root():
    """
    Endpoint raíz - Información básica del API
    """
    return HealthCheck(
        status="healthy",
        timestamp=datetime.now().isoformat(),
        environment=os.environ.get('ENVIRONMENT', 'development'),
        database="Neon PostgreSQL" if os.environ.get('DATABASE_URL') else "No configurada",
        metrics={
            "service": "HealthShield API",
            "version": "2.0.0",
            "uptime": "running"
        }
    )

@app.get("/health", response_model=HealthCheck, tags=["Diagnóstico"])
async def health_check(db: Session = Depends(get_db)):
    """
    Health check completo - Verifica conectividad a DB
    """
    try:
        db.execute(text("SELECT 1"))
        db_status = "connected"
        
        pacientes_count = db.query(Paciente).count()
        vacunas_count = db.query(Vacuna).count()
        usuarios_count = db.query(Usuario).count()
        
        return HealthCheck(
            status="healthy",
            timestamp=datetime.now().isoformat(),
            environment=os.environ.get('ENVIRONMENT', 'development'),
            database=db_status,
            metrics={
                "pacientes_count": pacientes_count,
                "vacunas_count": vacunas_count,
                "usuarios_count": usuarios_count,
                "vercel_environment": os.environ.get('VERCEL_ENV', 'unknown'),
                "region": os.environ.get('VERCEL_REGION', 'unknown')
            }
        )
        
    except Exception as e:
        logger.error(f"❌ Health check falló: {e}")
        return HealthCheck(
            status="unhealthy",
            timestamp=datetime.now().isoformat(),
            environment=os.environ.get('ENVIRONMENT', 'development'),
            database=f"error: {str(e)[:100]}",
            metrics={
                "error": str(e)[:200]
            }
        )

# ==================== ENDPOINTS DE AUTENTICACIÓN ====================

@app.post("/api/auth/register", 
          response_model=AuthResponse, 
          status_code=status.HTTP_201_CREATED,
          tags=["Autenticación"])
async def register_user(
    usuario: UsuarioCreate,
    db: Session = Depends(get_db)
):
    """
    Registrar un nuevo usuario
    """
    if UsuarioRepository.get_by_username(db, usuario.username):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="El nombre de usuario ya está registrado"
        )
    
    if UsuarioRepository.get_by_email(db, usuario.email):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="El email ya está registrado"
        )
    
    try:
        db_usuario = UsuarioRepository.create(db, usuario)
        
        access_token = create_access_token({
            "sub": db_usuario.username,
            "user_id": db_usuario.id,
            "email": db_usuario.email,
            "is_professional": db_usuario.is_professional
        })
        
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
        logger.error(f"❌ Error en registro: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Error interno del servidor"
        )

@app.post("/api/auth/login", 
          response_model=AuthResponse,
          tags=["Autenticación"])
async def login_user(
    login_data: UserLogin,
    db: Session = Depends(get_db)
):
    """
    Iniciar sesión con usuario y contraseña
    """
    usuario = UsuarioRepository.authenticate(db, login_data.username, login_data.password)
    
    if not usuario:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Credenciales incorrectas",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    access_token = create_access_token({
        "sub": usuario.username,
        "user_id": usuario.id,
        "email": usuario.email,
        "is_professional": usuario.is_professional
    })
    
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

@app.get("/api/auth/me", 
         response_model=UsuarioResponse,
         tags=["Autenticación"])
async def get_current_user_info(
    token: Optional[str] = Query(None),
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(security),
    db: Session = Depends(get_db)
):
    """
    Obtener información del usuario actual
    """
    usuario = get_current_user(token=token, credentials=credentials, db=db)
    
    return UsuarioResponse(
        id=usuario.id,
        username=usuario.username,
        email=usuario.email,
        telefono=usuario.telefono,
        is_professional=usuario.is_professional,
        professional_license=usuario.professional_license,
        is_verified=usuario.is_verified,
        created_at=usuario.created_at,
        updated_at=usuario.updated_at
    )

# ==================== ENDPOINTS DE PACIENTES ====================

@app.post("/api/pacientes", 
          response_model=MessageResponse,
          status_code=status.HTTP_201_CREATED,
          tags=["Pacientes"])
async def create_paciente(
    paciente: PacienteCreate,
    db: Session = Depends(get_db),
    token: Optional[str] = Query(None),
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(security)
):
    """
    Crear un nuevo paciente
    """
    get_current_user(token=token, credentials=credentials, db=db)
    
    if PacienteRepository.get_by_cedula(db, paciente.cedula):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="La cédula ya está registrada"
        )
    
    try:
        db_paciente = PacienteRepository.create(db, paciente)
        
        return MessageResponse(
            message="Paciente creado exitosamente",
            id=db_paciente.id,
            local_id=paciente.local_id
        )
    except Exception as e:
        logger.error(f"❌ Error creando paciente: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Error interno del servidor"
        )

@app.get("/api/pacientes", 
         response_model=List[PacienteResponse],
         tags=["Pacientes"])
async def get_all_pacientes(
    skip: int = Query(0, ge=0, description="Número de registros a saltar"),
    limit: int = Query(100, ge=1, le=1000, description="Límite de registros"),
    search: Optional[str] = Query(None, description="Búsqueda por nombre o cédula"),
    token: Optional[str] = Query(None),
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(security),
    db: Session = Depends(get_db)
):
    """
    Obtener todos los pacientes con paginación y búsqueda
    """
    try:
        # Si se proporciona token, verificar usuario
        if token or credentials:
            get_current_user(token=token, credentials=credentials, db=db)
        
        from sqlalchemy import or_
        
        query = db.query(Paciente)
        
        if search:
            query = query.filter(
                or_(
                    Paciente.nombre.ilike(f"%{search}%"),
                    Paciente.cedula.ilike(f"%{search}%"),
                    Paciente.telefono.ilike(f"%{search}%")
                )
            )
        
        pacientes = query.offset(skip).limit(limit).all()
        
        return [
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
    except Exception as e:
        logger.error(f"❌ Error obteniendo pacientes: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Error interno del servidor"
        )

@app.get("/api/pacientes/{paciente_id}", 
         response_model=PacienteResponse,
         tags=["Pacientes"])
async def get_paciente(
    paciente_id: int,
    db: Session = Depends(get_db)
):
    """
    Obtener un paciente específico por ID
    """
    paciente = PacienteRepository.get_by_id(db, paciente_id)
    
    if not paciente:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Paciente no encontrado"
        )
    
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

@app.get("/api/pacientes/cedula/{cedula}", 
         response_model=PacienteResponse,
         tags=["Pacientes"])
async def get_paciente_by_cedula(
    cedula: str,
    db: Session = Depends(get_db)
):
    """
    Buscar paciente por número de cédula
    """
    try:
        paciente = PacienteRepository.get_by_cedula(db, cedula)
        
        if not paciente:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Paciente no encontrado"
            )
        
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
        logger.error(f"❌ Error buscando paciente por cédula: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Error interno del servidor"
        )

@app.get("/api/pacientes/buscar", 
         response_model=List[PacienteResponse],
         tags=["Pacientes"])
async def buscar_pacientes(
    q: str = Query(..., description="Término de búsqueda (nombre o cédula)"),
    db: Session = Depends(get_db)
):
    """
    Buscar pacientes por nombre o cédula
    """
    try:
        from sqlalchemy import or_
        
        query = db.query(Paciente).filter(
            or_(
                Paciente.nombre.ilike(f"%{q}%"),
                Paciente.cedula.ilike(f"%{q}%")
            )
        )
        
        pacientes = query.all()
        
        return [
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
        
    except Exception as e:
        logger.error(f"❌ Error buscando pacientes: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Error interno del servidor"
        )

# ==================== ENDPOINTS DE VACUNAS ====================

@app.post("/api/vacunas", 
          response_model=MessageResponse,
          status_code=status.HTTP_201_CREATED,
          tags=["Vacunas"])
async def create_vacuna(
    vacuna: VacunaCreate,
    db: Session = Depends(get_db),
    token: Optional[str] = Query(None),
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(security)
):
    """
    Registrar una nueva vacuna
    """
    current_user = get_current_user(token=token, credentials=credentials, db=db)
    
    try:
        # Asignar usuario actual si no se especifica
        if not vacuna.usuario_id:
            vacuna.usuario_id = current_user.id
        
        db_vacuna = VacunaRepository.create(db, vacuna)
        
        return MessageResponse(
            message="Vacuna registrada exitosamente",
            id=db_vacuna.id,
            local_id=vacuna.local_id
        )
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(e)
        )
    except Exception as e:
        logger.error(f"❌ Error registrando vacuna: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Error interno del servidor"
        )

@app.get("/api/pacientes/{paciente_id}/vacunas", 
         response_model=List[VacunaResponse],
         tags=["Vacunas"])
async def get_vacunas_paciente(
    paciente_id: int,
    db: Session = Depends(get_db)
):
    """
    Obtener todas las vacunas de un paciente
    """
    try:
        paciente = PacienteRepository.get_by_id(db, paciente_id)
        if not paciente:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Paciente no encontrado"
            )
        
        vacunas = VacunaRepository.get_by_paciente(db, paciente_id)
        
        return [
            VacunaResponse(
                id=vacuna.id,
                paciente_id=vacuna.paciente_id,
                nombre_vacuna=vacuna.nombre_vacuna,
                fecha_aplicacion=vacuna.fecha_aplicacion,
                lote=vacuna.lote,
                proxima_dosis=vacuna.proxima_dosis,
                usuario_id=vacuna.usuario_id,
                created_at=vacuna.created_at.isoformat() if vacuna.created_at else None,
                paciente_nombre=vacuna.paciente.nombre if vacuna.paciente else None,
                usuario_nombre=vacuna.usuario.username if vacuna.usuario else None
            ) for vacuna in vacunas
        ]
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"❌ Error obteniendo vacunas: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Error interno del servidor"
        )

@app.get("/api/vacunas", 
         response_model=List[VacunaResponse],
         tags=["Vacunas"])
async def get_all_vacunas(
    skip: int = Query(0, ge=0, description="Número de registros a saltar"),
    limit: int = Query(100, ge=1, le=1000, description="Límite de registros"),
    paciente_id: Optional[int] = Query(None, description="Filtrar por ID de paciente"),
    db: Session = Depends(get_db)
):
    """
    Obtener todas las vacunas con filtros
    """
    try:
        query = db.query(Vacuna)
        
        if paciente_id:
            query = query.filter(Vacuna.paciente_id == paciente_id)
        
        vacunas = query.offset(skip).limit(limit).all()
        
        return [
            VacunaResponse(
                id=vacuna.id,
                paciente_id=vacuna.paciente_id,
                nombre_vacuna=vacuna.nombre_vacuna,
                fecha_aplicacion=vacuna.fecha_aplicacion,
                lote=vacuna.lote,
                proxima_dosis=vacuna.proxima_dosis,
                usuario_id=vacuna.usuario_id,
                created_at=vacuna.created_at.isoformat() if vacuna.created_at else None,
                paciente_nombre=vacuna.paciente.nombre if vacuna.paciente else None,
                usuario_nombre=vacuna.usuario.username if vacuna.usuario else None
            ) for vacuna in vacunas
        ]
    except Exception as e:
        logger.error(f"❌ Error obteniendo vacunas: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Error interno del servidor"
        )

# ==================== ENDPOINTS DE USUARIOS ====================

@app.get("/api/users", 
         response_model=List[UsuarioResponse],
         tags=["Usuarios"])
async def get_all_users(
    db: Session = Depends(get_db),
    token: Optional[str] = Query(None),
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(security)
):
    """
    Obtener todos los usuarios (solo administradores)
    """
    current_user = get_current_user(token=token, credentials=credentials, db=db)
    if current_user.username != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Solo administradores pueden ver todos los usuarios"
        )
    
    try:
        usuarios = UsuarioRepository.get_all(db)
        return [
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
    except Exception as e:
        logger.error(f"❌ Error obteniendo usuarios: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Error interno del servidor"
        )

@app.post("/api/users/change-password", 
          response_model=MessageResponse,
          tags=["Usuarios"])
async def change_password(
    current_password: str = Query(..., description="Contraseña actual"),
    new_password: str = Query(..., description="Nueva contraseña"),
    user_id: int = Query(..., description="ID del usuario"),
    db: Session = Depends(get_db),
    token: Optional[str] = Query(None),
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(security)
):
    """
    Cambiar contraseña de usuario
    """
    current_user = get_current_user(token=token, credentials=credentials, db=db)
    
    if current_user.id != user_id and current_user.username != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="No tienes permisos para cambiar esta contraseña"
        )
    
    try:
        usuario = UsuarioRepository.get_by_id(db, user_id)
        if not usuario:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Usuario no encontrado"
            )
        
        if not verify_password(current_password, usuario.password):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Contraseña actual incorrecta"
            )
        
        hashed_new_password = hash_password(new_password)
        usuario.password = hashed_new_password
        db.commit()
        
        return MessageResponse(
            message="Contraseña cambiada exitosamente",
            id=usuario.id
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"❌ Error cambiando contraseña: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Error interno del servidor"
        )

# ==================== ENDPOINTS DE SINCRONIZACIÓN ====================

@app.post("/api/sync/bulk", response_model=BulkSyncResponse, tags=["Sincronización"])
async def bulk_sync(
    sync_data: BulkSyncData,
    db: Session = Depends(get_db),
    token: Optional[str] = Query(None),
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(security)
):
    """Sincronización masiva desde cliente Flutter"""
    current_user = get_current_user(token=token, credentials=credentials, db=db)
    
    pacientes_ids = {}
    vacunas_ids = {}
    conflicts = []
    
    try:
        # 1. Sincronizar pacientes
        for paciente in sync_data.pacientes:
            try:
                existing_paciente = None
                
                if paciente.server_id:
                    existing_paciente = PacienteRepository.get_by_server_id(db, paciente.server_id)
                
                if not existing_paciente:
                    existing_paciente = PacienteRepository.get_by_cedula(db, paciente.cedula)
                
                if not existing_paciente:
                    db_paciente = PacienteRepository.create(db, paciente)
                    pacientes_ids[str(paciente.local_id)] = {
                        'server_id': db_paciente.id,
                        'action': 'created'
                    }
                else:
                    update_data = {
                        'cedula': paciente.cedula,
                        'nombre': paciente.nombre,
                        'fecha_nacimiento': paciente.fecha_nacimiento,
                        'telefono': paciente.telefono,
                        'direccion': paciente.direccion,
                        'is_synced': True
                    }
                    PacienteRepository.update(db, existing_paciente.id, update_data)
                    pacientes_ids[str(paciente.local_id)] = {
                        'server_id': existing_paciente.id,
                        'action': 'updated'
                    }
                    
            except Exception as e:
                logger.error(f"❌ Error sincronizando paciente: {e}")
                conflicts.append({
                    'type': 'paciente',
                    'local_id': paciente.local_id,
                    'error': str(e)
                })
        
        # 2. Sincronizar vacunas
        for vacuna in sync_data.vacunas:
            try:
                paciente_info = pacientes_ids.get(str(vacuna.paciente_id), {})
                paciente_server_id = paciente_info.get('server_id', vacuna.paciente_id)
                
                if not vacuna.usuario_id:
                    vacuna.usuario_id = current_user.id
                
                existing_vacuna = None
                if vacuna.server_id:
                    existing_vacuna = VacunaRepository.get_by_server_id(db, vacuna.server_id)
                
                vacuna_data_dict = {
                    'paciente_id': paciente_server_id,
                    'paciente_server_id': vacuna.paciente_server_id,
                    'nombre_vacuna': vacuna.nombre_vacuna,
                    'fecha_aplicacion': vacuna.fecha_aplicacion,
                    'lote': vacuna.lote,
                    'proxima_dosis': vacuna.proxima_dosis,
                    'usuario_id': vacuna.usuario_id,
                    'es_menor': getattr(vacuna, 'es_menor', False),
                    'cedula_tutor': getattr(vacuna, 'cedula_tutor', None),
                    'cedula_propia': getattr(vacuna, 'cedula_propia', None),
                    'nombre_paciente': getattr(vacuna, 'nombre_paciente', None),
                    'cedula_paciente': getattr(vacuna, 'cedula_paciente', None),
                    'server_id': vacuna.server_id,
                }
                
                if existing_vacuna:
                    VacunaRepository.update(db, existing_vacuna.id, vacuna_data_dict)
                    vacunas_ids[str(vacuna.local_id)] = {
                        'server_id': existing_vacuna.id,
                        'action': 'updated'
                    }
                else:
                    from models import VacunaCreate
                    vacuna_data = VacunaCreate(**vacuna_data_dict)
                    db_vacuna = VacunaRepository.create(db, vacuna_data)
                    vacunas_ids[str(vacuna.local_id)] = {
                        'server_id': db_vacuna.id,
                        'action': 'created'
                    }
                    
            except Exception as e:
                logger.error(f"❌ Error sincronizando vacuna: {e}")
                conflicts.append({
                    'type': 'vacuna',
                    'local_id': vacuna.local_id,
                    'error': str(e)
                })
        
        return BulkSyncResponse(
            message="Sincronización completada",
            pacientes_sincronizados=len(sync_data.pacientes),
            vacunas_sincronizadas=len(sync_data.vacunas),
            pacientes_ids=pacientes_ids,
            vacunas_ids=vacunas_ids,
            conflicts=conflicts if conflicts else None,
            server_timestamp=datetime.now().isoformat()
        )
        
    except Exception as e:
        db.rollback()
        logger.error(f"❌ Error en sincronización masiva: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error en sincronización: {str(e)}"
        )

@app.get("/api/sync/updates", 
         response_model=SyncResponse,
         tags=["Sincronización"])
async def get_updates(
    last_sync: str = Query("1970-01-01T00:00:00Z", description="Fecha de última sincronización"),
    limit: int = Query(100, ge=1, le=500, description="Límite de registros"),
    db: Session = Depends(get_db)
):
    """
    Obtener actualizaciones desde la última sincronización
    """
    try:
        from datetime import datetime
        last_sync_dt = datetime.fromisoformat(last_sync.replace('Z', '+00:00'))
        
        updates = []
        
        pacientes = db.query(Paciente).filter(
            Paciente.created_at > last_sync_dt
        ).limit(limit).all()
        
        for paciente in pacientes:
            updates.append({
                'type': 'paciente',
                'id': paciente.id,
                'cedula': paciente.cedula,
                'nombre': paciente.nombre,
                'fecha_nacimiento': paciente.fecha_nacimiento,
                'telefono': paciente.telefono,
                'direccion': paciente.direccion,
                'created_at': paciente.created_at.isoformat() if paciente.created_at else None,
                'action': 'created'
            })
        
        vacunas = db.query(Vacuna).filter(
            Vacuna.created_at > last_sync_dt
        ).limit(limit).all()
        
        for vacuna in vacunas:
            updates.append({
                'type': 'vacuna',
                'id': vacuna.id,
                'paciente_id': vacuna.paciente_id,
                'nombre_vacuna': vacuna.nombre_vacuna,
                'fecha_aplicacion': vacuna.fecha_aplicacion,
                'lote': vacuna.lote,
                'proxima_dosis': vacuna.proxima_dosis,
                'usuario_id': vacuna.usuario_id,
                'created_at': vacuna.created_at.isoformat() if vacuna.created_at else None,
                'action': 'created'
            })
        
        return SyncResponse(
            message="Actualizaciones obtenidas",
            updates_count=len(updates),
            last_sync=datetime.now().isoformat(),
            updates=updates
        )
        
    except Exception as e:
        logger.error(f"❌ Error obteniendo actualizaciones: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Error obteniendo actualizaciones"
        )

# ==================== ENDPOINTS DE UTILIDAD ====================

@app.get("/api/test/compatibility", tags=["Diagnóstico"])
async def test_compatibility():
    """
    Verificar compatibilidad con app Flutter
    """
    return {
        "status": "compatible",
        "message": "✅ API compatible con app Flutter",
        "token_support": {
            "header": "Authorization: Bearer <token>",
            "query_param": "?token=<token>",
            "both_supported": True
        },
        "timestamp": datetime.now().isoformat()
    }

@app.get("/api/debug/token", tags=["Diagnóstico"])
async def debug_token(
    token: Optional[str] = Query(None),
    authorization: Optional[str] = Header(None)
):
    """
    Debug: Verificar cómo llega el token
    """
    token_from_header = None
    if authorization and authorization.startswith("Bearer "):
        token_from_header = authorization[7:]
    
    return {
        "token_from_query": token,
        "token_from_header": token_from_header,
        "authorization_header": authorization,
        "token_valid": verify_token(token) if token else (verify_token(token_from_header) if token_from_header else False),
        "preferred_method": "Usa header Authorization: Bearer <token>",
        "note": "Ambos métodos son soportados, pero header es más seguro"
    }

# ==================== MANEJO DE ERRORES ====================

from fastapi.responses import JSONResponse

@app.exception_handler(HTTPException)
async def http_exception_handler(request, exc):
    logger.error(f"HTTP {exc.status_code}: {exc.detail}")
    return JSONResponse(
        status_code=exc.status_code,
        content={
            "error": exc.detail,
            "status_code": exc.status_code,
            "timestamp": datetime.now().isoformat()
        }
    )

@app.exception_handler(Exception)
async def general_exception_handler(request, exc):
    logger.error(f"❌ Error no controlado: {exc}", exc_info=True)
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={
            "error": "Error interno del servidor",
            "detail": str(exc) if os.environ.get('ENVIRONMENT') == 'development' else None,
            "status_code": status.HTTP_500_INTERNAL_SERVER_ERROR,
            "timestamp": datetime.now().isoformat()
        }
    )

# ==================== EJECUCIÓN ====================

if __name__ == "__main__":
    import uvicorn
    
    port = int(os.environ.get("PORT", 8000))
    
    print(f"\n🔧 Iniciando servidor en puerto {port}...")
    print(f"🌐 URL: http://localhost:{port}")
    print(f"📚 Docs: http://localhost:{port}/docs")
    print(f"🔍 Token debug: http://localhost:{port}/api/debug/token")
    print("\n🟢 Servidor listo. Presiona Ctrl+C para detener.")
    
    uvicorn.run(
        app,
        host="0.0.0.0",
        port=port,
        log_level="info",
        reload=os.environ.get('ENVIRONMENT') == 'development'
    )