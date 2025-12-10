from sqlalchemy import Column, Integer, String, Boolean, DateTime, ForeignKey, Text
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from database import Base
from pydantic import BaseModel, EmailStr
from typing import Optional, List, Dict, Any
from datetime import datetime

# ==================== SQLALCHEMY MODELS ====================

class Usuario(Base):
    __tablename__ = 'usuarios'
    
    id = Column(Integer, primary_key=True, index=True)
    username = Column(String(50), unique=True, index=True, nullable=False)
    email = Column(String(100), unique=True, index=True, nullable=False)
    password = Column(String(255), nullable=False)
    telefono = Column(String(20))
    is_professional = Column(Boolean, default=False)
    professional_license = Column(String(50))
    is_verified = Column(Boolean, default=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    
    vacunas = relationship("Vacuna", back_populates="usuario")

class Paciente(Base):
    __tablename__ = 'pacientes'
    
    id = Column(Integer, primary_key=True, index=True)
    cedula = Column(String(20), unique=True, index=True, nullable=False)
    nombre = Column(String(100), nullable=False)
    fecha_nacimiento = Column(String(10), nullable=False)
    telefono = Column(String(20))
    direccion = Column(Text)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    
    vacunas = relationship("Vacuna", back_populates="paciente")

class Vacuna(Base):
    __tablename__ = 'vacunas'
    
    id = Column(Integer, primary_key=True, index=True)
    paciente_id = Column(Integer, ForeignKey('pacientes.id'), nullable=False)
    nombre_vacuna = Column(String(100), nullable=False)
    fecha_aplicacion = Column(String(10), nullable=False)
    lote = Column(String(50))
    proxima_dosis = Column(String(10))
    usuario_id = Column(Integer, ForeignKey('usuarios.id'))
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    
    paciente = relationship("Paciente", back_populates="vacunas")
    usuario = relationship("Usuario", back_populates="vacunas")

# ==================== PYDANTIC SCHEMAS ====================

class UsuarioBase(BaseModel):
    username: str
    email: EmailStr
    telefono: Optional[str] = None
    is_professional: bool = False
    professional_license: Optional[str] = None

class UsuarioCreate(UsuarioBase):
    password: str

class UsuarioUpdate(BaseModel):
    telefono: Optional[str] = None
    is_professional: Optional[bool] = None
    professional_license: Optional[str] = None

class UsuarioResponse(UsuarioBase):
    id: int
    is_verified: bool
    created_at: datetime
    updated_at: Optional[datetime] = None
    
    class Config:
        from_attributes = True

class PacienteBase(BaseModel):
    cedula: str
    nombre: str
    fecha_nacimiento: str
    telefono: Optional[str] = None
    direccion: Optional[str] = None

class PacienteCreate(PacienteBase):
    local_id: Optional[int] = None

class PacienteUpdate(BaseModel):
    cedula: Optional[str] = None
    nombre: Optional[str] = None
    fecha_nacimiento: Optional[str] = None
    telefono: Optional[str] = None
    direccion: Optional[str] = None

class PacienteResponse(PacienteBase):
    id: int
    created_at: Optional[str] = None
    updated_at: Optional[str] = None
    
    class Config:
        from_attributes = True

class VacunaBase(BaseModel):
    paciente_id: int
    nombre_vacuna: str
    fecha_aplicacion: str
    lote: Optional[str] = None
    proxima_dosis: Optional[str] = None
    usuario_id: Optional[int] = None

class VacunaCreate(VacunaBase):
    local_id: Optional[int] = None

class VacunaUpdate(BaseModel):
    nombre_vacuna: Optional[str] = None
    fecha_aplicacion: Optional[str] = None
    lote: Optional[str] = None
    proxima_dosis: Optional[str] = None

class VacunaResponse(VacunaBase):
    id: int
    created_at: Optional[str] = None
    paciente_nombre: Optional[str] = None
    usuario_nombre: Optional[str] = None
    
    class Config:
        from_attributes = True

class UserLogin(BaseModel):
    username: str
    password: str

class AuthResponse(BaseModel):
    message: str
    user: UsuarioResponse
    token: Optional[str] = None

class MessageResponse(BaseModel):
    message: str
    id: Optional[int] = None
    local_id: Optional[int] = None

class HealthCheck(BaseModel):
    status: str
    timestamp: str
    environment: Optional[str] = None
    database: Optional[str] = None
    metrics: Optional[dict] = None

# ==================== SCHEMAS DE SINCRONIZACIÓN ====================

class BulkSyncData(BaseModel):
    pacientes: List[PacienteCreate] = []
    vacunas: List[VacunaCreate] = []
    last_sync_client: Optional[str] = None

class BulkSyncResponse(BaseModel):
    message: str
    pacientes_sincronizados: int
    vacunas_sincronizadas: int
    pacientes_ids: Dict[str, Any]
    vacunas_ids: Dict[str, Any]
    conflicts: Optional[List[Dict[str, Any]]] = None
    server_timestamp: str

class ClientSyncData(BaseModel):
    last_sync: str
    limit: Optional[int] = 100
    offset: Optional[int] = 0

class ClientSyncResponse(BaseModel):
    message: str
    last_sync_server: str
    pacientes: List[Dict[str, Any]] = []
    vacunas: List[Dict[str, Any]] = []
    total_pacientes: int = 0
    total_vacunas: int = 0
    has_more: bool = False

class FullDataResponse(BaseModel):
    message: str
    server_timestamp: str
    pacientes: List[Dict[str, Any]] = []
    vacunas: List[Dict[str, Any]] = []
    total_pacientes: int = 0
    total_vacunas: int = 0

class SyncStatus(BaseModel):
    status: str
    last_sync: Optional[str] = None
    pending_changes: int = 0
    server_available: bool = True
    server_counts: Optional[Dict[str, int]] = None
    error: Optional[str] = None

class ConflictResolution(BaseModel):
    conflict_id: str
    resolution: str
    data: Optional[Dict[str, Any]] = None

SyncResponse = BulkSyncResponse