import os
import sqlite3
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, declarative_base
from sqlalchemy.pool import StaticPool
from dotenv import load_dotenv
import bcrypt

load_dotenv()

Base = declarative_base()

def get_database_url():
    environment = os.environ.get('ENVIRONMENT', 'development')
    
    if environment == 'production':
        # OPCIÓN 1: Usar DATABASE_URL de Render (automático)
        database_url = os.environ.get('DATABASE_URL')
        
        if database_url:
            # Convertir postgres:// a postgresql:// para SQLAlchemy
            if database_url.startswith("postgres://"):
                database_url = database_url.replace("postgres://", "postgresql://", 1)
            print(f"✅ Usando DATABASE_URL de variable de entorno")
            return database_url
        
        # OPCIÓN 2: Usar variables individuales (backup)
        print(f"⚠️  DATABASE_URL no encontrada, usando variables individuales")
        return f"postgresql://{os.environ.get('DB_USER', 'healthshield_user')}:{os.environ.get('DB_PASSWORD', 'healthshield_password')}@{os.environ.get('DB_HOST', 'localhost')}:{os.environ.get('DB_PORT', '5432')}/{os.environ.get('DB_NAME', 'healthshield')}"
    else:
        return "sqlite:///./healthshield.db"

# Crear engine con configuración de producción
engine = create_engine(
    get_database_url(),
    echo=False,  # Desactivar logs SQL en producción
    pool_pre_ping=True,    # Verificar conexión antes de usar
    pool_recycle=300,      # Reciclar conexiones cada 5 minutos
    pool_size=10,          # Tamaño máximo del pool
    max_overflow=20,       # Conexiones adicionales permitidas
)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

def hash_password(password: str) -> str:
    """Hash password usando bcrypt"""
    password_bytes = password.encode('utf-8')
    if len(password_bytes) > 72:
        password_bytes = password_bytes[:72]
    salt = bcrypt.gensalt()
    hashed = bcrypt.hashpw(password_bytes, salt)
    return hashed.decode('utf-8')

def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verificar password usando bcrypt"""
    try:
        plain_bytes = plain_password.encode('utf-8')
        if len(plain_bytes) > 72:
            plain_bytes = plain_bytes[:72]
        hashed_bytes = hashed_password.encode('utf-8')
        return bcrypt.checkpw(plain_bytes, hashed_bytes)
    except Exception:
        return False

def init_db():
    from models import Usuario, Paciente, Vacuna
    Base.metadata.create_all(bind=engine)
    print("✅ Base de datos inicializada")