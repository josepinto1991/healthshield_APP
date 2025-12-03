import os
import logging
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, declarative_base
from sqlalchemy.pool import QueuePool
from dotenv import load_dotenv
import bcrypt

# Configurar logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

load_dotenv()

Base = declarative_base()

def get_database_url():
    """
    Obtener URL de PostgreSQL para Render.
    Render inyecta DATABASE_URL automáticamente cuando conectas la DB.
    """
    # 1. Primero, DATABASE_URL de Render (automático cuando conectas DB)
    database_url = os.environ.get('DATABASE_URL')
    
    if database_url:
        logger.info("✅ Usando DATABASE_URL de Render")
        # Convertir postgres:// a postgresql:// para SQLAlchemy
        if database_url.startswith("postgres://"):
            database_url = database_url.replace("postgres://", "postgresql://", 1)
        return database_url
    
    # 2. Para desarrollo local (usar .env)
    logger.info("⚠️  No hay DATABASE_URL, usando configuración local")
    
    # Variables individuales para desarrollo
    db_config = {
        'user': os.environ.get('DB_USER', 'healthshield_user'),
        'password': os.environ.get('DB_PASSWORD', 'healthshield_password'),
        'host': os.environ.get('DB_HOST', 'localhost'),
        'port': os.environ.get('DB_PORT', '5432'),
        'name': os.environ.get('DB_NAME', 'healthshield')
    }
    
    local_url = f"postgresql://{db_config['user']}:{db_config['password']}@{db_config['host']}:{db_config['port']}/{db_config['name']}"
    logger.info(f"ℹ️  URL local: {local_url}")
    
    return local_url

# Crear engine con manejo robusto de errores
try:
    database_url = get_database_url()
    logger.info(f"🔗 Conectando a: {database_url}")
    
    # Para depuración: mostrar partes de la URL (sin contraseña)
    if '@' in database_url:
        safe_url = database_url.split('@')[1] if '@' in database_url else database_url
        logger.info(f"📡 Host de DB: {safe_url}")
    
    engine = create_engine(
        database_url,
        echo=False,  # Cambiar a True para debugging SQL
        poolclass=QueuePool,
        pool_size=5,
        max_overflow=10,
        pool_recycle=300,
        pool_pre_ping=True,
        connect_args={
            "connect_timeout": 10,
            "keepalives": 1,
            "keepalives_idle": 30,
            "keepalives_interval": 10,
        }
    )
    
    # Test de conexión
    with engine.connect() as conn:
        conn.execute("SELECT 1")
    logger.info("✅ Conexión a PostgreSQL exitosa")
    
except Exception as e:
    logger.error(f"❌ Error conectando a PostgreSQL: {e}")
    
    # Fallback temporal: SQLite en memoria (solo para emergencias)
    logger.warning("⚠️  Usando SQLite en memoria (modo emergencia)")
    engine = create_engine(
        "sqlite:///:memory:",
        echo=False,
        connect_args={"check_same_thread": False}
    )

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

def get_db():
    """Dependency para obtener sesión de DB"""
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
    """Inicializar tablas en la base de datos"""
    try:
        from models import Usuario, Paciente, Vacuna
        logger.info("🔄 Creando tablas en PostgreSQL...")
        
        Base.metadata.create_all(bind=engine)
        
        logger.info("✅ Tablas creadas exitosamente")
        
        # Verificar que las tablas existen
        with engine.connect() as conn:
            tables = conn.execute("""
                SELECT table_name 
                FROM information_schema.tables 
                WHERE table_schema = 'public'
            """).fetchall()
            
            logger.info(f"📊 Tablas en la base de datos: {[t[0] for t in tables]}")
            
    except Exception as e:
        logger.error(f"❌ Error inicializando base de datos: {e}")
        raise