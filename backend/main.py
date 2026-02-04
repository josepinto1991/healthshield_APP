from fastapi import FastAPI, HTTPException, Depends, Query, status
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session
from sqlalchemy import text
import os
from datetime import datetime
from dotenv import load_dotenv
from jose import jwt, JWTError
from typing import List, Optional
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
    # En Vercel, las variables vienen del entorno
    # Solo cargar .env si existe y estamos en desarrollo
    if os.path.exists('.env'):
        load_dotenv()
        logger.info("📁 .env cargado para desarrollo")
else:
    # Desarrollo local
    load_dotenv()
    logger.info("💻 Modo desarrollo local")

# Configuración JWT
SECRET_KEY = os.environ.get("SECRET_KEY")
if not SECRET_KEY:
    if is_vercel:
        logger.error("❌ SECRET_KEY no configurada en Vercel")
        # Valor temporal para desarrollo (CAMBIAR EN PRODUCCIÓN)
        SECRET_KEY = "temp_secret_key_change_in_production_32_chars"
        logger.warning("⚠️  Usando secreto temporal - CAMBIAR EN PRODUCCIÓN")
    else:
        SECRET_KEY = "dev_secret_key_32_chars_minimum_here"
        logger.info("🔑 Usando secreto de desarrollo")

ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60 * 24 * 7  # 7 días

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
        # Verificar si ya existe un admin
        existing_admin = UsuarioRepository.get_by_username(db, "admin")
        if existing_admin:
            logger.info("✅ Usuario admin ya existe")
            return existing_admin
        
        # Crear admin
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

def get_current_user(token: Optional[str] = None, db: Session = Depends(get_db)):
    """Obtener usuario actual desde token JWT"""
    if not token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token no proporcionado",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    payload = verify_token(token)
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

# ==================== CONFIGURACIÓN CORS ====================

# Determinar orígenes permitidos
if os.environ.get('ALLOWED_ORIGINS'):
    allowed_origins = [origin.strip() for origin in os.environ.get('ALLOWED_ORIGINS').split(",")]
else:
    # Valores por defecto
    allowed_origins = [
        "http://localhost:3000",
        "http://localhost:5173",
        "http://localhost:8080",
        "https://*.vercel.app",
    ]
    
    # Agregar URL de Vercel si está disponible
    vercel_url = os.environ.get('VERCEL_URL')
    if vercel_url:
        allowed_origins.append(f"https://{vercel_url}")
    
    # Filtrar vacíos
    allowed_origins = [origin for origin in allowed_origins if origin]

logger.info(f"🌐 CORS configurado para {len(allowed_origins)} orígenes")

# ==================== APLICACIÓN FASTAPI ====================

app = FastAPI(
    title="HealthShield API",
    version="2.0.0",
    description="""
    API para gestión de pacientes y registros de vacunación.
    
    🚀 Desplegado en Vercel con Neon PostgreSQL
    🔐 Autenticación JWT
    📱 Sincronización offline/online
    🏥 Gestión de profesionales de salud
    
    ## Características
    
    - **Autenticación segura** con JWT
    - **CRUD completo** de pacientes y vacunas
    - **Sincronización** para uso offline
    - **API RESTful** con documentación automática
    - **CORS configurado** para frontend
    """,
    docs_url="/docs",
    redoc_url="/redoc",
    openapi_url="/openapi.json",
    lifespan=lifespan
)

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
    
    Returns:
        HealthCheck: Estado del servicio y metadata
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
    
    Returns:
        HealthCheck: Estado detallado del servicio
    """
    try:
        # Verificar conexión a base de datos
        db.execute(text("SELECT 1"))
        db_status = "connected"
        
        # Obtener estadísticas
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

@app.get("/api/neon/status", tags=["Diagnóstico"])
async def neon_status(db: Session = Depends(get_db)):
    """
    Estado detallado de la conexión a Neon PostgreSQL
    
    Returns:
        dict: Información detallada de la base de datos
    """
    try:
        result = db.execute(text("""
            SELECT 
                current_database() as database,
                current_user as username,
                version() as version,
                pg_database_size(current_database()) as size_bytes,
                now() as server_time,
                inet_server_addr() as host,
                inet_server_port() as port
        """))
        info = result.fetchone()
        
        # Calcular tamaño
        size_mb = info.size_bytes / (1024 * 1024) if info.size_bytes else 0
        size_gb = size_mb / 1024
        
        return {
            "status": "connected",
            "provider": "Neon",
            "timestamp": datetime.now().isoformat(),
            "database": {
                "name": info.database,
                "username": info.username,
                "host": f"{info.host}:{info.port}",
                "version": info.version.split(',')[0],
                "size_mb": round(size_mb, 2),
                "size_gb": round(size_gb, 3),
                "server_time": info.server_time.isoformat()
            },
            "limits": {
                "free_tier": "10 GB",
                "used_percentage": round((size_gb / 10) * 100, 2) if size_gb > 0 else 0
            }
        }
        
    except Exception as e:
        return {
            "status": "error",
            "provider": "Neon",
            "error": str(e),
            "timestamp": datetime.now().isoformat()
        }

@app.get("/api/debug/env", tags=["Diagnóstico"])
async def debug_environment():
    """
    Debug: Mostrar variables de entorno (sin valores sensibles)
    
    Returns:
        dict: Variables de entorno disponibles
    """
    env_vars = {}
    for key in sorted(os.environ.keys()):
        value = os.environ[key]
        
        # Ocultar valores sensibles
        if any(sensitive in key.lower() for sensitive in ['pass', 'secret', 'key', 'token']):
            env_vars[key] = "***HIDDEN***"
        elif 'DATABASE_URL' in key or 'NEON' in key:
            # Mostrar URL de forma segura
            if '@' in value:
                parts = value.split('@')
                user_part = parts[0]
                if '://' in user_part:
                    protocol = user_part.split('://')[0]
                    credentials = user_part.split('://')[1]
                    if ':' in credentials:
                        user = credentials.split(':')[0]
                        env_vars[key] = f"{protocol}://{user}:***@{parts[1].split('?')[0][:40]}..."
                    else:
                        env_vars[key] = f"{protocol}://***@{parts[1].split('?')[0][:40]}..."
                else:
                    env_vars[key] = value[:50] + "..."
            else:
                env_vars[key] = value[:50] + "..."
        else:
            env_vars[key] = value
    
    return {
        "timestamp": datetime.now().isoformat(),
        "environment_variables": env_vars,
        "python": {
            "version": sys.version,
            "platform": sys.platform,
            "executable": sys.executable
        },
        "vercel": {
            "environment": os.environ.get('VERCEL_ENV'),
            "url": os.environ.get('VERCEL_URL'),
            "region": os.environ.get('VERCEL_REGION'),
            "deployment": os.environ.get('VERCEL_GIT_COMMIT_SHA', 'local')[:7]
        }
    }

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
    
    Args:
        usuario (UsuarioCreate): Datos del nuevo usuario
    
    Returns:
        AuthResponse: Usuario creado y token JWT
    
    Raises:
        HTTPException: Si el usuario o email ya existen
    """
    # Verificar si usuario ya existe
    if UsuarioRepository.get_by_username(db, usuario.username):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="El nombre de usuario ya está registrado"
        )
    
    # Verificar si email ya existe
    if UsuarioRepository.get_by_email(db, usuario.email):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="El email ya está registrado"
        )
    
    try:
        # Crear usuario
        db_usuario = UsuarioRepository.create(db, usuario)
        
        # Crear token JWT
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
    
    Args:
        login_data (UserLogin): Credenciales de acceso
    
    Returns:
        AuthResponse: Usuario y token JWT
    
    Raises:
        HTTPException: Si las credenciales son incorrectas
    """
    # Autenticar usuario
    usuario = UsuarioRepository.authenticate(db, login_data.username, login_data.password)
    
    if not usuario:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Credenciales incorrectas",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    # Crear token JWT
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
    token: str = Query(..., description="Token JWT"),
    db: Session = Depends(get_db)
):
    """
    Obtener información del usuario actual
    
    Args:
        token (str): Token JWT en query parameter
    
    Returns:
        UsuarioResponse: Información del usuario
    """
    usuario = get_current_user(token, db)
    
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

# ==================== ENDPOINTS DE USUARIOS ====================

@app.get("/api/users", 
         response_model=List[UsuarioResponse],
         tags=["Usuarios"])
async def get_all_users(
    db: Session = Depends(get_db),
    token: str = Query(..., description="Token JWT de administrador")
):
    """
    Obtener todos los usuarios (solo administradores)
    
    Args:
        token (str): Token JWT
    
    Returns:
        List[UsuarioResponse]: Lista de usuarios
    """
    # Verificar que el usuario sea admin
    current_user = get_current_user(token, db)
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

# ==================== ENDPOINTS DE PACIENTES ====================

@app.post("/api/pacientes", 
          response_model=MessageResponse,
          status_code=status.HTTP_201_CREATED,
          tags=["Pacientes"])
async def create_paciente(
    paciente: PacienteCreate,
    db: Session = Depends(get_db),
    token: str = Query(..., description="Token JWT")
):
    """
    Crear un nuevo paciente
    
    Args:
        paciente (PacienteCreate): Datos del paciente
        token (str): Token JWT
    
    Returns:
        MessageResponse: Confirmación y ID del paciente
    """
    # Verificar autenticación
    get_current_user(token, db)
    
    # Verificar si la cédula ya existe
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
    db: Session = Depends(get_db),
    token: Optional[str] = Query(None, description="Token JWT (opcional para este endpoint)")
):
    """
    Obtener todos los pacientes con paginación y búsqueda
    
    Args:
        skip (int): Registros a saltar
        limit (int): Límite de registros
        search (str, optional): Término de búsqueda
        token (str, optional): Token JWT
    
    Returns:
        List[PacienteResponse]: Lista de pacientes
    """
    try:
        # Si se proporciona token, verificar usuario
        if token:
            get_current_user(token, db)
        
        # Obtener pacientes con filtro de búsqueda si existe
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
    
    Args:
        paciente_id (int): ID del paciente
    
    Returns:
        PacienteResponse: Datos del paciente
    
    Raises:
        HTTPException: Si el paciente no existe
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

# ==================== ENDPOINTS DE VACUNAS ====================

@app.post("/api/vacunas", 
          response_model=MessageResponse,
          status_code=status.HTTP_201_CREATED,
          tags=["Vacunas"])
async def create_vacuna(
    vacuna: VacunaCreate,
    db: Session = Depends(get_db),
    token: str = Query(..., description="Token JWT")
):
    """
    Registrar una nueva vacuna
    
    Args:
        vacuna (VacunaCreate): Datos de la vacuna
        token (str): Token JWT
    
    Returns:
        MessageResponse: Confirmación y ID de la vacuna
    """
    # Verificar autenticación
    current_user = get_current_user(token, db)
    
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
        # Error específico del repositorio (paciente no encontrado)
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
    
    Args:
        paciente_id (int): ID del paciente
    
    Returns:
        List[VacunaResponse]: Lista de vacunas del paciente
    """
    try:
        # Verificar que el paciente existe
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
    
    Args:
        skip (int): Registros a saltar
        limit (int): Límite de registros
        paciente_id (int, optional): Filtrar por paciente
    
    Returns:
        List[VacunaResponse]: Lista de vacunas
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

# ==================== ENDPOINTS DE SINCRONIZACIÓN ====================

@app.post("/api/sync/bulk", response_model=BulkSyncResponse, tags=["Sincronización"])
async def bulk_sync(
    sync_data: BulkSyncData,
    db: Session = Depends(get_db),
    token: str = Query(..., description="Token JWT")
):
    """Sincronización masiva desde cliente Flutter"""
    # Verificar autenticación
    current_user = get_current_user(token, db)
    
    pacientes_ids = {}
    vacunas_ids = {}
    conflicts = []
    
    try:
        # 1. Sincronizar pacientes
        for paciente in sync_data.pacientes:
            try:
                # Buscar paciente por cédula o server_id
                existing_paciente = None
                
                # Primero por server_id si existe
                if paciente.server_id:
                    existing_paciente = PacienteRepository.get_by_server_id(db, paciente.server_id)
                
                # Si no, buscar por cédula
                if not existing_paciente:
                    existing_paciente = PacienteRepository.get_by_cedula(db, paciente.cedula)
                
                if not existing_paciente:
                    # Nuevo paciente
                    db_paciente = PacienteRepository.create(db, paciente)
                    pacientes_ids[str(paciente.local_id)] = {
                        'server_id': db_paciente.id,
                        'action': 'created'
                    }
                else:
                    # Paciente ya existe, actualizar
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
                # Obtener ID real del paciente
                paciente_info = pacientes_ids.get(str(vacuna.paciente_id), {})
                paciente_server_id = paciente_info.get('server_id', vacuna.paciente_id)
                
                # Asignar usuario actual si no tiene
                if not vacuna.usuario_id:
                    vacuna.usuario_id = current_user.id
                
                # Buscar vacuna existente por server_id
                existing_vacuna = None
                if vacuna.server_id:
                    existing_vacuna = VacunaRepository.get_by_server_id(db, vacuna.server_id)
                
                # Preparar datos de vacuna
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
                    # Actualizar vacuna existente
                    VacunaRepository.update(db, existing_vacuna.id, vacuna_data_dict)
                    vacunas_ids[str(vacuna.local_id)] = {
                        'server_id': existing_vacuna.id,
                        'action': 'updated'
                    }
                else:
                    # Crear nueva vacuna
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
    
    Args:
        last_sync (str): Fecha ISO de última sincronización
        limit (int): Límite de registros
    
    Returns:
        SyncResponse: Actualizaciones disponibles
    """
    try:
        from datetime import datetime
        last_sync_dt = datetime.fromisoformat(last_sync.replace('Z', '+00:00'))
        
        updates = []
        
        # Pacientes actualizados/creados
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
        
        # Vacunas actualizadas/creadas
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

@app.get("/api/stats", tags=["Utilidad"])
async def get_statistics(db: Session = Depends(get_db)):
    """
    Obtener estadísticas del sistema
    
    Returns:
        dict: Estadísticas de pacientes, vacunas y usuarios
    """
    try:
        pacientes_count = db.query(Paciente).count()
        vacunas_count = db.query(Vacuna).count()
        usuarios_count = db.query(Usuario).count()
        
        # Últimos 7 días
        from datetime import datetime, timedelta
        seven_days_ago = datetime.now() - timedelta(days=7)
        
        pacientes_recent = db.query(Paciente).filter(
            Paciente.created_at >= seven_days_ago
        ).count()
        
        vacunas_recent = db.query(Vacuna).filter(
            Vacuna.created_at >= seven_days_ago
        ).count()
        
        return {
            "totales": {
                "pacientes": pacientes_count,
                "vacunas": vacunas_count,
                "usuarios": usuarios_count
            },
            "recientes_7_dias": {
                "pacientes": pacientes_recent,
                "vacunas": vacunas_recent
            },
            "timestamp": datetime.now().isoformat()
        }
        
    except Exception as e:
        logger.error(f"❌ Error obteniendo estadísticas: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Error obteniendo estadísticas"
        )

@app.get("/api/info", tags=["Utilidad"])
async def get_api_info():
    """
    Información detallada del API
    
    Returns:
        dict: Información de versión, endpoints, etc.
    """
    return {
        "name": "HealthShield API",
        "version": "2.0.0",
        "description": "API para gestión de pacientes y vacunas",
        "environment": os.environ.get('ENVIRONMENT', 'development'),
        "database": "Neon PostgreSQL",
        "provider": "Vercel",
        "endpoints": {
            "auth": {
                "register": "/api/auth/register",
                "login": "/api/auth/login",
                "me": "/api/auth/me"
            },
            "pacientes": {
                "create": "/api/pacientes",
                "list": "/api/pacientes",
                "detail": "/api/pacientes/{id}"
            },
            "vacunas": {
                "create": "/api/vacunas",
                "by_patient": "/api/pacientes/{id}/vacunas",
                "list": "/api/vacunas"
            },
            "sync": {
                "bulk": "/api/sync/bulk",
                "updates": "/api/sync/updates"
            },
            "diagnostic": {
                "health": "/health",
                "neon_status": "/api/neon/status",
                "stats": "/api/stats"
            }
        },
        "timestamp": datetime.now().isoformat()
    }

# ==================== MANEJO DE ERRORES GLOBAL ====================

@app.exception_handler(HTTPException)
async def http_exception_handler(request, exc):
    """Manejador global para excepciones HTTP"""
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
    """Manejador global para excepciones no controladas"""
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

# ==================== EJECUCIÓN PRINCIPAL ====================

if __name__ == "__main__":
    import uvicorn
    
    # Obtener puerto de Vercel o usar 8000 por defecto
    port = int(os.environ.get("PORT", 8000))
    
    print(f"\n🔧 Iniciando servidor en puerto {port}...")
    print(f"🌐 URL: http://localhost:{port}")
    print(f"📚 Docs: http://localhost:{port}/docs")
    print(f"🔍 Health: http://localhost:{port}/health")
    print("\n🟢 Servidor listo. Presiona Ctrl+C para detener.")
    
    uvicorn.run(
        app,
        host="0.0.0.0",
        port=port,
        log_level="info",
        reload=os.environ.get('ENVIRONMENT') == 'development'
    )