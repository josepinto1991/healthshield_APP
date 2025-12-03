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
SECRET_KEY = os.environ.get("SECRET_KEY", "healthshield_secret_key")
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
        
        hashed_password = hash_password("admin123")
        
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
    # Startup
    logger.info("🚀 Iniciando HealthShield API...")
    init_db()
    
    db = next(get_db())
    create_default_admin(db)
    
    logger.info("✅ HealthShield API iniciada correctamente")
    yield
    # Shutdown
    logger.info("🛑 Deteniendo HealthShield API...")

app = FastAPI(
    title="HealthShield API",
    version="1.0.0",
    description="API para gestión de pacientes y vacunas con sincronización offline",
    docs_url="/docs",
    redoc_url="/redoc",
    lifespan=lifespan
)

# Configuración CORS para producción
allowed_origins = os.environ.get("ALLOWED_ORIGINS", "").split(",")
if not allowed_origins or allowed_origins == [""]:
    allowed_origins = ["*"]

app.add_middleware(
    CORSMiddleware,
    allow_origins=allowed_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ==================== ENDPOINTS DE AUTENTICACIÓN ====================

@app.post("/api/auth/register", response_model=AuthResponse, status_code=201)
async def register(usuario: UsuarioCreate, db: Session = Depends(get_db)):
    """Registrar un nuevo usuario"""
    if UsuarioRepository.get_by_username(db, usuario.username):
        raise HTTPException(status_code=400, detail="El usuario ya existe")
    
    if UsuarioRepository.get_by_email(db, usuario.email):
        raise HTTPException(status_code=400, detail="El email ya está registrado")
    
    try:
        db_usuario = UsuarioRepository.create(db, usuario)
        access_token = create_access_token({"sub": usuario.username, "user_id": db_usuario.id})
        
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
        raise HTTPException(status_code=500, detail=f'Error del servidor: {str(e)}')

@app.post("/api/auth/login", response_model=AuthResponse)
async def login(login_data: UserLogin, db: Session = Depends(get_db)):
    """Iniciar sesión"""
    usuario = UsuarioRepository.authenticate(db, login_data.username, login_data.password)
    if not usuario:
        raise HTTPException(status_code=401, detail="Credenciales incorrectas")
    
    access_token = create_access_token(data={"sub": usuario.username, "user_id": usuario.id})
    
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

# ==================== ENDPOINTS DE USUARIOS ====================

@app.get("/api/users", response_model=List[UsuarioResponse])
async def get_usuarios(db: Session = Depends(get_db)):
    """Obtener todos los usuarios"""
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
        raise HTTPException(status_code=500, detail=f'Error del servidor: {str(e)}')

# ==================== ENDPOINTS DE PACIENTES ====================

@app.post("/api/pacientes", response_model=MessageResponse, status_code=201)
async def add_paciente(paciente: PacienteCreate, db: Session = Depends(get_db)):
    """Agregar un nuevo paciente"""
    if PacienteRepository.get_by_cedula(db, paciente.cedula):
        raise HTTPException(status_code=400, detail="La cédula ya está registrada")
    
    try:
        db_paciente = PacienteRepository.create(db, paciente)
        return MessageResponse(
            message='Paciente agregado correctamente',
            id=db_paciente.id,
            local_id=paciente.local_id
        )
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f'Error del servidor: {str(e)}')

@app.get("/api/pacientes", response_model=List[PacienteResponse])
async def get_pacientes(db: Session = Depends(get_db)):
    """Obtener todos los pacientes"""
    try:
        pacientes = PacienteRepository.get_all(db)
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
        raise HTTPException(status_code=500, detail=f'Error del servidor: {str(e)}')

@app.get("/api/pacientes/{paciente_id}", response_model=PacienteResponse)
async def get_paciente(paciente_id: int, db: Session = Depends(get_db)):
    """Obtener un paciente específico"""
    try:
        paciente = PacienteRepository.get_by_id(db, paciente_id)
        if not paciente:
            raise HTTPException(status_code=404, detail="Paciente no encontrado")
        
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
        raise HTTPException(status_code=500, detail=f'Error del servidor: {str(e)}')

# ==================== ENDPOINTS DE VACUNAS ====================

@app.post("/api/vacunas", response_model=MessageResponse, status_code=201)
async def add_vacuna(vacuna: VacunaCreate, db: Session = Depends(get_db)):
    """Registrar una nueva vacuna"""
    try:
        db_vacuna = VacunaRepository.create(db, vacuna)
        return MessageResponse(
            message='Vacuna registrada correctamente',
            id=db_vacuna.id,
            local_id=vacuna.local_id
        )
        
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f'Error del servidor: {str(e)}')

@app.get("/api/pacientes/{paciente_id}/vacunas", response_model=List[VacunaResponse])
async def get_vacunas_paciente(paciente_id: int, db: Session = Depends(get_db)):
    """Obtener todas las vacunas de un paciente"""
    try:
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
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f'Error del servidor: {str(e)}')

@app.get("/api/vacunas", response_model=List[VacunaResponse])
async def get_all_vacunas(db: Session = Depends(get_db)):
    """Obtener todas las vacunas"""
    try:
        vacunas = VacunaRepository.get_all(db)
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
        raise HTTPException(status_code=500, detail=f'Error del servidor: {str(e)}')

# ==================== ENDPOINTS DE SINCRONIZACIÓN ====================

@app.post("/api/sync/pacientes")
async def sync_pacientes(
    request: SyncPacientesRequest,
    db: Session = Depends(get_db)
):
    """Sincronizar múltiples pacientes desde el móvil"""
    resultados = []
    pacientes_map = {}
    
    for paciente_data in request.pacientes:
        try:
            # Usar create_or_update que verifica por cédula
            paciente_dict = paciente_data.dict()
            paciente = PacienteRepository.create_or_update(db, paciente_dict)
            
            resultados.append({
                'local_id': paciente_data.local_id,
                'server_id': paciente.id,
                'action': 'created_or_updated',
                'success': True
            })
            
            pacientes_map[paciente_data.local_id] = paciente.id
            
        except Exception as e:
            logger.error(f"Error sincronizando paciente {paciente_data.local_id}: {e}")
            resultados.append({
                'local_id': paciente_data.local_id,
                'error': str(e),
                'success': False
            })
    
    return {
        'message': 'Sincronización de pacientes completada',
        'results': resultados,
        'pacientes_map': pacientes_map
    }

@app.post("/api/sync/vacunas")
async def sync_vacunas(
    request: SyncVacunasRequest,
    db: Session = Depends(get_db)
):
    """Sincronizar múltiples vacunas desde el móvil"""
    resultados = []
    
    for vacuna_data in request.vacunas:
        try:
            vacuna_dict = vacuna_data.dict()
            vacuna = VacunaRepository.create_with_patient_check(db, vacuna_dict)
            
            resultados.append({
                'local_id': vacuna_data.local_id,
                'server_id': vacuna.id,
                'action': 'created',
                'success': True
            })
            
        except ValueError as e:
            logger.error(f"Error paciente no encontrado para vacuna {vacuna_data.local_id}: {e}")
            resultados.append({
                'local_id': vacuna_data.local_id,
                'error': str(e),
                'success': False
            })
        except Exception as e:
            logger.error(f"Error sincronizando vacuna {vacuna_data.local_id}: {e}")
            resultados.append({
                'local_id': vacuna_data.local_id,
                'error': str(e),
                'success': False
            })
    
    return {
        'message': 'Sincronización de vacunas completada',
        'results': resultados
    }

@app.post("/api/sync/full")
async def full_sync(
    request: SyncFullRequest,
    db: Session = Depends(get_db)
):
    """Sincronización completa bidireccional"""
    # 1. Sincronizar pacientes
    pacientes_result = []
    pacientes_map = {}
    
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
            
        except Exception as e:
            pacientes_result.append({
                'local_id': paciente_data.local_id,
                'error': str(e),
                'success': False
            })
    
    # 2. Sincronizar vacunas (usando el mapeo de IDs)
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
            
        except Exception as e:
            vacunas_result.append({
                'local_id': vacuna_data.local_id,
                'error': str(e),
                'success': False
            })
    
    # 3. Obtener todos los datos actualizados para enviar al cliente
    all_pacientes = PacienteRepository.get_all(db)
    all_vacunas = VacunaRepository.get_all(db)
    
    return {
        'message': 'Sincronización completa exitosa',
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

@app.get("/api/sync/updates")
async def get_updates(
    last_sync: str = Query("1970-01-01T00:00:00Z", description="Fecha de última sincronización"),
    db: Session = Depends(get_db)
):
    """Obtener actualizaciones desde la última sincronización"""
    try:
        updates = []
        
        # Obtener pacientes actualizados
        pacientes = db.query(Paciente).filter(Paciente.created_at > last_sync).all()
        for paciente in pacientes:
            paciente_data = {
                'tipo': 'paciente',
                'id': paciente.id,
                'cedula': paciente.cedula,
                'nombre': paciente.nombre,
                'fecha_nacimiento': paciente.fecha_nacimiento,
                'telefono': paciente.telefono,
                'direccion': paciente.direccion,
                'created_at': paciente.created_at.isoformat() if paciente.created_at else None
            }
            updates.append(paciente_data)
        
        # Obtener vacunas actualizadas
        vacunas = db.query(Vacuna).filter(Vacuna.created_at > last_sync).all()
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
                'created_at': vacuna.created_at.isoformat() if vacuna.created_at else None
            }
            updates.append(vacuna_data)
        
        return SyncResponse(
            message="Actualizaciones obtenidas correctamente",
            updates_count=len(updates),
            last_sync=datetime.now().isoformat(),
            updates=updates
        )
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f'Error del servidor: {str(e)}')

# ==================== ENDPOINTS DE UTILIDAD ====================

@app.get("/", response_model=HealthCheck)
async def root():
    """Endpoint raíz - Información básica del API"""
    return HealthCheck(
        status="healthy",
        timestamp=datetime.now().isoformat(),
        environment=os.environ.get('ENVIRONMENT', 'development'),
        database="PostgreSQL"
    )

@app.get("/health", response_model=HealthCheck)
async def health_check(db: Session = Depends(get_db)):
    """Health check completo"""
    try:
        # Verificar conexión a la base de datos
        db.execute('SELECT 1')
        db_status = "connected"
        
        # Contar registros
        pacientes_count = db.query(Paciente).count()
        vacunas_count = db.query(Vacuna).count()
        usuarios_count = db.query(Usuario).count()
        
    except Exception as e:
        db_status = f"error: {str(e)}"
        pacientes_count = 0
        vacunas_count = 0
        usuarios_count = 0
    
    return HealthCheck(
        status="healthy",
        timestamp=datetime.now().isoformat(),
        environment=os.environ.get('ENVIRONMENT', 'development'),
        database=db_status,
        metrics={
            "pacientes_count": pacientes_count,
            "vacunas_count": vacunas_count,
            "usuarios_count": usuarios_count
        }
    )

if __name__ == "__main__":
    import uvicorn
    
    port = int(os.environ.get("PORT", 8000))
    
    uvicorn.run(
        app,
        host="0.0.0.0",
        port=port,
        log_level="info"
    )