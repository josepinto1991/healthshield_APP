import os
from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker, declarative_base
from dotenv import load_dotenv
import bcrypt

load_dotenv()

Base = declarative_base()

def get_database_url():
    """Obtener URL de PostgreSQL"""
    db_host = os.environ.get('DB_HOST', 'postgres')
    db_port = os.environ.get('DB_PORT', '5432')
    db_name = os.environ.get('DB_NAME', 'healthshield')
    db_user = os.environ.get('DB_USER', 'healthshield_user')
    db_pass = os.environ.get('DB_PASSWORD', 'healthshield_password')
    
    url = f"postgresql://{db_user}:{db_pass}@{db_host}:{db_port}/{db_name}"
    print(f"🔗 Conectando a PostgreSQL: {url.replace(db_pass, '***')}")
    return url

# Crear engine
try:
    database_url = get_database_url()
    engine = create_engine(
        database_url,
        echo=True,
        pool_pre_ping=True,
        pool_recycle=300,
        pool_size=5,
        max_overflow=10,
        connect_args={
            "connect_timeout": 10,
        }
    )
    
    # Probar conexión
    with engine.connect() as conn:
        result = conn.execute(text("SELECT 1"))
        print(f"✅ PostgreSQL conectado: {result.fetchone()}")
        
except Exception as e:
    print(f"❌ Error conectando a PostgreSQL: {e}")
    raise

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
        print("✅ Tablas creadas en PostgreSQL")
    except Exception as e:
        print(f"❌ Error inicializando tablas: {e}")
        raise