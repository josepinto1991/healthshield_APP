# from fastapi import FastAPI, HTTPException, Depends, Query, status, BackgroundTasks
# from fastapi.middleware.cors import CORSMiddleware
# from sqlalchemy.orm import Session
# from sqlalchemy import text, or_
# import os
# from datetime import datetime, timedelta
# from dotenv import load_dotenv
# from jose import jwt, JWTError
# from typing import List, Optional, Dict, Any
# import logging
# from contextlib import asynccontextmanager

# from database import get_db, init_db
# from models import (
#     UsuarioCreate, UsuarioResponse, UserLogin, AuthResponse,
#     PacienteCreate, PacienteResponse, PacienteUpdate,
#     VacunaCreate, VacunaResponse, VacunaUpdate,
#     MessageResponse, HealthCheck,
#     BulkSyncData, BulkSyncResponse,
#     ClientSyncData, ClientSyncResponse,
#     FullDataResponse, SyncStatus, ConflictResolution,
#     Usuario, Paciente, Vacuna
# )
# from repositories import UsuarioRepository, PacienteRepository, VacunaRepository

# # Configurar logging
# logging.basicConfig(
#     level=logging.INFO,
#     format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
# )
# logger = logging.getLogger(__name__)

# load_dotenv()

# # Configuración de JWT
# SECRET_KEY = os.environ.get("SECRET_KEY", "healthshield_secret_key")
# ALGORITHM = "HS256"

# def create_access_token(data: dict):
#     to_encode = data.copy()
#     encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
#     return encoded_jwt

# def get_current_user(token: str = Depends(lambda: ""), db: Session = Depends(get_db)):
#     """Obtener usuario actual desde token JWT"""
#     credentials_exception = HTTPException(
#         status_code=status.HTTP_401_UNAUTHORIZED,
#         detail="No se pudieron validar las credenciales",
#         headers={"WWW-Authenticate": "Bearer"},
#     )
    
#     try:
#         payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
#         username: str = payload.get("sub")
#         if username is None:
#             raise credentials_exception
#     except JWTError:
#         raise credentials_exception
    
#     user = UsuarioRepository.get_by_username(db, username=username)
#     if user is None:
#         raise credentials_exception
#     return user

# def create_default_admin(db: Session):
#     """Crear usuario admin por defecto si no existe"""
#     try:
#         existing_admin = UsuarioRepository.get_by_username(db, "admin")
#         if existing_admin:
#             logger.info("✅ Usuario admin ya existe")
#             return
        
#         admin_password = os.environ.get('ADMIN_PASSWORD', 'admin')
        
#         admin_data = UsuarioCreate(
#             username="admin",
#             email="admin@healthshield.com",
#             password=admin_password,
#             telefono="0000000000",
#             is_professional=True,
#             professional_license="ADMIN-001"
#         )
        
#         db_admin = UsuarioRepository.create(db, admin_data)
#         db_admin.is_verified = True
#         db.commit()
        
#         logger.info(f"✅ Usuario admin creado exitosamente")
        
#     except Exception as e:
#         logger.error(f"⚠️ Error creando usuario admin: {e}")
#         db.rollback()

# @asynccontextmanager
# async def lifespan(app: FastAPI):
#     # Startup
#     logger.info("🚀 Iniciando HealthShield API...")
#     init_db()
    
#     db = next(get_db())
#     create_default_admin(db)
    
#     logger.info("✅ HealthShield API iniciada correctamente")
#     yield
#     # Shutdown
#     logger.info("🛑 Deteniendo HealthShield API...")

# app = FastAPI(
#     title="HealthShield API",
#     version="1.0.0",
#     description="API para gestión de pacientes y vacunas",
#     docs_url="/docs",
#     redoc_url="/redoc",
#     lifespan=lifespan
# )

# # Configuración CORS
# app.add_middleware(
#     CORSMiddleware,
#     allow_origins=["*"],
#     allow_credentials=True,
#     allow_methods=["*"],
#     allow_headers=["*"],
# )

# # ==================== ENDPOINTS DE AUTENTICACIÓN ====================

# @app.post("/api/auth/register", response_model=AuthResponse, status_code=201)
# async def register(usuario: UsuarioCreate, db: Session = Depends(get_db)):
#     """Registrar un nuevo usuario"""
#     if UsuarioRepository.get_by_username(db, usuario.username):
#         raise HTTPException(status_code=400, detail="El usuario ya existe")
    
#     if UsuarioRepository.get_by_email(db, usuario.email):
#         raise HTTPException(status_code=400, detail="El email ya está registrado")
    
#     try:
#         db_usuario = UsuarioRepository.create(db, usuario)
#         access_token = create_access_token({"sub": usuario.username, "user_id": db_usuario.id})
        
#         return AuthResponse(
#             message="Usuario registrado exitosamente",
#             user=UsuarioResponse(
#                 id=db_usuario.id,
#                 username=db_usuario.username,
#                 email=db_usuario.email,
#                 telefono=db_usuario.telefono,
#                 is_professional=db_usuario.is_professional,
#                 professional_license=db_usuario.professional_license,
#                 is_verified=db_usuario.is_verified,
#                 created_at=db_usuario.created_at,
#                 updated_at=db_usuario.updated_at
#             ),
#             token=access_token
#         )
        
#     except Exception as e:
#         logger.error(f"Error en registro: {e}")
#         raise HTTPException(status_code=500, detail=f'Error del servidor: {str(e)}')

# @app.post("/api/auth/login", response_model=AuthResponse)
# async def login(login_data: UserLogin, db: Session = Depends(get_db)):
#     """Iniciar sesión"""
#     usuario = UsuarioRepository.authenticate(db, login_data.username, login_data.password)
#     if not usuario:
#         raise HTTPException(status_code=401, detail="Credenciales incorrectas")
    
#     access_token = create_access_token(data={"sub": usuario.username, "user_id": usuario.id})
    
#     return AuthResponse(
#         message="Login exitoso",
#         user=UsuarioResponse(
#             id=usuario.id,
#             username=usuario.username,
#             email=usuario.email,
#             telefono=usuario.telefono,
#             is_professional=usuario.is_professional,
#             professional_license=usuario.professional_license,
#             is_verified=usuario.is_verified,
#             created_at=usuario.created_at,
#             updated_at=usuario.updated_at
#         ),
#         token=access_token
#     )

# # ==================== ENDPOINTS DE USUARIOS ====================

# @app.get("/api/users", response_model=List[UsuarioResponse])
# async def get_usuarios(
#     skip: int = Query(0, ge=0),
#     limit: int = Query(100, ge=1, le=1000),
#     db: Session = Depends(get_db)
# ):
#     """Obtener todos los usuarios"""
#     try:
#         usuarios = UsuarioRepository.get_all(db, skip=skip, limit=limit)
#         return [
#             UsuarioResponse(
#                 id=usuario.id,
#                 username=usuario.username,
#                 email=usuario.email,
#                 telefono=usuario.telefono,
#                 is_professional=usuario.is_professional,
#                 professional_license=usuario.professional_license,
#                 is_verified=usuario.is_verified,
#                 created_at=usuario.created_at,
#                 updated_at=usuario.updated_at
#             ) for usuario in usuarios
#         ]
        
#     except Exception as e:
#         logger.error(f"Error obteniendo usuarios: {e}")
#         raise HTTPException(status_code=500, detail=f'Error del servidor: {str(e)}')

# @app.get("/api/users/{user_id}", response_model=UsuarioResponse)
# async def get_usuario(user_id: int, db: Session = Depends(get_db)):
#     """Obtener un usuario específico"""
#     try:
#         usuario = UsuarioRepository.get_by_id(db, user_id)
#         if not usuario:
#             raise HTTPException(status_code=404, detail="Usuario no encontrado")
        
#         return UsuarioResponse(
#             id=usuario.id,
#             username=usuario.username,
#             email=usuario.email,
#             telefono=usuario.telefono,
#             is_professional=usuario.is_professional,
#             professional_license=usuario.professional_license,
#             is_verified=usuario.is_verified,
#             created_at=usuario.created_at,
#             updated_at=usuario.updated_at
#         )
        
#     except HTTPException:
#         raise
#     except Exception as e:
#         logger.error(f"Error obteniendo usuario: {e}")
#         raise HTTPException(status_code=500, detail=f'Error del servidor: {str(e)}')

# @app.put("/api/users/{user_id}")
# async def update_usuario(
#     user_id: int,
#     usuario_update: dict,
#     db: Session = Depends(get_db),
#     current_user: Usuario = Depends(get_current_user)
# ):
#     """Actualizar usuario"""
#     try:
#         if current_user.id != user_id and current_user.username != "admin":
#             raise HTTPException(status_code=403, detail="No autorizado")
        
#         usuario = UsuarioRepository.get_by_id(db, user_id)
#         if not usuario:
#             raise HTTPException(status_code=404, detail="Usuario no encontrado")
        
#         # Actualizar campos permitidos
#         allowed_fields = ['telefono', 'is_professional', 'professional_license']
#         for field in allowed_fields:
#             if field in usuario_update:
#                 setattr(usuario, field, usuario_update[field])
        
#         db.commit()
#         db.refresh(usuario)
        
#         return MessageResponse(message="Usuario actualizado exitosamente")
        
#     except HTTPException:
#         raise
#     except Exception as e:
#         db.rollback()
#         logger.error(f"Error actualizando usuario: {e}")
#         raise HTTPException(status_code=500, detail=f'Error del servidor: {str(e)}')

# @app.post("/api/users/change-password")
# async def change_password(
#     current_password: str = Query(...),
#     new_password: str = Query(...),
#     user_id: int = Query(...),
#     db: Session = Depends(get_db),
#     current_user: Usuario = Depends(get_current_user)
# ):
#     """Cambiar contraseña de usuario"""
#     try:
#         if current_user.id != user_id and current_user.username != "admin":
#             raise HTTPException(status_code=403, detail="No autorizado")
        
#         usuario = UsuarioRepository.get_by_id(db, user_id)
#         if not usuario:
#             raise HTTPException(status_code=404, detail="Usuario no encontrado")
        
#         from database import verify_password, hash_password
        
#         if not verify_password(current_password, usuario.password):
#             raise HTTPException(status_code=400, detail="Contraseña actual incorrecta")
        
#         usuario.password = hash_password(new_password)
#         db.commit()
        
#         return MessageResponse(message="Contraseña actualizada exitosamente")
        
#     except HTTPException:
#         raise
#     except Exception as e:
#         db.rollback()
#         logger.error(f"Error cambiando contraseña: {e}")
#         raise HTTPException(status_code=500, detail=f'Error del servidor: {str(e)}')

# # ==================== ENDPOINTS DE PACIENTES ====================

# @app.post("/api/pacientes", response_model=MessageResponse, status_code=201)
# async def add_paciente(
#     paciente: PacienteCreate,
#     db: Session = Depends(get_db),
#     current_user: Usuario = Depends(get_current_user)
# ):
#     """Agregar un nuevo paciente"""
#     if PacienteRepository.get_by_cedula(db, paciente.cedula):
#         raise HTTPException(status_code=400, detail="La cédula ya está registrada")
    
#     try:
#         db_paciente = PacienteRepository.create(db, paciente)
#         return MessageResponse(
#             message='Paciente agregado correctamente',
#             id=db_paciente.id,
#             local_id=paciente.local_id
#         )
        
#     except Exception as e:
#         logger.error(f"Error agregando paciente: {e}")
#         raise HTTPException(status_code=500, detail=f'Error del servidor: {str(e)}')

# @app.get("/api/pacientes", response_model=List[PacienteResponse])
# async def get_pacientes(
#     skip: int = Query(0, ge=0),
#     limit: int = Query(100, ge=1, le=1000),
#     search: Optional[str] = Query(None),
#     db: Session = Depends(get_db)
# ):
#     """Obtener todos los pacientes"""
#     try:
#         query = db.query(Paciente)
        
#         if search:
#             query = query.filter(
#                 or_(
#                     Paciente.cedula.ilike(f"%{search}%"),
#                     Paciente.nombre.ilike(f"%{search}%"),
#                     Paciente.telefono.ilike(f"%{search}%")
#                 )
#             )
        
#         pacientes = query.offset(skip).limit(limit).all()
        
#         return [
#             PacienteResponse(
#                 id=paciente.id,
#                 cedula=paciente.cedula,
#                 nombre=paciente.nombre,
#                 fecha_nacimiento=paciente.fecha_nacimiento,
#                 telefono=paciente.telefono,
#                 direccion=paciente.direccion,
#                 created_at=paciente.created_at.isoformat() if paciente.created_at else None,
#                 updated_at=paciente.updated_at.isoformat() if paciente.updated_at else None
#             ) for paciente in pacientes
#         ]
        
#     except Exception as e:
#         logger.error(f"Error obteniendo pacientes: {e}")
#         raise HTTPException(status_code=500, detail=f'Error del servidor: {str(e)}')

# @app.get("/api/pacientes/{paciente_id}", response_model=PacienteResponse)
# async def get_paciente(paciente_id: int, db: Session = Depends(get_db)):
#     """Obtener un paciente específico"""
#     try:
#         paciente = PacienteRepository.get_by_id(db, paciente_id)
#         if not paciente:
#             raise HTTPException(status_code=404, detail="Paciente no encontrado")
        
#         return PacienteResponse(
#             id=paciente.id,
#             cedula=paciente.cedula,
#             nombre=paciente.nombre,
#             fecha_nacimiento=paciente.fecha_nacimiento,
#             telefono=paciente.telefono,
#             direccion=paciente.direccion,
#             created_at=paciente.created_at.isoformat() if paciente.created_at else None,
#             updated_at=paciente.updated_at.isoformat() if paciente.updated_at else None
#         )
        
#     except HTTPException:
#         raise
#     except Exception as e:
#         logger.error(f"Error obteniendo paciente: {e}")
#         raise HTTPException(status_code=500, detail=f'Error del servidor: {str(e)}')

# @app.put("/api/pacientes/{paciente_id}")
# async def update_paciente(
#     paciente_id: int,
#     paciente_update: PacienteUpdate,
#     db: Session = Depends(get_db),
#     current_user: Usuario = Depends(get_current_user)
# ):
#     """Actualizar paciente"""
#     try:
#         paciente = PacienteRepository.get_by_id(db, paciente_id)
#         if not paciente:
#             raise HTTPException(status_code=404, detail="Paciente no encontrado")
        
#         # Verificar si la cédula ya existe (si se está actualizando)
#         if paciente_update.cedula and paciente_update.cedula != paciente.cedula:
#             existing = PacienteRepository.get_by_cedula(db, paciente_update.cedula)
#             if existing:
#                 raise HTTPException(status_code=400, detail="La cédula ya está registrada")
        
#         # Actualizar campos
#         update_data = paciente_update.dict(exclude_unset=True)
#         updated_paciente = PacienteRepository.update(db, paciente_id, update_data)
        
#         if not updated_paciente:
#             raise HTTPException(status_code=404, detail="Paciente no encontrado")
        
#         return MessageResponse(message="Paciente actualizado exitosamente")
        
#     except HTTPException:
#         raise
#     except Exception as e:
#         db.rollback()
#         logger.error(f"Error actualizando paciente: {e}")
#         raise HTTPException(status_code=500, detail=f'Error del servidor: {str(e)}')

# @app.delete("/api/pacientes/{paciente_id}")
# async def delete_paciente(
#     paciente_id: int,
#     db: Session = Depends(get_db),
#     current_user: Usuario = Depends(get_current_user)
# ):
#     """Eliminar paciente"""
#     try:
#         paciente = PacienteRepository.get_by_id(db, paciente_id)
#         if not paciente:
#             raise HTTPException(status_code=404, detail="Paciente no encontrado")
        
#         # Verificar si tiene vacunas asociadas
#         vacunas = VacunaRepository.get_by_paciente(db, paciente_id)
#         if vacunas:
#             raise HTTPException(
#                 status_code=400,
#                 detail="No se puede eliminar el paciente porque tiene vacunas registradas"
#             )
        
#         db.delete(paciente)
#         db.commit()
        
#         return MessageResponse(message="Paciente eliminado exitosamente")
        
#     except HTTPException:
#         raise
#     except Exception as e:
#         db.rollback()
#         logger.error(f"Error eliminando paciente: {e}")
#         raise HTTPException(status_code=500, detail=f'Error del servidor: {str(e)}')

# # ==================== ENDPOINTS DE VACUNAS ====================

# @app.post("/api/vacunas", response_model=MessageResponse, status_code=201)
# async def add_vacuna(
#     vacuna: VacunaCreate,
#     db: Session = Depends(get_db),
#     current_user: Usuario = Depends(get_current_user)
# ):
#     """Registrar una nueva vacuna"""
#     try:
#         db_vacuna = VacunaRepository.create(db, vacuna)
#         return MessageResponse(
#             message='Vacuna registrada correctamente',
#             id=db_vacuna.id,
#             local_id=vacuna.local_id
#         )
        
#     except ValueError as e:
#         raise HTTPException(status_code=404, detail=str(e))
#     except Exception as e:
#         logger.error(f"Error agregando vacuna: {e}")
#         raise HTTPException(status_code=500, detail=f'Error del servidor: {str(e)}')

# @app.get("/api/pacientes/{paciente_id}/vacunas", response_model=List[VacunaResponse])
# async def get_vacunas_paciente(
#     paciente_id: int,
#     skip: int = Query(0, ge=0),
#     limit: int = Query(100, ge=1, le=1000),
#     db: Session = Depends(get_db)
# ):
#     """Obtener todas las vacunas de un paciente"""
#     try:
#         paciente = PacienteRepository.get_by_id(db, paciente_id)
#         if not paciente:
#             raise HTTPException(status_code=404, detail="Paciente no encontrado")
        
#         vacunas = db.query(Vacuna).filter(
#             Vacuna.paciente_id == paciente_id
#         ).offset(skip).limit(limit).all()
        
#         return [
#             VacunaResponse(
#                 id=vacuna.id,
#                 paciente_id=vacuna.paciente_id,
#                 nombre_vacuna=vacuna.nombre_vacuna,
#                 fecha_aplicacion=vacuna.fecha_aplicacion,
#                 lote=vacuna.lote,
#                 proxima_dosis=vacuna.proxima_dosis,
#                 usuario_id=vacuna.usuario_id,
#                 created_at=vacuna.created_at.isoformat() if vacuna.created_at else None,
#                 paciente_nombre=vacuna.paciente.nombre if vacuna.paciente else None,
#                 usuario_nombre=vacuna.usuario.username if vacuna.usuario else None
#             ) for vacuna in vacunas
#         ]
        
#     except HTTPException:
#         raise
#     except Exception as e:
#         logger.error(f"Error obteniendo vacunas: {e}")
#         raise HTTPException(status_code=500, detail=f'Error del servidor: {str(e)}')

# @app.get("/api/vacunas", response_model=List[VacunaResponse])
# async def get_all_vacunas(
#     skip: int = Query(0, ge=0),
#     limit: int = Query(100, ge=1, le=1000),
#     paciente_id: Optional[int] = Query(None),
#     usuario_id: Optional[int] = Query(None),
#     db: Session = Depends(get_db)
# ):
#     """Obtener todas las vacunas"""
#     try:
#         query = db.query(Vacuna)
        
#         if paciente_id:
#             query = query.filter(Vacuna.paciente_id == paciente_id)
        
#         if usuario_id:
#             query = query.filter(Vacuna.usuario_id == usuario_id)
        
#         vacunas = query.offset(skip).limit(limit).all()
        
#         return [
#             VacunaResponse(
#                 id=vacuna.id,
#                 paciente_id=vacuna.paciente_id,
#                 nombre_vacuna=vacuna.nombre_vacuna,
#                 fecha_aplicacion=vacuna.fecha_aplicacion,
#                 lote=vacuna.lote,
#                 proxima_dosis=vacuna.proxima_dosis,
#                 usuario_id=vacuna.usuario_id,
#                 created_at=vacuna.created_at.isoformat() if vacuna.created_at else None,
#                 paciente_nombre=vacuna.paciente.nombre if vacuna.paciente else None,
#                 usuario_nombre=vacuna.usuario.username if vacuna.usuario else None
#             ) for vacuna in vacunas
#         ]
        
#     except Exception as e:
#         logger.error(f"Error obteniendo vacunas: {e}")
#         raise HTTPException(status_code=500, detail=f'Error del servidor: {str(e)}')

# @app.get("/api/vacunas/{vacuna_id}", response_model=VacunaResponse)
# async def get_vacuna(vacuna_id: int, db: Session = Depends(get_db)):
#     """Obtener una vacuna específica"""
#     try:
#         vacuna = VacunaRepository.get_by_id(db, vacuna_id)
#         if not vacuna:
#             raise HTTPException(status_code=404, detail="Vacuna no encontrada")
        
#         return VacunaResponse(
#             id=vacuna.id,
#             paciente_id=vacuna.paciente_id,
#             nombre_vacuna=vacuna.nombre_vacuna,
#             fecha_aplicacion=vacuna.fecha_aplicacion,
#             lote=vacuna.lote,
#             proxima_dosis=vacuna.proxima_dosis,
#             usuario_id=vacuna.usuario_id,
#             created_at=vacuna.created_at.isoformat() if vacuna.created_at else None,
#             paciente_nombre=vacuna.paciente.nombre if vacuna.paciente else None,
#             usuario_nombre=vacuna.usuario.username if vacuna.usuario else None
#         )
        
#     except HTTPException:
#         raise
#     except Exception as e:
#         logger.error(f"Error obteniendo vacuna: {e}")
#         raise HTTPException(status_code=500, detail=f'Error del servidor: {str(e)}')

# @app.put("/api/vacunas/{vacuna_id}")
# async def update_vacuna(
#     vacuna_id: int,
#     vacuna_update: VacunaUpdate,
#     db: Session = Depends(get_db),
#     current_user: Usuario = Depends(get_current_user)
# ):
#     """Actualizar vacuna"""
#     try:
#         vacuna = VacunaRepository.get_by_id(db, vacuna_id)
#         if not vacuna:
#             raise HTTPException(status_code=404, detail="Vacuna no encontrada")
        
#         # Actualizar campos
#         update_data = vacuna_update.dict(exclude_unset=True)
#         updated_vacuna = VacunaRepository.update(db, vacuna_id, update_data)
        
#         if not updated_vacuna:
#             raise HTTPException(status_code=404, detail="Vacuna no encontrada")
        
#         return MessageResponse(message="Vacuna actualizada exitosamente")
        
#     except HTTPException:
#         raise
#     except Exception as e:
#         db.rollback()
#         logger.error(f"Error actualizando vacuna: {e}")
#         raise HTTPException(status_code=500, detail=f'Error del servidor: {str(e)}')

# @app.delete("/api/vacunas/{vacuna_id}")
# async def delete_vacuna(
#     vacuna_id: int,
#     db: Session = Depends(get_db),
#     current_user: Usuario = Depends(get_current_user)
# ):
#     """Eliminar vacuna"""
#     try:
#         vacuna = VacunaRepository.get_by_id(db, vacuna_id)
#         if not vacuna:
#             raise HTTPException(status_code=404, detail="Vacuna no encontrada")
        
#         db.delete(vacuna)
#         db.commit()
        
#         return MessageResponse(message="Vacuna eliminada exitosamente")
        
#     except HTTPException:
#         raise
#     except Exception as e:
#         db.rollback()
#         logger.error(f"Error eliminando vacuna: {e}")
#         raise HTTPException(status_code=500, detail=f'Error del servidor: {str(e)}')

# # ==================== ENDPOINTS DE SINCRONIZACIÓN ====================

# @app.post("/api/sync/from-client", response_model=BulkSyncResponse)
# async def sync_from_client(
#     sync_data: BulkSyncData,
#     background_tasks: BackgroundTasks,
#     db: Session = Depends(get_db)
# ):
#     """Sincronización DESDE el cliente HACIA el servidor"""
#     pacientes_ids = {}
#     vacunas_ids = {}
#     conflicts = []
#     synced_pacientes = 0
#     synced_vacunas = 0
    
#     try:
#         # Procesar pacientes
#         for paciente in sync_data.pacientes:
#             try:
#                 existing_paciente = PacienteRepository.get_by_cedula(db, paciente.cedula)
                
#                 if not existing_paciente:
#                     # Nuevo paciente
#                     db_paciente = PacienteRepository.create(db, paciente)
#                     pacientes_ids[str(paciente.local_id)] = {
#                         'server_id': db_paciente.id,
#                         'action': 'created',
#                         'local_id': paciente.local_id
#                     }
#                     synced_pacientes += 1
#                     logger.info(f"✅ Paciente sincronizado: {paciente.nombre}")
#                 else:
#                     # Paciente ya existe
#                     pacientes_ids[str(paciente.local_id)] = {
#                         'server_id': existing_paciente.id,
#                         'action': 'existing',
#                         'local_id': paciente.local_id
#                     }
#                     logger.info(f"ℹ️  Paciente ya existe: {paciente.nombre}")
                    
#             except Exception as e:
#                 logger.error(f"❌ Error sincronizando paciente {paciente.local_id}: {e}")
#                 conflicts.append({
#                     'type': 'paciente',
#                     'local_id': paciente.local_id,
#                     'error': str(e),
#                     'data': paciente.dict()
#                 })
        
#         # Procesar vacunas
#         for vacuna in sync_data.vacunas:
#             try:
#                 # Obtener ID mapeado del paciente
#                 paciente_info = pacientes_ids.get(str(vacuna.paciente_id), {})
#                 paciente_server_id = paciente_info.get('server_id', vacuna.paciente_id)
                
#                 # Crear vacuna
#                 vacuna_data = VacunaCreate(
#                     paciente_id=paciente_server_id,
#                     nombre_vacuna=vacuna.nombre_vacuna,
#                     fecha_aplicacion=vacuna.fecha_aplicacion,
#                     lote=vacuna.lote,
#                     proxima_dosis=vacuna.proxima_dosis,
#                     usuario_id=vacuna.usuario_id,
#                     local_id=vacuna.local_id
#                 )
                
#                 db_vacuna = VacunaRepository.create(db, vacuna_data)
#                 vacunas_ids[str(vacuna.local_id)] = {
#                     'server_id': db_vacuna.id,
#                     'action': 'created',
#                     'local_id': vacuna.local_id
#                 }
#                 synced_vacunas += 1
#                 logger.info(f"✅ Vacuna sincronizada: {vacuna.nombre_vacuna}")
                    
#             except Exception as e:
#                 logger.error(f"❌ Error sincronizando vacuna {vacuna.local_id}: {e}")
#                 conflicts.append({
#                     'type': 'vacuna',
#                     'local_id': vacuna.local_id,
#                     'error': str(e),
#                     'data': vacuna.dict()
#                 })
        
#         logger.info(f"📊 Sincronización completada: {synced_pacientes} pacientes, {synced_vacunas} vacunas")
        
#         return BulkSyncResponse(
#             message="Sincronización desde cliente completada",
#             pacientes_sincronizados=synced_pacientes,
#             vacunas_sincronizadas=synced_vacunas,
#             pacientes_ids=pacientes_ids,
#             vacunas_ids=vacunas_ids,
#             conflicts=conflicts if conflicts else None,
#             server_timestamp=datetime.now().isoformat()
#         )
        
#     except Exception as e:
#         db.rollback()
#         logger.error(f"❌ Error en sincronización: {str(e)}")
#         raise HTTPException(status_code=500, detail=f'Error en sincronización: {str(e)}')

# @app.get("/api/sync/to-client", response_model=ClientSyncResponse)
# async def sync_to_client(
#     last_sync: str = Query("1970-01-01T00:00:00Z"),
#     limit: int = Query(100, ge=1, le=500),
#     offset: int = Query(0, ge=0),
#     db: Session = Depends(get_db)
# ):
#     """Sincronización DESDE el servidor HACIA el cliente"""
#     try:
#         # Convertir string a datetime
#         last_sync_dt = datetime.fromisoformat(last_sync.replace('Z', '+00:00'))
        
#         # Obtener pacientes modificados
#         pacientes = db.query(Paciente).filter(
#             (Paciente.created_at > last_sync_dt) | 
#             (Paciente.updated_at > last_sync_dt)
#         ).offset(offset).limit(limit).all()
        
#         pacientes_data = []
#         for paciente in pacientes:
#             pacientes_data.append({
#                 'id': paciente.id,
#                 'cedula': paciente.cedula,
#                 'nombre': paciente.nombre,
#                 'fecha_nacimiento': paciente.fecha_nacimiento,
#                 'telefono': paciente.telefono,
#                 'direccion': paciente.direccion,
#                 'created_at': paciente.created_at.isoformat() if paciente.created_at else None,
#                 'updated_at': paciente.updated_at.isoformat() if paciente.updated_at else None,
#                 'sync_action': 'created' if paciente.created_at > last_sync_dt else 'updated'
#             })
        
#         # Obtener vacunas modificadas
#         vacunas = db.query(Vacuna).filter(
#             (Vacuna.created_at > last_sync_dt) | 
#             (Vacuna.updated_at > last_sync_dt)
#         ).offset(offset).limit(limit).all()
        
#         vacunas_data = []
#         for vacuna in vacunas:
#             vacunas_data.append({
#                 'id': vacuna.id,
#                 'paciente_id': vacuna.paciente_id,
#                 'nombre_vacuna': vacuna.nombre_vacuna,
#                 'fecha_aplicacion': vacuna.fecha_aplicacion,
#                 'lote': vacuna.lote,
#                 'proxima_dosis': vacuna.proxima_dosis,
#                 'usuario_id': vacuna.usuario_id,
#                 'created_at': vacuna.created_at.isoformat() if vacuna.created_at else None,
#                 'updated_at': vacuna.updated_at.isoformat() if vacuna.updated_at else None,
#                 'sync_action': 'created' if vacuna.created_at > last_sync_dt else 'updated'
#             })
        
#         # Verificar si hay más datos
#         total_pacientes = len(pacientes)
#         total_vacunas = len(vacunas)
#         has_more = (total_pacientes == limit) or (total_vacunas == limit)
        
#         return ClientSyncResponse(
#             message="Datos para sincronización hacia cliente",
#             last_sync_server=datetime.now().isoformat(),
#             pacientes=pacientes_data,
#             vacunas=vacunas_data,
#             total_pacientes=total_pacientes,
#             total_vacunas=total_vacunas,
#             has_more=has_more
#         )
        
#     except Exception as e:
#         logger.error(f"❌ Error obteniendo actualizaciones: {str(e)}")
#         raise HTTPException(status_code=500, detail=f'Error obteniendo actualizaciones: {str(e)}')

# @app.get("/api/sync/full-data", response_model=FullDataResponse)
# async def get_full_data_for_client(db: Session = Depends(get_db)):
#     """Obtener TODOS los datos para inicialización del cliente"""
#     try:
#         # Obtener todos los pacientes
#         pacientes = PacienteRepository.get_all(db, limit=1000)
#         pacientes_data = []
#         for paciente in pacientes:
#             pacientes_data.append({
#                 'id': paciente.id,
#                 'cedula': paciente.cedula,
#                 'nombre': paciente.nombre,
#                 'fecha_nacimiento': paciente.fecha_nacimiento,
#                 'telefono': paciente.telefono,
#                 'direccion': paciente.direccion,
#                 'created_at': paciente.created_at.isoformat() if paciente.created_at else None,
#                 'updated_at': paciente.updated_at.isoformat() if paciente.updated_at else None
#             })
        
#         # Obtener todas las vacunas
#         vacunas = VacunaRepository.get_all(db, limit=1000)
#         vacunas_data = []
#         for vacuna in vacunas:
#             vacunas_data.append({
#                 'id': vacuna.id,
#                 'paciente_id': vacuna.paciente_id,
#                 'nombre_vacuna': vacuna.nombre_vacuna,
#                 'fecha_aplicacion': vacuna.fecha_aplicacion,
#                 'lote': vacuna.lote,
#                 'proxima_dosis': vacuna.proxima_dosis,
#                 'usuario_id': vacuna.usuario_id,
#                 'created_at': vacuna.created_at.isoformat() if vacuna.created_at else None,
#                 'updated_at': vacuna.updated_at.isoformat() if vacuna.updated_at else None
#             })
        
#         logger.info(f"📊 Datos completos: {len(pacientes_data)} pacientes, {len(vacunas_data)} vacunas")
        
#         return FullDataResponse(
#             message="Datos completos para inicialización del cliente",
#             server_timestamp=datetime.now().isoformat(),
#             pacientes=pacientes_data,
#             vacunas=vacunas_data,
#             total_pacientes=len(pacientes_data),
#             total_vacunas=len(vacunas_data)
#         )
        
#     except Exception as e:
#         logger.error(f"❌ Error obteniendo datos completos: {str(e)}")
#         raise HTTPException(status_code=500, detail=f'Error obteniendo datos completos: {str(e)}')

# @app.get("/api/sync/status", response_model=SyncStatus)
# async def get_sync_status(db: Session = Depends(get_db)):
#     """Obtener estado de sincronización"""
#     try:
#         # Contar datos en el servidor
#         pacientes_count = db.query(Paciente).count()
#         vacunas_count = db.query(Vacuna).count()
#         usuarios_count = db.query(Usuario).count()
        
#         return SyncStatus(
#             status="online",
#             last_sync=None,
#             pending_changes=0,
#             server_available=True,
#             server_counts={
#                 "pacientes": pacientes_count,
#                 "vacunas": vacunas_count,
#                 "usuarios": usuarios_count
#             }
#         )
        
#     except Exception as e:
#         logger.error(f"❌ Error obteniendo estado: {str(e)}")
#         return SyncStatus(
#             status="error",
#             server_available=False,
#             error=str(e)
#         )

# @app.post("/api/sync/resolve-conflict")
# async def resolve_conflict(
#     resolution: ConflictResolution,
#     db: Session = Depends(get_db),
#     current_user: Usuario = Depends(get_current_user)
# ):
#     """Resolver conflictos de sincronización"""
#     try:
#         logger.info(f"🔧 Resolviendo conflicto {resolution.conflict_id}: {resolution.resolution}")
        
#         # Aquí implementarías la lógica para resolver conflictos
#         # Por ahora solo registramos la resolución
        
#         return MessageResponse(
#             message=f"Conflicto {resolution.conflict_id} resuelto con estrategia: {resolution.resolution}"
#         )
        
#     except Exception as e:
#         logger.error(f"❌ Error resolviendo conflicto: {str(e)}")
#         raise HTTPException(status_code=500, detail=f'Error resolviendo conflicto: {str(e)}')

# # ==================== ENDPOINTS EXISTENTES DE SINCRONIZACIÓN (para compatibilidad) ====================

# @app.post("/api/sync/bulk", response_model=BulkSyncResponse)
# async def bulk_sync(sync_data: BulkSyncData, db: Session = Depends(get_db)):
#     """Sincronización masiva - para compatibilidad"""
#     from fastapi import BackgroundTasks
#     return await sync_from_client(sync_data, BackgroundTasks(), db)

# @app.get("/api/sync/updates")
# async def get_updates(
#     last_sync: str = Query("1970-01-01T00:00:00Z"),
#     db: Session = Depends(get_db)
# ):
#     """Obtener actualizaciones - para compatibilidad"""
#     return await sync_to_client(last_sync, 100, 0, db)

# # ==================== ENDPOINTS DE UTILIDAD ====================

# @app.get("/", response_model=HealthCheck)
# async def root():
#     """Endpoint raíz"""
#     return HealthCheck(
#         status="healthy",
#         timestamp=datetime.now().isoformat(),
#         environment=os.environ.get('ENVIRONMENT', 'development'),
#         database="PostgreSQL"
#     )

# @app.get("/health", response_model=HealthCheck)
# async def health_check(db: Session = Depends(get_db)):
#     """Health check completo"""
#     try:
#         # Verificar conexión a la base de datos
#         db.execute(text('SELECT 1'))
#         db_status = "connected"
        
#         # Contar registros
#         pacientes_count = db.query(Paciente).count()
#         vacunas_count = db.query(Vacuna).count()
#         usuarios_count = db.query(Usuario).count()
        
#         return HealthCheck(
#             status="healthy",
#             timestamp=datetime.now().isoformat(),
#             environment=os.environ.get('ENVIRONMENT', 'development'),
#             database=db_status,
#             metrics={
#                 "pacientes_count": pacientes_count,
#                 "vacunas_count": vacunas_count,
#                 "usuarios_count": usuarios_count
#             }
#         )
        
#     except Exception as e:
#         db_status = f"error: {str(e)}"
#         return HealthCheck(
#             status="unhealthy",
#             timestamp=datetime.now().isoformat(),
#             environment=os.environ.get('ENVIRONMENT', 'development'),
#             database=db_status,
#             metrics={
#                 "pacientes_count": 0,
#                 "vacunas_count": 0,
#                 "usuarios_count": 0
#             }
#         )

# @app.get("/api/info")
# async def get_api_info():
#     """Información detallada del API"""
#     return {
#         "name": "HealthShield API",
#         "version": "1.0.0",
#         "description": "API para gestión de pacientes y vacunas con sincronización offline",
#         "environment": os.environ.get('ENVIRONMENT', 'development'),
#         "database": "PostgreSQL",
#         "sync_endpoints": {
#             "from_client": "/api/sync/from-client",
#             "to_client": "/api/sync/to-client",
#             "full_data": "/api/sync/full-data",
#             "status": "/api/sync/status"
#         },
#         "timestamp": datetime.now().isoformat()
#     }

# @app.get("/api/stats")
# async def get_stats(db: Session = Depends(get_db)):
#     """Estadísticas del sistema"""
#     try:
#         pacientes_count = db.query(Paciente).count()
#         vacunas_count = db.query(Vacuna).count()
#         usuarios_count = db.query(Usuario).count()
        
#         # Últimos 30 días
#         thirty_days_ago = datetime.now() - timedelta(days=30)
        
#         pacientes_recent = db.query(Paciente).filter(
#             Paciente.created_at >= thirty_days_ago
#         ).count()
        
#         vacunas_recent = db.query(Vacuna).filter(
#             Vacuna.created_at >= thirty_days_ago
#         ).count()
        
#         return {
#             "total_pacientes": pacientes_count,
#             "total_vacunas": vacunas_count,
#             "total_usuarios": usuarios_count,
#             "pacientes_ultimos_30_dias": pacientes_recent,
#             "vacunas_ultimos_30_dias": vacunas_recent,
#             "timestamp": datetime.now().isoformat()
#         }
        
#     except Exception as e:
#         logger.error(f"Error obteniendo estadísticas: {e}")
#         raise HTTPException(status_code=500, detail=f'Error obteniendo estadísticas: {str(e)}')

# if __name__ == "__main__":
#     import uvicorn
    
#     port = int(os.environ.get("PORT", 8000))
    
#     uvicorn.run(
#         app,
#         host="0.0.0.0",
#         port=port,
#         log_level="info"
#     )

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

# Configurar logging para Railway
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Solo cargar .env en desarrollo local
if os.environ.get('ENVIRONMENT') != 'production':
    load_dotenv()
    logger.info("✅ Modo desarrollo: .env cargado")
else:
    logger.info("✅ Modo producción: usando variables de Railway")

# Configuración de JWT
SECRET_KEY = os.environ.get("SECRET_KEY")
if not SECRET_KEY:
    logger.warning("⚠️  SECRET_KEY no definida, usando valor por defecto (inseguro en producción)")
    SECRET_KEY = "healthshield_secret_key_dev"

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
            return True
        
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
        
        logger.info(f"✅ Usuario admin creado exitosamente")
        return True
        
    except Exception as e:
        logger.error(f"❌ Error creando usuario admin: {e}")
        db.rollback()
        return False

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    logger.info("🚀 Iniciando HealthShield API en Railway...")
    
    # Inicializar base de datos
    db_initialized = init_db()
    
    if db_initialized:
        try:
            db = next(get_db())
            create_default_admin(db)
            logger.info("✅ Base de datos inicializada correctamente")
        except Exception as e:
            logger.error(f"⚠️  Error inicializando datos: {e}")
    else:
        logger.warning("⚠️  Base de datos no inicializada, algunos endpoints no funcionarán")
    
    logger.info("✅ HealthShield API lista para recibir peticiones")
    yield
    
    # Shutdown
    logger.info("🛑 Deteniendo HealthShield API...")

# Configurar CORS para Railway
allowed_origins_str = os.environ.get("ALLOWED_ORIGINS", "")
if allowed_origins_str:
    allowed_origins = [origin.strip() for origin in allowed_origins_str.split(",")]
else:
    # Por defecto en Railway, permitir los comunes
    allowed_origins = [
        "http://localhost:3000",
        "http://localhost:8080",
        "http://localhost",
        "https://healthshield-app.vercel.app",  # Ejemplo de frontend
    ]

logger.info(f"🌐 CORS configurado para orígenes: {allowed_origins}")

app = FastAPI(
    title="HealthShield API",
    version="1.0.0",
    description="API para gestión de pacientes y vacunas - Desplegado en Railway",
    docs_url="/docs",
    redoc_url="/redoc",
    lifespan=lifespan
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=allowed_origins,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allow_headers=["*"],
)

# ==================== ENDPOINTS DE AUTENTICACIÓN ====================

@app.post("/api/auth/register", response_model=AuthResponse, status_code=201)
async def register(usuario: UsuarioCreate, db: Session = Depends(get_db)):
    """Registrar un nuevo usuario"""
    try:
        if UsuarioRepository.get_by_username(db, usuario.username):
            raise HTTPException(status_code=400, detail="El usuario ya existe")
        
        if UsuarioRepository.get_by_email(db, usuario.email):
            raise HTTPException(status_code=400, detail="El email ya está registrado")
        
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
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error en registro: {e}")
        raise HTTPException(status_code=500, detail="Error interno del servidor")

@app.post("/api/auth/login", response_model=AuthResponse)
async def login(login_data: UserLogin, db: Session = Depends(get_db)):
    """Iniciar sesión"""
    try:
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
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error en login: {e}")
        raise HTTPException(status_code=500, detail="Error interno del servidor")

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
        logger.error(f"Error obteniendo usuarios: {e}")
        raise HTTPException(status_code=500, detail="Error interno del servidor")

@app.post("/api/users/change-password", response_model=MessageResponse)
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
        logger.error(f"Error cambiando contraseña: {e}")
        raise HTTPException(status_code=500, detail="Error interno del servidor")

# ==================== ENDPOINTS DE PACIENTES ====================

@app.post("/api/pacientes", response_model=MessageResponse, status_code=201)
async def add_paciente(paciente: PacienteCreate, db: Session = Depends(get_db)):
    """Agregar un nuevo paciente"""
    try:
        if PacienteRepository.get_by_cedula(db, paciente.cedula):
            raise HTTPException(status_code=400, detail="La cédula ya está registrada")
        
        db_paciente = PacienteRepository.create(db, paciente)
        return MessageResponse(
            message='Paciente agregado correctamente',
            id=db_paciente.id,
            local_id=paciente.local_id
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error agregando paciente: {e}")
        raise HTTPException(status_code=500, detail="Error interno del servidor")

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
        logger.error(f"Error obteniendo pacientes: {e}")
        raise HTTPException(status_code=500, detail="Error interno del servidor")

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
        logger.error(f"Error obteniendo paciente: {e}")
        raise HTTPException(status_code=500, detail="Error interno del servidor")

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
        logger.error(f"Error agregando vacuna: {e}")
        raise HTTPException(status_code=500, detail="Error interno del servidor")

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
        logger.error(f"Error obteniendo vacunas del paciente: {e}")
        raise HTTPException(status_code=500, detail="Error interno del servidor")

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
        logger.error(f"Error obteniendo todas las vacunas: {e}")
        raise HTTPException(status_code=500, detail="Error interno del servidor")

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
        logger.error(f"Error en sincronización masiva: {e}")
        raise HTTPException(status_code=500, detail=f'Error en sincronización masiva: {str(e)}')

@app.get("/api/sync/updates", response_model=SyncResponse)
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
        logger.error(f"Error obteniendo actualizaciones: {e}")
        raise HTTPException(status_code=500, detail="Error interno del servidor")

# ==================== ENDPOINTS DE UTILIDAD PARA RAILWAY ====================

@app.get("/", response_model=HealthCheck)
async def root():
    """Endpoint raíz - Información de Railway"""
    return HealthCheck(
        status="healthy",
        timestamp=datetime.now().isoformat(),
        environment=os.environ.get('ENVIRONMENT', 'unknown'),
        database="PostgreSQL (Railway)" if os.environ.get('DATABASE_URL') else "Not connected",
        metrics={
            "railway_service": os.environ.get('RAILWAY_SERVICE_NAME', 'unknown'),
            "railway_environment": os.environ.get('RAILWAY_ENVIRONMENT', 'unknown'),
            "service_url": os.environ.get('RAILWAY_STATIC_URL', 'unknown')
        }
    )

@app.get("/health", response_model=HealthCheck)
async def health_check(db: Session = Depends(get_db)):
    """Health check para Railway"""
    try:
        # Verificar conexión a la base de datos
        db.execute('SELECT 1')
        db_status = "connected"
        
        # Contar registros
        pacientes_count = db.query(Paciente).count()
        vacunas_count = db.query(Vacuna).count()
        usuarios_count = db.query(Usuario).count()
        
        logger.info(f"Health check OK - DB: {db_status}, Pacientes: {pacientes_count}")
        
    except Exception as e:
        db_status = f"error: {str(e)[:100]}"
        pacientes_count = 0
        vacunas_count = 0
        usuarios_count = 0
        logger.warning(f"Health check con problemas: {e}")
    
    return HealthCheck(
        status="healthy" if "connected" in db_status else "degraded",
        timestamp=datetime.now().isoformat(),
        environment=os.environ.get('ENVIRONMENT', 'development'),
        database=db_status,
        metrics={
            "pacientes_count": pacientes_count,
            "vacunas_count": vacunas_count,
            "usuarios_count": usuarios_count,
            "railway_runtime": os.environ.get('RAILWAY_RUNWAY_VERSION', 'unknown'),
            "deployment_id": os.environ.get('RAILWAY_DEPLOYMENT_ID', 'unknown')
        }
    )

@app.get("/api/db-status")
async def db_status():
    """Verificar estado de la conexión a PostgreSQL"""
    try:
        from database import engine
        
        if engine is None:
            return {
                "status": "not_initialized", 
                "message": "Engine no inicializado",
                "railway_info": {
                    "service_id": os.environ.get('RAILWAY_SERVICE_ID'),
                    "environment": os.environ.get('RAILWAY_ENVIRONMENT')
                }
            }
        
        with engine.connect() as conn:
            result = conn.execute("""
                SELECT 
                    current_database() as database,
                    version() as version,
                    current_user as user,
                    inet_server_addr() as host,
                    inet_server_port() as port
            """)
            db_info = result.fetchone()
            
            # Obtener estadísticas
            result = conn.execute("""
                SELECT count(*) as total_tables 
                FROM information_schema.tables 
                WHERE table_schema = 'public'
            """)
            tables_count = result.scalar()
            
            # Contar registros en nuestras tablas
            result = conn.execute("""
                SELECT 
                    (SELECT COUNT(*) FROM usuarios) as usuarios,
                    (SELECT COUNT(*) FROM pacientes) as pacientes,
                    (SELECT COUNT(*) FROM vacunas) as vacunas
            """)
            counts = result.fetchone()
            
        return {
            "status": "connected",
            "database": {
                "name": db_info.database,
                "version": db_info.version.split(',')[0],
                "user": db_info.user,
                "host": db_info.host,
                "port": db_info.port,
                "tables_count": tables_count,
                "records": {
                    "usuarios": counts.usuarios,
                    "pacientes": counts.pacientes,
                    "vacunas": counts.vacunas
                }
            },
            "railway": {
                "service_id": os.environ.get('RAILWAY_SERVICE_ID'),
                "service_name": os.environ.get('RAILWAY_SERVICE_NAME'),
                "environment": os.environ.get('RAILWAY_ENVIRONMENT'),
                "deployment_id": os.environ.get('RAILWAY_DEPLOYMENT_ID'),
                "static_url": os.environ.get('RAILWAY_STATIC_URL')
            },
            "timestamp": datetime.now().isoformat()
        }
        
    except Exception as e:
        return {
            "status": "error",
            "message": str(e),
            "database_url_preview": os.environ.get('DATABASE_URL', 'not_found')[:50] + "..." if os.environ.get('DATABASE_URL') else 'not_found',
            "railway_variables": {
                k: v[:50] + "..." if v and len(v) > 50 else v
                for k, v in os.environ.items() 
                if 'RAILWAY' in k or 'DATABASE' in k
            },
            "timestamp": datetime.now().isoformat()
        }

@app.get("/api/railway-info")
async def railway_info():
    """Información específica de Railway"""
    railway_vars = {
        k: v for k, v in os.environ.items() 
        if 'RAILWAY' in k or 'DATABASE' in k or 'ENVIRONMENT' in k or 'PORT' in k
    }
    
    # Ocultar valores sensibles
    for key in railway_vars:
        if 'PASSWORD' in key or 'SECRET' in key or 'KEY' in key or 'TOKEN' in key:
            railway_vars[key] = "***HIDDEN***"
        elif 'DATABASE_URL' in key:
            # Mostrar solo partes no sensibles de la URL
            if railway_vars[key]:
                try:
                    from urllib.parse import urlparse
                    parsed = urlparse(railway_vars[key])
                    railway_vars[key] = f"{parsed.scheme}://{parsed.hostname}:{parsed.port}/{parsed.path.split('/')[-1]}"
                except:
                    railway_vars[key] = "***HIDDEN***"
    
    return {
        "service": {
            "name": os.environ.get('RAILWAY_SERVICE_NAME'),
            "id": os.environ.get('RAILWAY_SERVICE_ID'),
            "environment": os.environ.get('RAILWAY_ENVIRONMENT'),
            "deployment_id": os.environ.get('RAILWAY_DEPLOYMENT_ID')
        },
        "runtime": {
            "python_version": os.sys.version,
            "environment": os.environ.get('ENVIRONMENT'),
            "port": os.environ.get('PORT'),
            "workers": os.environ.get('WORKERS', 'auto')
        },
        "database": {
            "connected": "DATABASE_URL" in os.environ,
            "type": "PostgreSQL",
            "provider": "Railway"
        },
        "endpoints": {
            "api_docs": "/docs",
            "health_check": "/health",
            "db_status": "/api/db-status",
            "auth_register": "/api/auth/register",
            "auth_login": "/api/auth/login"
        },
        "variables": railway_vars,
        "timestamp": datetime.now().isoformat()
    }

# ==================== ENDPOINTS DE PRUEBA ====================

@app.get("/api/test/db")
async def test_db():
    """Endpoint de prueba para verificar conexión a DB"""
    try:
        from database import engine
        if engine is None:
            return {"status": "error", "message": "Engine no inicializado"}
        
        with engine.connect() as conn:
            # Ejecutar una consulta simple
            result = conn.execute("SELECT NOW() as server_time, VERSION() as db_version")
            row = result.fetchone()
            
            return {
                "status": "success",
                "message": "Conexión a PostgreSQL exitosa",
                "data": {
                    "server_time": str(row.server_time),
                    "db_version": row.db_version.split(',')[0]
                }
            }
    except Exception as e:
        return {
            "status": "error",
            "message": str(e),
            "available_vars": {
                k: "***" if any(s in k.lower() for s in ['pass', 'secret', 'key']) else v[:50] + "..." if v else None
                for k, v in os.environ.items()
                if any(keyword in k.lower() for keyword in ['database', 'postgres', 'railway', 'env'])
            }
        }

@app.get("/api/test/echo")
async def test_echo(message: str = "Hello Railway!"):
    """Endpoint de prueba simple"""
    return {
        "message": message,
        "timestamp": datetime.now().isoformat(),
        "environment": os.environ.get('ENVIRONMENT', 'unknown'),
        "service": os.environ.get('RAILWAY_SERVICE_NAME', 'unknown')
    }

if __name__ == "__main__":
    import uvicorn
    
    port = int(os.environ.get("PORT", 8000))
    
    uvicorn.run(
        app,
        host="0.0.0.0",
        port=port,
        log_level="info"
    )