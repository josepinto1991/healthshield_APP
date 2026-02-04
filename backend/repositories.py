from sqlalchemy.orm import Session
from sqlalchemy import or_
from models import Usuario, Paciente, Vacuna
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
    def get_by_server_id(db: Session, server_id: int) -> Optional[Usuario]:
        return db.query(Usuario).filter(Usuario.server_id == server_id).first()
    
    @staticmethod
    def get_all(db: Session, skip: int = 0, limit: int = 100) -> List[Usuario]:
        return db.query(Usuario).offset(skip).limit(limit).all()
    
    @staticmethod
    def create(db: Session, usuario_data) -> Usuario:
        hashed_password = hash_password(usuario_data.password)
        
        # Buscar por server_id si existe
        existing_user = None
        if hasattr(usuario_data, 'server_id') and usuario_data.server_id:
            existing_user = UsuarioRepository.get_by_server_id(db, usuario_data.server_id)
        
        if existing_user:
            # Actualizar usuario existente
            existing_user.username = usuario_data.username
            existing_user.email = usuario_data.email
            existing_user.password = hashed_password
            existing_user.telefono = usuario_data.telefono
            existing_user.is_professional = usuario_data.is_professional
            existing_user.professional_license = usuario_data.professional_license
            existing_user.role = getattr(usuario_data, 'role', 'user')
            existing_user.is_synced = True
            db.commit()
            db.refresh(existing_user)
            return existing_user
        else:
            # Crear nuevo usuario
            db_usuario = Usuario(
                server_id=getattr(usuario_data, 'server_id', None),
                username=usuario_data.username,
                email=usuario_data.email,
                password=hashed_password,
                telefono=usuario_data.telefono,
                is_professional=usuario_data.is_professional,
                professional_license=usuario_data.professional_license,
                role=getattr(usuario_data, 'role', 'user'),
                is_synced=True  # Cuando se crea desde el servidor, está sincronizado
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
    
    @staticmethod
    def update(db: Session, user_id: int, update_data: Dict[str, Any]) -> Optional[Usuario]:
        usuario = UsuarioRepository.get_by_id(db, user_id)
        if not usuario:
            return None
        
        for key, value in update_data.items():
            if value is not None and hasattr(usuario, key):
                setattr(usuario, key, value)
        
        db.commit()
        db.refresh(usuario)
        return usuario

class PacienteRepository:
    @staticmethod
    def get_by_id(db: Session, paciente_id: int) -> Optional[Paciente]:
        return db.query(Paciente).filter(Paciente.id == paciente_id).first()
    
    @staticmethod
    def get_by_server_id(db: Session, server_id: int) -> Optional[Paciente]:
        return db.query(Paciente).filter(Paciente.server_id == server_id).first()
    
    @staticmethod
    def get_by_cedula(db: Session, cedula: str) -> Optional[Paciente]:
        return db.query(Paciente).filter(Paciente.cedula == cedula).first()
    
    @staticmethod
    def get_all(db: Session, skip: int = 0, limit: int = 100) -> List[Paciente]:
        return db.query(Paciente).offset(skip).limit(limit).all()
    
    @staticmethod
    def create(db: Session, paciente_data) -> Paciente:
        # Buscar por server_id si existe
        existing_paciente = None
        if hasattr(paciente_data, 'server_id') and paciente_data.server_id:
            existing_paciente = PacienteRepository.get_by_server_id(db, paciente_data.server_id)
        
        if existing_paciente:
            # Actualizar paciente existente
            existing_paciente.cedula = paciente_data.cedula
            existing_paciente.nombre = paciente_data.nombre
            existing_paciente.fecha_nacimiento = paciente_data.fecha_nacimiento
            existing_paciente.telefono = paciente_data.telefono
            existing_paciente.direccion = paciente_data.direccion
            existing_paciente.is_synced = True
            db.commit()
            db.refresh(existing_paciente)
            return existing_paciente
        else:
            # Crear nuevo paciente
            db_paciente = Paciente(
                server_id=getattr(paciente_data, 'server_id', None),
                cedula=paciente_data.cedula,
                nombre=paciente_data.nombre,
                fecha_nacimiento=paciente_data.fecha_nacimiento,
                telefono=paciente_data.telefono,
                direccion=paciente_data.direccion,
                is_synced=True  # Cuando se crea desde el servidor, está sincronizado
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
    def get_by_server_id(db: Session, server_id: int) -> Optional[Vacuna]:
        return db.query(Vacuna).filter(Vacuna.server_id == server_id).first()
    
    @staticmethod
    def get_by_paciente(db: Session, paciente_id: int) -> List[Vacuna]:
        return db.query(Vacuna).filter(Vacuna.paciente_id == paciente_id).all()
    
    @staticmethod
    def get_all(db: Session, skip: int = 0, limit: int = 100) -> List[Vacuna]:
        return db.query(Vacuna).offset(skip).limit(limit).all()
    
    @staticmethod
    def create(db: Session, vacuna_data) -> Vacuna:
        from repositories import PacienteRepository
        
        # Verificar que el paciente existe
        paciente_id = vacuna_data.paciente_id
        paciente = PacienteRepository.get_by_id(db, paciente_id)
        
        if not paciente:
            # Intentar buscar por server_id si existe paciente_server_id
            if hasattr(vacuna_data, 'paciente_server_id') and vacuna_data.paciente_server_id:
                paciente = PacienteRepository.get_by_server_id(db, vacuna_data.paciente_server_id)
                if paciente:
                    paciente_id = paciente.id
        
        if not paciente:
            raise ValueError("Paciente no encontrado")
        
        # Buscar por server_id si existe
        existing_vacuna = None
        if hasattr(vacuna_data, 'server_id') and vacuna_data.server_id:
            existing_vacuna = VacunaRepository.get_by_server_id(db, vacuna_data.server_id)
        
        if existing_vacuna:
            # Actualizar vacuna existente
            existing_vacuna.paciente_id = paciente_id
            existing_vacuna.paciente_server_id = getattr(vacuna_data, 'paciente_server_id', None)
            existing_vacuna.nombre_vacuna = vacuna_data.nombre_vacuna
            existing_vacuna.fecha_aplicacion = vacuna_data.fecha_aplicacion
            existing_vacuna.lote = vacuna_data.lote
            existing_vacuna.proxima_dosis = vacuna_data.proxima_dosis
            existing_vacuna.usuario_id = vacuna_data.usuario_id
            existing_vacuna.es_menor = getattr(vacuna_data, 'es_menor', False)
            existing_vacuna.cedula_tutor = getattr(vacuna_data, 'cedula_tutor', None)
            existing_vacuna.cedula_propia = getattr(vacuna_data, 'cedula_propia', None)
            existing_vacuna.nombre_paciente = getattr(vacuna_data, 'nombre_paciente', None)
            existing_vacuna.cedula_paciente = getattr(vacuna_data, 'cedula_paciente', None)
            existing_vacuna.is_synced = True
            db.commit()
            db.refresh(existing_vacuna)
            return existing_vacuna
        else:
            # Crear nueva vacuna
            db_vacuna = Vacuna(
                server_id=getattr(vacuna_data, 'server_id', None),
                paciente_id=paciente_id,
                paciente_server_id=getattr(vacuna_data, 'paciente_server_id', None),
                nombre_vacuna=vacuna_data.nombre_vacuna,
                fecha_aplicacion=vacuna_data.fecha_aplicacion,
                lote=vacuna_data.lote,
                proxima_dosis=vacuna_data.proxima_dosis,
                usuario_id=vacuna_data.usuario_id,
                es_menor=getattr(vacuna_data, 'es_menor', False),
                cedula_tutor=getattr(vacuna_data, 'cedula_tutor', None),
                cedula_propia=getattr(vacuna_data, 'cedula_propia', None),
                nombre_paciente=getattr(vacuna_data, 'nombre_paciente', None),
                cedula_paciente=getattr(vacuna_data, 'cedula_paciente', None),
                is_synced=True  # Cuando se crea desde el servidor, está sincronizado
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