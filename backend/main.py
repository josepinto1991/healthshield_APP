from fastapi import FastAPI, HTTPException, Depends, Query, status
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session
import os
from datetime import datetime
from dotenv import load_dotenv
from jose import jwt
from typing import List, Optional, Dict, Any
import logging
from contextlib import asynccontextmanager

from database import get_db, init_db, hash_password
from models import (
    UsuarioCreate, UsuarioResponse, UserLogin, AuthResponse,
    PacienteCreate, PacienteResponse, PacienteUpdate,
    VacunaCreate, VacunaResponse, VacunaUpdate,
    MessageResponse, SyncResponse, BulkSyncData, BulkSyncResponse,
    HealthCheck, SyncPacientesRequest, SyncVacunasRequest, SyncFullRequest,
    Usuario, Paciente, Vacuna
)
from repositories import UsuarioRepository, PacienteRepository, VacunaRepository

# Configurar logging para producción
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

load_dotenv()

# Configuración de JWT
SECRET_KEY = os.environ.get("SECRET_KEY", "healthshield_production_secret_key_3312")
ALGORITHM = "HS256"

def create_access_token(data: dict):
    to_encode = data.copy()
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt

def create_default_admin(db: Session):
    """Crear usuario admin por defecto si no existe"""
    try:
        existing_admin = UsuarioRepository.get_by_username(db, "admin")
        if existing_admin:
            logger.info("✅ Usuario admin ya existe")
            return
        
        hashed_password = hash_password("Admin123!")  # Contraseña segura
        
        db_admin = Usuario(
            username="admin",
            email="admin@healthshield.com",
            password=hashed_password,
            telefono="0000000000",
            is_professional=True,
            professional_license="ADMIN-001",
            is_verified=True
        )
        
        db.add(db_admin)
        db.commit()
        logger.info("✅ Usuario admin creado exitosamente")
        
    except Exception as e:
        logger.error(f"⚠️ Error creando usuario admin: {e}")
        db.rollback()

@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    Lifespan mejorado con manejo de errores
    """
    # Startup
    logger.info("=" * 50)
    logger.info("🚀 Iniciando HealthShield API en Render...")
    logger.info(f"📁 Entorno: {os.environ.get('ENVIRONMENT', 'development')}")
    
    try:
        # Inicializar base de datos
        init_db()
        
        # Crear admin por defecto
        db = next(get_db())
        create_default_admin(db)
        
        logger.info("✅ HealthShield API iniciada correctamente")
        logger.info(f"🔐 Secret Key configurada: {'Sí' if SECRET_KEY else 'No'}")
        logger.info(f"🌐 CORS Origins: {os.environ.get('ALLOWED_ORIGINS', '*')}")
        
    except Exception as e:
        logger.error(f"❌ Error crítico al iniciar: {e}")
        logger.warning("⚠️  La API iniciará en modo limitado")
    
    yield
    
    # Shutdown
    logger.info("🛑 Deteniendo HealthShield API...")
    logger.info("=" * 50)

app = FastAPI(
    title="HealthShield API",
    version="2.0.0",
    description="API para gestión de pacientes y vacunas - Desplegado en Render",
    docs_url="/docs",
    redoc_url="/redoc",
    openapi_url="/openapi.json",
    lifespan=lifespan
)

# Configuración CORS para producción
allowed_origins_str = os.environ.get("ALLOWED_ORIGINS", "*")
allowed_origins = allowed_origins_str.split(",") if "," in allowed_origins_str else [allowed_origins_str]

logger.info(f"🌍 Configurando CORS para: {allowed_origins}")

app.add_middleware(
    CORSMiddleware,
    allow_origins=allowed_origins,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS", "PATCH"],
    allow_headers=["*"],
    expose_headers=["*"]
)

# ==================== ENDPOINTS DE DEBUG ====================

@app.get("/api/debug/env")
async def debug_env():
    """
    Endpoint para debug de variables de entorno (solo desarrollo)
    """
    import re
    
    env_vars = {}
    sensitive_keys = ['DATABASE_URL', 'SECRET_KEY', 'PASSWORD', 'TOKEN']
    
    for key, value in os.environ.items():
        if any(sensitive in key.upper() for sensitive in sensitive_keys):
            # Ocultar información sensible
            if 'DATABASE_URL' in key.upper() and value:
                # Ocultar contraseña en URL
                value = re.sub(r':([^:@]+)@', ':****@', value)
            elif 'SECRET' in key.upper() and value:
                value = f"{value[:10]}..." if len(value) > 10 else "****"
        env_vars[key] = value
    
    return {
        "app": "HealthShield API",
        "environment": os.environ.get("ENVIRONMENT", "development"),
        "debug_mode": os.environ.get("DEBUG", "False"),
        "variables": env_vars,
        "timestamp": datetime.now().isoformat()
    }

@app.get("/api/debug/db")
async def debug_db(db: Session = Depends(get_db)):
    """
    Endpoint para debug de base de datos
    """
    try:
        # Contar registros
        pacientes_count = db.query(Paciente).count()
        vacunas_count = db.query(Vacuna).count()
        usuarios_count = db.query(Usuario).count()
        
        # Obtener información de tablas
        from sqlalchemy import text
        tables_info = db.execute(text("""
            SELECT table_name 
            FROM information_schema.tables 
            WHERE table_schema = 'public'
            ORDER BY table_name
        """)).fetchall()
        
        tables = [table[0] for table in tables_info]
        
        return {
            "database_status": "connected",
            "tables": tables,
            "counts": {
                "pacientes": pacientes_count,
                "vacunas": vacunas_count,
                "usuarios": usuarios_count
            },
            "timestamp": datetime.now().isoformat()
        }
        
    except Exception as e:
        return {
            "database_status": "error",
            "error": str(e),
            "timestamp": datetime.now().isoformat()
        }

# ==================== ENDPOINTS DE AUTENTICACIÓN ====================

@app.post("/api/auth/register", response_model=AuthResponse, status_code=201)
async def register(usuario: UsuarioCreate, db: Session = Depends(get_db)):
    """Registrar un nuevo usuario"""
    logger.info(f"📝 Registrando usuario: {usuario.username}")
    
    if UsuarioRepository.get_by_username(db, usuario.username):
        raise HTTPException(status_code=400, detail="El usuario ya existe")
    
    if UsuarioRepository.get_by_email(db, usuario.email):
        raise HTTPException(status_code=400, detail="El email ya está registrado")
    
    try:
        db_usuario = UsuarioRepository.create(db, usuario)
        access_token = create_access_token({"sub": usuario.username, "user_id": db_usuario.id})
        
        logger.info(f"✅ Usuario registrado: {usuario.username}")
        
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
        raise HTTPException(status_code=500, detail=f'Error del servidor: {str(e)}')

@app.post("/api/auth/login", response_model=AuthResponse)
async def login(login_data: UserLogin, db: Session = Depends(get_db)):
    """Iniciar sesión"""
    logger.info(f"🔐 Login intento: {login_data.username}")
    
    usuario = UsuarioRepository.authenticate(db, login_data.username, login_data.password)
    if not usuario:
        logger.warning(f"❌ Login fallido: {login_data.username}")
        raise HTTPException(status_code=401, detail="Credenciales incorrectas")
    
    access_token = create_access_token(data={"sub": usuario.username, "user_id": usuario.id})
    
    logger.info(f"✅ Login exitoso: {login_data.username}")
    
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

# ==================== ENDPOINTS DE PACIENTES ====================

@app.post("/api/pacientes", response_model=MessageResponse, status_code=201)
async def add_paciente(paciente: PacienteCreate, db: Session = Depends(get_db)):
    """Agregar un nuevo paciente"""
    logger.info(f"➕ Agregando paciente: {paciente.nombre}")
    
    if PacienteRepository.get_by_cedula(db, paciente.cedula):
        raise HTTPException(status_code=400, detail="La cédula ya está registrada")
    
    try:
        db_paciente = PacienteRepository.create(db, paciente)
        
        logger.info(f"✅ Paciente agregado: {paciente.nombre} (ID: {db_paciente.id})")
        
        return MessageResponse(
            message='Paciente agregado correctamente',
            id=db_paciente.id,
            local_id=paciente.local_id
        )
        
    except Exception as e:
        logger.error(f"❌ Error agregando paciente: {e}")
        raise HTTPException(status_code=500, detail=f'Error del servidor: {str(e)}')

@app.get("/api/pacientes", response_model=List[PacienteResponse])
async def get_pacientes(
    db: Session = Depends(get_db),
    skip: int = 0,
    limit: int = 100
):
    """Obtener todos los pacientes con paginación"""
    logger.info(f"📋 Obteniendo pacientes (skip={skip}, limit={limit})")
    
    try:
        pacientes = PacienteRepository.get_all(db, skip=skip, limit=limit)
        total = db.query(Paciente).count()
        
        logger.info(f"✅ Encontrados {len(pacientes)}/{total} pacientes")
        
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
        raise HTTPException(status_code=500, detail=f'Error del servidor: {str(e)}')

# ==================== ENDPOINTS DE VACUNAS ====================

@app.post("/api/vacunas", response_model=MessageResponse, status_code=201)
async def add_vacuna(vacuna: VacunaCreate, db: Session = Depends(get_db)):
    """Registrar una nueva vacuna"""
    logger.info(f"💉 Registrando vacuna para paciente ID: {vacuna.paciente_id}")
    
    try:
        db_vacuna = VacunaRepository.create(db, vacuna)
        
        logger.info(f"✅ Vacuna registrada: {vacuna.nombre_vacuna} (ID: {db_vacuna.id})")
        
        return MessageResponse(
            message='Vacuna registrada correctamente',
            id=db_vacuna.id,
            local_id=vacuna.local_id
        )
        
    except ValueError as e:
        logger.error(f"❌ Error validando vacuna: {e}")
        raise HTTPException(status_code=404, detail=str(e))
    except Exception as e:
        logger.error(f"❌ Error registrando vacuna: {e}")
        raise HTTPException(status_code=500, detail=f'Error del servidor: {str(e)}')

# ==================== ENDPOINTS DE SINCRONIZACIÓN ====================

@app.post("/api/sync/full")
async def full_sync(
    request: SyncFullRequest,
    db: Session = Depends(get_db)
):
    """
    Sincronización completa bidireccional
    Para uso del frontend móvil
    """
    logger.info(f"🔄 Iniciando sync completo - Pacientes: {len(request.pacientes)}, Vacunas: {len(request.vacunas)}")
    
    start_time = datetime.now()
    pacientes_map = {}
    
    # 1. Sincronizar pacientes
    pacientes_result = []
    for paciente_data in request.pacientes:
        try:
            paciente_dict = paciente_data.dict()
            paciente = PacienteRepository.create_or_update(db, paciente_dict)
            
            pacientes_result.append({
                'local_id': paciente_data.local_id,
                'server_id': paciente.id,
                'action': 'created_or_updated',
                'success': True
            })
            
            pacientes_map[paciente_data.local_id] = paciente.id
            
            logger.debug(f"✅ Paciente sync: {paciente.nombre} (local:{paciente_data.local_id} -> server:{paciente.id})")
            
        except Exception as e:
            logger.error(f"❌ Error sync paciente {paciente_data.local_id}: {e}")
            pacientes_result.append({
                'local_id': paciente_data.local_id,
                'error': str(e),
                'success': False
            })
    
    # 2. Sincronizar vacunas
    vacunas_result = []
    for vacuna_data in request.vacunas:
        try:
            vacuna_dict = vacuna_data.dict()
            
            # Mapear paciente_id local a server_id
            local_paciente_id = vacuna_data.paciente_id
            server_paciente_id = pacientes_map.get(local_paciente_id, local_paciente_id)
            vacuna_dict['paciente_id'] = server_paciente_id
            
            vacuna = VacunaRepository.create_with_patient_check(db, vacuna_dict)
            
            vacunas_result.append({
                'local_id': vacuna_data.local_id,
                'server_id': vacuna.id,
                'action': 'created',
                'success': True
            })
            
            logger.debug(f"✅ Vacuna sync: {vacuna.nombre_vacuna} (local:{vacuna_data.local_id} -> server:{vacuna.id})")
            
        except Exception as e:
            logger.error(f"❌ Error sync vacuna {vacuna_data.local_id}: {e}")
            vacunas_result.append({
                'local_id': vacuna_data.local_id,
                'error': str(e),
                'success': False
            })
    
    # 3. Obtener datos actualizados
    all_pacientes = PacienteRepository.get_all(db, limit=1000)
    all_vacunas = VacunaRepository.get_all(db, limit=1000)
    
    sync_duration = (datetime.now() - start_time).total_seconds()
    
    logger.info(f"✅ Sync completado en {sync_duration:.2f}s - "
                f"Pacientes: {len(pacientes_result)}, Vacunas: {len(vacunas_result)}")
    
    return {
        'success': True,
        'message': 'Sincronización completa exitosa',
        'duration_seconds': sync_duration,
        'upload_results': {
            'pacientes': pacientes_result,
            'vacunas': vacunas_result
        },
        'download_data': {
            'pacientes': [
                {
                    'id': p.id,
                    'cedula': p.cedula,
                    'nombre': p.nombre,
                    'fecha_nacimiento': p.fecha_nacimiento,
                    'telefono': p.telefono,
                    'direccion': p.direccion,
                    'created_at': p.created_at.isoformat() if p.created_at else None,
                } for p in all_pacientes
            ],
            'vacunas': [
                {
                    'id': v.id,
                    'paciente_id': v.paciente_id,
                    'nombre_vacuna': v.nombre_vacuna,
                    'fecha_aplicacion': v.fecha_aplicacion,
                    'lote': v.lote,
                    'proxima_dosis': v.proxima_dosis,
                    'usuario_id': v.usuario_id,
                    'created_at': v.created_at.isoformat() if v.created_at else None,
                } for v in all_vacunas
            ]
        }
    }

# ==================== ENDPOINTS DE HEALTH CHECK ====================

@app.get("/", response_model=HealthCheck)
async def root():
    """Endpoint raíz"""
    return HealthCheck(
        status="healthy",
        timestamp=datetime.now().isoformat(),
        environment=os.environ.get('ENVIRONMENT', 'development'),
        database="PostgreSQL" if os.environ.get('ENVIRONMENT') == 'production' else "SQLite"
    )

@app.get("/health", response_model=HealthCheck)
async def health_check(db: Session = Depends(get_db)):
    """Health check completo para Render"""
    try:
        # Test de conexión a DB
        db.execute('SELECT 1')
        db_status = "connected"
        
        # Contar registros
        pacientes_count = db.query(Paciente).count()
        vacunas_count = db.query(Vacuna).count()
        usuarios_count = db.query(Usuario).count()
        
        # Obtener info del sistema
        import platform
        import sys
        
        return HealthCheck(
            status="healthy",
            timestamp=datetime.now().isoformat(),
            environment=os.environ.get('ENVIRONMENT', 'development'),
            database=db_status,
            metrics={
                "pacientes_count": pacientes_count,
                "vacunas_count": vacunas_count,
                "usuarios_count": usuarios_count,
                "python_version": platform.python_version(),
                "system": platform.system(),
                "memory_usage": "N/A"  # Podrías agregar psutil para más detalles
            }
        )
        
    except Exception as e:
        logger.error(f"❌ Health check failed: {e}")
        return HealthCheck(
            status="unhealthy",
            timestamp=datetime.now().isoformat(),
            environment=os.environ.get('ENVIRONMENT', 'development'),
            database=f"error: {str(e)}",
            metrics={"error": str(e)}
        )

# ==================== MIDDLEWARE ADICIONAL ====================

@app.middleware("http")
async def log_requests(request, call_next):
    """Middleware para log de requests"""
    start_time = datetime.now()
    
    response = await call_next(request)
    
    duration = (datetime.now() - start_time).total_seconds() * 1000
    
    logger.info(f"{request.method} {request.url.path} - Status: {response.status_code} - {duration:.2f}ms")
    
    return response

if __name__ == "__main__":
    import uvicorn
    
    port = int(os.environ.get("PORT", 10000))
    
    uvicorn.run(
        app,
        host="0.0.0.0",
        port=port,
        log_level="info"
    )