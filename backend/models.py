from sqlalchemy import Column, Integer, String, Boolean, DateTime, ForeignKey, Text
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from database import Base
from pydantic import BaseModel, EmailStr, field_validator, ConfigDict
from typing import Optional, List, Dict, Any
from datetime import datetime
import re

# ==================== SQLALCHEMY MODELS ====================

class Usuario(Base):
    __tablename__ = 'usuarios'
    
    id = Column(Integer, primary_key=True, index=True)
    server_id = Column(Integer, nullable=True, index=True)
    username = Column(String(50), unique=True, index=True, nullable=False)
    email = Column(String(100), unique=True, index=True, nullable=False)
    password = Column(String(255), nullable=False)
    telefono = Column(String(20))
    is_professional = Column(Boolean, default=False)
    professional_license = Column(String(50))
    is_verified = Column(Boolean, default=False)
    role = Column(String(20), default='user')
    is_synced = Column(Boolean, default=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    
    vacunas = relationship("Vacuna", back_populates="usuario")

class Paciente(Base):
    __tablename__ = 'pacientes'
    
    id = Column(Integer, primary_key=True, index=True)
    server_id = Column(Integer, nullable=True, index=True)
    cedula = Column(String(20), unique=True, index=True, nullable=False)
    nombre = Column(String(100), nullable=False)
    fecha_nacimiento = Column(String(10), nullable=False)
    telefono = Column(String(20))
    direccion = Column(Text)
    is_synced = Column(Boolean, default=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    
    # 🔥 IMPORTANTE: ELIMINAR esta relación completamente
    # vacunas = relationship("Vacuna", back_populates="paciente")  # ← COMENTAR O ELIMINAR

class Vacuna(Base):
    __tablename__ = 'vacunas'
    
    id = Column(Integer, primary_key=True, index=True)
    server_id = Column(Integer, nullable=True, index=True)
    
    # 🔥 paciente_id es solo un número, NO ForeignKey
    paciente_id = Column(Integer, nullable=True)
    
    paciente_server_id = Column(Integer, nullable=True)
    nombre_vacuna = Column(String(100), nullable=False)
    fecha_aplicacion = Column(String(10), nullable=False)
    lote = Column(String(50))
    proxima_dosis = Column(String(10))
    usuario_id = Column(Integer, ForeignKey('usuarios.id'))
    is_synced = Column(Boolean, default=False)
    
    es_menor = Column(Boolean, default=False)
    cedula_tutor = Column(String(20))
    cedula_propia = Column(String(20))
    nombre_paciente = Column(String(100))
    cedula_paciente = Column(String(20))
    
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    
    # 🔥 IMPORTANTE: ELIMINAR esta relación
    # paciente = relationship("Paciente", back_populates="vacunas")  # ← COMENTAR O ELIMINAR
    usuario = relationship("Usuario", back_populates="vacunas")

# ==================== PYDANTIC SCHEMAS ====================

class UsuarioBase(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    
    username: str
    email: EmailStr
    telefono: Optional[str] = None
    is_professional: bool = False
    professional_license: Optional[str] = None
    role: str = 'user'
    
    @field_validator('username')
    @classmethod
    def validate_username(cls, v):
        if len(v) < 3:
            raise ValueError('El nombre de usuario debe tener al menos 3 caracteres')
        if len(v) > 50:
            raise ValueError('El nombre de usuario no puede tener más de 50 caracteres')
        if not re.match(r'^[a-zA-Z0-9_]+$', v):
            raise ValueError('El nombre de usuario solo puede contener letras, números y guiones bajos')
        return v
    
    @field_validator('telefono')
    @classmethod
    def validate_telefono(cls, v):
        if v and not re.match(r'^\+?[\d\s\-\(\)]{7,}$', v):
            raise ValueError('Formato de teléfono inválido')
        return v
    
    @field_validator('role')
    @classmethod
    def validate_role(cls, v):
        allowed_roles = ['admin', 'professional', 'user']
        if v not in allowed_roles:
            raise ValueError(f'El rol debe ser uno de: {", ".join(allowed_roles)}')
        return v

class UsuarioCreate(UsuarioBase):
    password: str
    local_id: Optional[int] = None  # Para sincronización
    
    @field_validator('password')
    @classmethod
    def validate_password(cls, v):
        if len(v) < 6:
            raise ValueError('La contraseña debe tener al menos 6 caracteres')
        return v

class UsuarioUpdate(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    
    telefono: Optional[str] = None
    is_professional: Optional[bool] = None
    professional_license: Optional[str] = None
    role: Optional[str] = None
    is_synced: Optional[bool] = None

class UsuarioResponse(UsuarioBase):
    model_config = ConfigDict(from_attributes=True)
    
    id: int
    server_id: Optional[int] = None
    is_verified: bool
    is_synced: bool = True
    created_at: datetime
    updated_at: Optional[datetime] = None

class PacienteBase(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    
    cedula: str
    nombre: str
    fecha_nacimiento: str
    telefono: Optional[str] = None
    direccion: Optional[str] = None
    
    @field_validator('cedula')
    @classmethod
    def validate_cedula(cls, v):
        if not v or len(v) < 3:
            raise ValueError('La cédula debe tener al menos 3 caracteres')
        return v
    
    @field_validator('nombre')
    @classmethod
    def validate_nombre(cls, v):
        if len(v) < 2:
            raise ValueError('El nombre debe tener al menos 2 caracteres')
        if len(v) > 100:
            raise ValueError('El nombre no puede tener más de 100 caracteres')
        return v
    
    @field_validator('fecha_nacimiento')
    @classmethod
    def validate_fecha_nacimiento(cls, v):
        # Validar formato YYYY-MM-DD
        if not re.match(r'^\d{4}-\d{2}-\d{2}$', v):
            raise ValueError('La fecha debe estar en formato YYYY-MM-DD')
        return v

class PacienteCreate(PacienteBase):
    local_id: Optional[int] = None  # Para sincronización
    server_id: Optional[int] = None

class PacienteUpdate(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    
    cedula: Optional[str] = None
    nombre: Optional[str] = None
    fecha_nacimiento: Optional[str] = None
    telefono: Optional[str] = None
    direccion: Optional[str] = None
    is_synced: Optional[bool] = None
    server_id: Optional[int] = None

class PacienteResponse(PacienteBase):
    model_config = ConfigDict(from_attributes=True)
    
    id: int
    server_id: Optional[int] = None
    is_synced: bool
    created_at: Optional[str] = None
    updated_at: Optional[str] = None

class VacunaBase(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    
    paciente_id: Optional[int] = None 
    paciente_server_id: Optional[int] = None
    nombre_vacuna: str 
    fecha_aplicacion: str
    lote: Optional[str] = None
    proxima_dosis: Optional[str] = None
    usuario_id: Optional[int] = None
    
    es_menor: bool = False
    cedula_tutor: Optional[str] = None
    cedula_propia: Optional[str] = None
    nombre_paciente: Optional[str] = None
    cedula_paciente: Optional[str] = None
    
    @field_validator('nombre_vacuna')
    @classmethod
    def validate_nombre_vacuna(cls, v):
        if len(v) < 2:
            raise ValueError('El nombre de la vacuna debe tener al menos 2 caracteres')
        return v
    
    @field_validator('fecha_aplicacion', 'proxima_dosis')
    @classmethod
    def validate_fecha(cls, v):
        if v and not re.match(r'^\d{4}-\d{2}-\d{2}$', v):
            raise ValueError('La fecha debe estar en formato YYYY-MM-DD')
        return v

class VacunaCreate(VacunaBase):
    local_id: Optional[int] = None  # Para sincronización
    server_id: Optional[int] = None

class VacunaUpdate(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    
    nombre_vacuna: Optional[str] = None
    fecha_aplicacion: Optional[str] = None
    lote: Optional[str] = None
    proxima_dosis: Optional[str] = None
    es_menor: Optional[bool] = None
    cedula_tutor: Optional[str] = None
    cedula_propia: Optional[str] = None
    is_synced: Optional[bool] = None
    server_id: Optional[int] = None

class VacunaResponse(VacunaBase):
    model_config = ConfigDict(from_attributes=True)
    
    id: int
    server_id: Optional[int] = None
    is_synced: bool
    created_at: Optional[str] = None
    updated_at: Optional[str] = None

class UserLogin(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    
    username: str
    password: str

class AuthResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    
    message: str
    user: UsuarioResponse
    token: Optional[str] = None

class MessageResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    
    message: str
    id: Optional[int] = None
    server_id: Optional[int] = None  # Cambiar local_id por server_id
    local_id: Optional[int] = None   # Mantener para compatibilidad

class HealthCheck(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    
    status: str
    timestamp: str
    environment: Optional[str] = None
    database: Optional[str] = None
    metrics: Optional[dict] = None

# ==================== SCHEMAS DE SINCRONIZACIÓN ====================

class BulkSyncData(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    
    pacientes: List[PacienteCreate] = []
    vacunas: List[VacunaCreate] = []
    last_sync_client: Optional[str] = None

class BulkSyncResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    
    message: str
    pacientes_sincronizados: int
    vacunas_sincronizadas: int
    pacientes_ids: Dict[str, Any]
    vacunas_ids: Dict[str, Any]
    conflicts: Optional[List[Dict[str, Any]]] = None
    server_timestamp: str

class ClientSyncData(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    
    last_sync: str
    limit: Optional[int] = 100
    offset: Optional[int] = 0

class ClientSyncResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    
    message: str
    last_sync_server: str
    pacientes: List[Dict[str, Any]] = []
    vacunas: List[Dict[str, Any]] = []
    total_pacientes: int = 0
    total_vacunas: int = 0
    has_more: bool = False

class FullDataResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    
    message: str
    server_timestamp: str
    pacientes: List[Dict[str, Any]] = []
    vacunas: List[Dict[str, Any]] = []
    total_pacientes: int = 0
    total_vacunas: int = 0

class SyncStatus(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    
    status: str
    last_sync: Optional[str] = None
    pending_changes: int = 0
    server_available: bool = True
    server_counts: Optional[Dict[str, int]] = None
    error: Optional[str] = None

class ConflictResolution(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    
    conflict_id: str
    resolution: str
    data: Optional[Dict[str, Any]] = None

# Alias para compatibilidad
SyncResponse = BulkSyncResponse

# ==================== SCHEMAS ESPECIALES PARA FLUTTER ====================

class VacunaForSync(BaseModel):
    """Esquema especial para sincronización desde Flutter"""
    model_config = ConfigDict(from_attributes=True)
    
    id: Optional[int] = None
    server_id: Optional[int] = None
    paciente_id: Optional[int] = None
    paciente_server_id: Optional[int] = None
    nombre_vacuna: str
    fecha_aplicacion: str
    lote: Optional[str] = None
    proxima_dosis: Optional[str] = None
    usuario_id: Optional[int] = None
    is_synced: bool = False
    
    # Nuevos campos
    es_menor: bool = False
    cedula_tutor: Optional[str] = None
    cedula_propia: Optional[str] = None
    nombre_paciente: Optional[str] = None
    cedula_paciente: Optional[str] = None
    
    local_id: Optional[int] = None

class PacienteForSync(BaseModel):
    """Esquema especial para sincronización desde Flutter"""
    model_config = ConfigDict(from_attributes=True)
    
    id: Optional[int] = None
    server_id: Optional[int] = None
    cedula: str
    nombre: str
    fecha_nacimiento: str
    telefono: Optional[str] = None
    direccion: Optional[str] = None
    is_synced: bool = False
    
    local_id: Optional[int] = None