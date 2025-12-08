from fastapi import FastAPI, HTTPException, Depends, Query, status
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session
import os
from datetime import datetime
from dotenv import load_dotenv
from jose import jwt
from typing import List, Optional
import logging
from contextlib import asynccontextmanager

from database import get_db, init_db, hash_password
from models import (
    UsuarioCreate, UsuarioResponse, UserLogin, AuthResponse,
    PacienteCreate, PacienteResponse, PacienteUpdate,
    VacunaCreate, VacunaResponse, VacunaUpdate,
    MessageResponse, SyncResponse, BulkSyncData, BulkSyncResponse,
    HealthCheck, Usuario, Paciente, Vacuna
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
        
        # Cambiar contraseña a "admin" (sin exclamación)
        admin_password = os.environ.get('ADMIN_PASSWORD', 'admin')
        
        admin_data = UsuarioCreate(
            username="admin",
            email="admin@healthshield.com",
            password=admin_password,
            telefono="0000000000",
            is_professional=True,
            professional_license="ADMIN-001"
        )
        
        db_admin = UsuarioRepository.create(db, admin_data)
        db_admin.is_verified = True
        db.commit()
        
        logger.info(f"✅ Usuario admin creado exitosamente (usuario: admin, contraseña: {admin_password})")
        
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
    description="API para gestión de pacientes y vacunas",
    docs_url="/docs" if os.environ.get('ENVIRONMENT') == 'development' else None,
    redoc_url="/redoc" if os.environ.get('ENVIRONMENT') == 'development' else None,
    lifespan=lifespan
)

# Configuración CORS para producción
allowed_origins = os.environ.get("ALLOWED_ORIGINS", "").split(",")
if not allowed_origins or allowed_origins == [""]:
    allowed_origins = [
        "http://localhost:3000",
        "http://localhost",
        "https://healthshield-backend.onrender.com",
    ]

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

@app.post("/api/users/change-password")
async def change_password(
    current_password: str = Query(...),
    new_password: str = Query(...),
    user_id: int = Query(...),
    db: Session = Depends(get_db)
):
    """Cambiar contraseña de usuario"""
    try:
        usuario = UsuarioRepository.get_by_id(db, user_id)
        if not usuario:
            raise HTTPException(status_code=404, detail="Usuario no encontrado")
        
        from database import verify_password, hash_password
        
        if not verify_password(current_password, usuario.password):
            raise HTTPException(status_code=400, detail="Contraseña actual incorrecta")
        
        usuario.password = hash_password(new_password)
        db.commit()
        
        return MessageResponse(message="Contraseña actualizada exitosamente")
        
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
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
    """Obtener todas las vacunas (útil para sincronización)"""
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

@app.post("/api/sync/bulk", response_model=BulkSyncResponse)
async def bulk_sync(sync_data: BulkSyncData, db: Session = Depends(get_db)):
    """Sincronización masiva - para enviar múltiples datos a la vez"""
    pacientes_ids = {}
    vacunas_ids = {}
    
    try:
        # Sincronizar pacientes
        for paciente in sync_data.pacientes:
            try:
                existing_paciente = PacienteRepository.get_by_cedula(db, paciente.cedula)
                if not existing_paciente:
                    db_paciente = PacienteRepository.create(db, paciente)
                    if db_paciente:
                        pacientes_ids[paciente.local_id] = db_paciente.id
                        logger.info(f"✅ Paciente sincronizado: {paciente.nombre}")
                else:
                    pacientes_ids[paciente.local_id] = existing_paciente.id
                    logger.info(f"ℹ️  Paciente ya existía: {paciente.nombre}")
                    
            except Exception as e:
                logger.error(f"❌ Error sincronizando paciente {paciente.local_id}: {e}")
        
        # Sincronizar vacunas
        for vacuna in sync_data.vacunas:
            try:
                paciente_server_id = pacientes_ids.get(vacuna.paciente_id, vacuna.paciente_id)
                
                vacuna_data = VacunaCreate(
                    paciente_id=paciente_server_id,
                    nombre_vacuna=vacuna.nombre_vacuna,
                    fecha_aplicacion=vacuna.fecha_aplicacion,
                    lote=vacuna.lote,
                    proxima_dosis=vacuna.proxima_dosis,
                    usuario_id=vacuna.usuario_id,
                    local_id=vacuna.local_id
                )
                
                db_vacuna = VacunaRepository.create(db, vacuna_data)
                if db_vacuna:
                    vacunas_ids[vacuna.local_id] = db_vacuna.id
                    logger.info(f"✅ Vacuna sincronizada: {vacuna.nombre_vacuna}")
                    
            except Exception as e:
                logger.error(f"❌ Error sincronizando vacuna {vacuna.local_id}: {e}")
        
        return BulkSyncResponse(
            message="Sincronización masiva completada",
            pacientes_sincronizados=len(sync_data.pacientes),
            vacunas_sincronizadas=len(sync_data.vacunas),
            pacientes_ids=pacientes_ids,
            vacunas_ids=vacunas_ids
        )
        
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f'Error en sincronización masiva: {str(e)}')

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
        database="PostgreSQL" if os.environ.get('ENVIRONMENT') == 'production' else "SQLite"
    )

@app.get("/health", response_model=HealthCheck)
async def health_check(db: Session = Depends(get_db)):
    """Health check completo - Verifica estado del API y base de datos"""
    try:
        # Verificar conexión a la base de datos
        db.execute('SELECT 1')
        db_status = "connected"
        
        # Contar registros para verificar funcionalidad
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
    
    port = int(os.environ.get("PORT", 5001))
    
    uvicorn.run(
        app,
        host="0.0.0.0",
        port=port,
        log_level="info" if os.environ.get('ENVIRONMENT') == 'production' else "debug"
    )