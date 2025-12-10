from sqlalchemy.orm import Session
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
    def get_all(db: Session, skip: int = 0, limit: int = 100) -> List[Paciente]:
        return db.query(Paciente).offset(skip).limit(limit).all()
    
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
    def update(db: Session, paciente_id: int, paciente_update: Dict[str, Any]) -> Optional[Paciente]:
        paciente = PacienteRepository.get_by_id(db, paciente_id)
        if not paciente:
            return None
        
        for key, value in paciente_update.items():
            if value is not None and hasattr(paciente, key):
                setattr(paciente, key, value)
        
        db.commit()
        db.refresh(paciente)
        return paciente

class VacunaRepository:
    @staticmethod
    def get_by_id(db: Session, vacuna_id: int) -> Optional[Vacuna]:
        return db.query(Vacuna).filter(Vacuna.id == vacuna_id).first()
    
    @staticmethod
    def get_by_paciente(db: Session, paciente_id: int) -> List[Vacuna]:
        return db.query(Vacuna).filter(Vacuna.paciente_id == paciente_id).all()
    
    @staticmethod
    def get_all(db: Session, skip: int = 0, limit: int = 100) -> List[Vacuna]:
        return db.query(Vacuna).offset(skip).limit(limit).all()
    
    @staticmethod
    def create(db: Session, vacuna: VacunaCreate) -> Vacuna:
        from repositories import PacienteRepository
        
        paciente = PacienteRepository.get_by_id(db, vacuna.paciente_id)
        if not paciente:
            raise ValueError("Paciente no encontrado")
        
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
    def update(db: Session, vacuna_id: int, vacuna_update: Dict[str, Any]) -> Optional[Vacuna]:
        vacuna = VacunaRepository.get_by_id(db, vacuna_id)
        if not vacuna:
            return None
        
        for key, value in vacuna_update.items():
            if value is not None and hasattr(vacuna, key):
                setattr(vacuna, key, value)
        
        db.commit()
        db.refresh(vacuna)
        return vacuna