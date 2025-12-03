import os
import sys
from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker, declarative_base
from dotenv import load_dotenv
import bcrypt
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

load_dotenv()

Base = declarative_base()

def get_database_url():
    """Obtener y preparar URL de base de datos para Render"""
    database_url = os.environ.get('DATABASE_URL')
    
    if not database_url:
        logger.error("❌ DATABASE_URL no encontrada en variables de entorno")
        raise ValueError("DATABASE_URL no configurada")
    
    # Convertir postgres:// a postgresql:// para SQLAlchemy
    if database_url.startswith("postgres://"):
        database_url = database_url.replace("postgres://", "postgresql://", 1)
    
    logger.info(f"✅ Usando DATABASE_URL de Render")
    return database_url

def ensure_database_exists():
    """Asegurarse de que la base de datos y tablas existan"""
    try:
        # Obtener URL base sin nombre de base de datos
        original_url = get_database_url()
        
        # Conectar a PostgreSQL sin especificar DB (a 'postgres')
        if '/healthshield' in original_url:
            base_url = original_url.rsplit('/', 1)[0] + '/postgres'
        else:
            base_url = original_url
        
        temp_engine = create_engine(base_url, isolation_level="AUTOCOMMIT")
        
        with temp_engine.connect() as conn:
            # Verificar si la base de datos 'healthshield' existe
            result = conn.execute(
                text("SELECT 1 FROM pg_database WHERE datname = 'healthshield'")
            )
            db_exists = result.scalar() is not None
            
            if not db_exists:
                logger.info("🛠️  Creando base de datos 'healthshield'...")
                conn.execute(text("CREATE DATABASE healthshield"))
                logger.info("✅ Base de datos 'healthshield' creada")
            else:
                logger.info("✅ Base de datos 'healthshield' ya existe")
        
        temp_engine.dispose()
        
    except Exception as e:
        logger.warning(f"⚠️  No se pudo verificar/crear DB: {e}")
        logger.info("ℹ️  Continuando con conexión normal...")

# Crear engine principal
engine = create_engine(
    get_database_url(),
    echo=False,
    pool_pre_ping=True,
    pool_recycle=300,
    pool_size=10,
    max_overflow=20,
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
    salt = bcrypt.gensalt()
    hashed = bcrypt.hashpw(password_bytes, salt)
    return hashed.decode('utf-8')

def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verificar password usando bcrypt"""
    try:
        plain_bytes = plain_password.encode('utf-8')
        hashed_bytes = hashed_password.encode('utf-8')
        return bcrypt.checkpw(plain_bytes, hashed_bytes)
    except Exception:
        return False

def init_db():
    """Inicializar base de datos - Crear tablas si no existen"""
    try:
        # 1. Asegurar que la base de datos existe
        ensure_database_exists()
        
        # 2. Importar modelos para que SQLAlchemy los detecte
        from models import Usuario, Paciente, Vacuna
        
        # 3. Crear todas las tablas
        logger.info("🛠️  Creando tablas en la base de datos...")
        Base.metadata.create_all(bind=engine)
        
        logger.info("✅ Tablas creadas exitosamente:")
        logger.info("   - usuarios")
        logger.info("   - pacientes") 
        logger.info("   - vacunas")
        
    except Exception as e:
        logger.error(f"❌ Error inicializando base de datos: {e}")
        raise