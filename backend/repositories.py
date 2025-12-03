from sqlalchemy.orm import Session
from sqlalchemy import and_, func
from models import Usuario, Paciente, Vacuna, UsuarioCreate, PacienteCreate, VacunaCreate
from database import hash_password, verify_password
from typing import List, Optional, Dict, Any

class UsuarioRepository:
    @staticmethod
    def get_by_username(db: Session, username: str) -> Optional[Usuario]:
        return db.query(Usuario).filter(Usuario.username == username).first()
    
    @staticmethod
    def get_by_email(db: Session, email: str) -> Optional[Usuario]:
        return db.query(Usuario).filter(Usuario.email == email).first()
    
    @staticmethod
    def get_by_id(db: Session, user_id: int) -> Optional[Usuario]:
        return db.query(Usuario).filter(Usuario.id == user_id).first()
    
    @staticmethod
    def get_all(db: Session, skip: int = 0, limit: int = 100) -> List[Usuario]:
        return db.query(Usuario).offset(skip).limit(limit).all()
    
    @staticmethod
    def create(db: Session, usuario: UsuarioCreate) -> Usuario:
        hashed_password = hash_password(usuario.password)
        db_usuario = Usuario(
            username=usuario.username,
            email=usuario.email,
            password=hashed_password,
            telefono=usuario.telefono,
            is_professional=usuario.is_professional,
            professional_license=usuario.professional_license
        )
        db.add(db_usuario)
        db.commit()
        db.refresh(db_usuario)
        return db_usuario
    
    @staticmethod
    def authenticate(db: Session, username: str, password: str) -> Optional[Usuario]:
        usuario = UsuarioRepository.get_by_username(db, username)
        if not usuario:
            return None
        if not verify_password(password, usuario.password):
            return None
        return usuario

class PacienteRepository:
    @staticmethod
    def get_by_id(db: Session, paciente_id: int) -> Optional[Paciente]:
        return db.query(Paciente).filter(Paciente.id == paciente_id).first()
    
    @staticmethod
    def get_by_cedula(db: Session, cedula: str) -> Optional[Paciente]:
        return db.query(Paciente).filter(Paciente.cedula == cedula).first()
    
    @staticmethod
    def get_all(db: Session, skip: int = 0, limit: int = 1000) -> List[Paciente]:
        return db.query(Paciente).order_by(Paciente.id.desc()).offset(skip).limit(limit).all()
    
    @staticmethod
    def get_recent(db: Session, hours: int = 24) -> List[Paciente]:
        from datetime import datetime, timedelta
        since = datetime.now() - timedelta(hours=hours)
        return db.query(Paciente).filter(Paciente.created_at >= since).all()
    
    @staticmethod
    def create(db: Session, paciente: PacienteCreate) -> Paciente:
        db_paciente = Paciente(
            cedula=paciente.cedula,
            nombre=paciente.nombre,
            fecha_nacimiento=paciente.fecha_nacimiento,
            telefono=paciente.telefono,
            direccion=paciente.direccion
        )
        db.add(db_paciente)
        db.commit()
        db.refresh(db_paciente)
        return db_paciente
    
    @staticmethod
    def create_or_update(db: Session, paciente_data: Dict[str, Any]) -> Paciente:
        """Crear o actualizar paciente basado en cédula (para sync)"""
        existing = PacienteRepository.get_by_cedula(db, paciente_data['cedula'])
        
        if existing:
            # Actualizar campos existentes
            update_fields = ['nombre', 'fecha_nacimiento', 'telefono', 'direccion']
            for field in update_fields:
                if field in paciente_data and paciente_data[field] is not None:
                    setattr(existing, field, paciente_data[field])
            
            existing.updated_at = func.now()
            existing.last_sync = func.now()
            db.commit()
            db.refresh(existing)
            return existing
        else:
            # Crear nuevo paciente
            db_paciente = Paciente(
                cedula=paciente_data['cedula'],
                nombre=paciente_data['nombre'],
                fecha_nacimiento=paciente_data['fecha_nacimiento'],
                telefono=paciente_data.get('telefono'),
                direccion=paciente_data.get('direccion')
            )
            db.add(db_paciente)
            db.commit()
            db.refresh(db_paciente)
            return db_paciente

class VacunaRepository:
    @staticmethod
    def get_by_id(db: Session, vacuna_id: int) -> Optional[Vacuna]:
        return db.query(Vacuna).filter(Vacuna.id == vacuna_id).first()
    
    @staticmethod
    def get_by_paciente(db: Session, paciente_id: int) -> List[Vacuna]:
        return db.query(Vacuna).filter(Vacuna.paciente_id == paciente_id).all()
    
    @staticmethod
    def get_all(db: Session, skip: int = 0, limit: int = 1000) -> List[Vacuna]:
        return db.query(Vacuna).order_by(Vacuna.id.desc()).offset(skip).limit(limit).all()
    
    @staticmethod
    def get_recent(db: Session, hours: int = 24) -> List[Vacuna]:
        from datetime import datetime, timedelta
        since = datetime.now() - timedelta(hours=hours)
        return db.query(Vacuna).filter(Vacuna.created_at >= since).all()
    
    @staticmethod
    def create(db: Session, vacuna: VacunaCreate) -> Vacuna:
        # Verificar que el paciente existe
        paciente = PacienteRepository.get_by_id(db, vacuna.paciente_id)
        if not paciente:
            raise ValueError(f"Paciente con ID {vacuna.paciente_id} no encontrado")
        
        db_vacuna = Vacuna(
            paciente_id=vacuna.paciente_id,
            nombre_vacuna=vacuna.nombre_vacuna,
            fecha_aplicacion=vacuna.fecha_aplicacion,
            lote=vacuna.lote,
            proxima_dosis=vacuna.proxima_dosis,
            usuario_id=vacuna.usuario_id
        )
        db.add(db_vacuna)
        db.commit()
        db.refresh(db_vacuna)
        return db_vacuna
    
    @staticmethod
    def create_with_patient_check(db: Session, vacuna_data: Dict[str, Any]) -> Vacuna:
        """Crear vacuna verificando que el paciente existe (para sync)"""
        paciente_id = vacuna_data['paciente_id']
        
        # Verificar que el paciente existe
        paciente = PacienteRepository.get_by_id(db, paciente_id)
        if not paciente:
            raise ValueError(f"Paciente con ID {paciente_id} no encontrado")
        
        db_vacuna = Vacuna(
            paciente_id=paciente_id,
            nombre_vacuna=vacuna_data['nombre_vacuna'],
            fecha_aplicacion=vacuna_data['fecha_aplicacion'],
            lote=vacuna_data.get('lote'),
            proxima_dosis=vacuna_data.get('proxima_dosis'),
            usuario_id=vacuna_data.get('usuario_id')
        )
        db.add(db_vacuna)
        db.commit()
        db.refresh(db_vacuna)
        return db_vacuna