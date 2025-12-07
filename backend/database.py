import os
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, declarative_base
from dotenv import load_dotenv
import bcrypt
import time

load_dotenv()

Base = declarative_base()

def get_database_url():
    """
    Obtener URL de PostgreSQL para Render.
    Render inyecta DATABASE_URL automáticamente.
    """
    # 1. Prioridad: DATABASE_URL de Render
    database_url = os.environ.get('DATABASE_URL')
    
    if database_url:
        print(f"✅ Usando DATABASE_URL de Render")
        # Render usa formato postgresql:// directamente
        if database_url.startswith("postgres://"):
            database_url = database_url.replace("postgres://", "postgresql://", 1)
        return database_url
    
    # 2. Fallback para desarrollo local
    print(f"⚠️  DATABASE_URL no encontrada, usando variables individuales")
    db_host = os.environ.get('DB_HOST', 'localhost')
    db_port = os.environ.get('DB_PORT', '5432')
    db_name = os.environ.get('DB_NAME', 'healthshield')
    db_user = os.environ.get('DB_USER', 'healthshield_user')
    db_pass = os.environ.get('DB_PASSWORD', 'healthshield_password')
    
    return f"postgresql://{db_user}:{db_pass}@{db_host}:{db_port}/{db_name}"

def create_engine_with_retry(max_retries=5, initial_wait=2):
    """Crear engine con reintentos"""
    wait_time = initial_wait
    
    for attempt in range(max_retries):
        try:
            database_url = get_database_url()
            print(f"🔗 Intentando conectar a PostgreSQL (Intento {attempt + 1}/{max_retries})...")
            
            engine = create_engine(
                database_url,
                echo=False,  # No logs en producción
                pool_pre_ping=True,
                pool_recycle=300,
                pool_size=5,
                max_overflow=10,
                connect_args={
                    "connect_timeout": 10,
                    "keepalives": 1,
                    "keepalives_idle": 30,
                }
            )
            
            # Test connection
            with engine.connect() as conn:
                conn.execute("SELECT 1")
            
            print(f"✅ Conectado a PostgreSQL exitosamente")
            return engine
            
        except Exception as e:
            if attempt < max_retries - 1:
                print(f"⚠️  Error conectando, reintentando en {wait_time}s...")
                time.sleep(wait_time)
                wait_time *= 2
            else:
                print(f"❌ Error conectando a PostgreSQL después de {max_retries} intentos")
                raise

engine = create_engine_with_retry()
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

def hash_password(password: str) -> str:
    password_bytes = password.encode('utf-8')
    if len(password_bytes) > 72:
        password_bytes = password_bytes[:72]
    salt = bcrypt.gensalt()
    hashed = bcrypt.hashpw(password_bytes, salt)
    return hashed.decode('utf-8')

def verify_password(plain_password: str, hashed_password: str) -> bool:
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
    try:
        Base.metadata.create_all(bind=engine)
        print("✅ Tablas de PostgreSQL creadas/verificadas")
    except Exception as e:
        print(f"❌ Error inicializando base de datos: {e}")
        raise