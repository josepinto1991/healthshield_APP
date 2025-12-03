import os
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, declarative_base
from dotenv import load_dotenv
import bcrypt

load_dotenv()

Base = declarative_base()

def get_database_url():
    """Obtener URL de conexión a PostgreSQL desde Railway"""
    # Railway automáticamente inyecta DATABASE_URL
    database_url = os.environ.get('DATABASE_URL')
    
    if not database_url:
        raise ValueError("❌ DATABASE_URL no está configurada en Railway")
    
    # Railway usa postgresql://, pero aseguramos formato correcto
    if database_url.startswith("postgres://"):
        database_url = database_url.replace("postgres://", "postgresql://", 1)
    
    print(f"✅ Usando PostgreSQL desde Railway: {database_url.split('@')[1] if '@' in database_url else database_url}")
    return database_url

# Crear engine optimizado para PostgreSQL
engine = create_engine(
    get_database_url(),
    echo=os.environ.get('ENVIRONMENT') == 'development',  # Solo logs en desarrollo
    pool_pre_ping=True,     # Verificar conexión antes de usar
    pool_recycle=300,       # Reciclar conexiones cada 5 minutos
    pool_size=10,           # Tamaño máximo del pool
    max_overflow=20,        # Conexiones adicionales permitidas
    connect_args={
        "connect_timeout": 10,  # Timeout de conexión de 10 segundos
        "keepalives": 1,
        "keepalives_idle": 30,
        "keepalives_interval": 10,
        "keepalives_count": 5,
    }
)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

def get_db():
    """Dependencia para obtener sesión de base de datos"""
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
    """Inicializar tablas en PostgreSQL"""
    from models import Usuario, Paciente, Vacuna
    try:
        Base.metadata.create_all(bind=engine)
        print("✅ Tablas de PostgreSQL creadas/verificadas")
    except Exception as e:
        print(f"❌ Error inicializando base de datos: {e}")
        raise