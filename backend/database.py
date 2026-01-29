# import os
# from sqlalchemy import create_engine, text
# from sqlalchemy.orm import sessionmaker, declarative_base
# from dotenv import load_dotenv
# import bcrypt

# load_dotenv()

# Base = declarative_base()

# def get_database_url():
#     """Obtener URL de PostgreSQL"""
#     db_host = os.environ.get('DB_HOST', 'postgres')
#     db_port = os.environ.get('DB_PORT', '5432')
#     db_name = os.environ.get('DB_NAME', 'healthshield')
#     db_user = os.environ.get('DB_USER', 'healthshield_user')
#     db_pass = os.environ.get('DB_PASSWORD', 'healthshield_password')
    
#     url = f"postgresql://{db_user}:{db_pass}@{db_host}:{db_port}/{db_name}"
#     print(f"🔗 Conectando a PostgreSQL: {url.replace(db_pass, '***')}")
#     return url

# # Crear engine
# try:
#     database_url = get_database_url()
#     engine = create_engine(
#         database_url,
#         echo=True,
#         pool_pre_ping=True,
#         pool_recycle=300,
#         pool_size=5,
#         max_overflow=10,
#         connect_args={
#             "connect_timeout": 10,
#         }
#     )
    
#     # Probar conexión
#     with engine.connect() as conn:
#         result = conn.execute(text("SELECT 1"))
#         print(f"✅ PostgreSQL conectado: {result.fetchone()}")
        
# except Exception as e:
#     print(f"❌ Error conectando a PostgreSQL: {e}")
#     raise

# SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# def get_db():
#     """Dependencia para obtener sesión de base de datos"""
#     db = SessionLocal()
#     try:
#         yield db
#     finally:
#         db.close()

# def hash_password(password: str) -> str:
#     """Hash password usando bcrypt"""
#     password_bytes = password.encode('utf-8')
#     if len(password_bytes) > 72:
#         password_bytes = password_bytes[:72]
#     salt = bcrypt.gensalt()
#     hashed = bcrypt.hashpw(password_bytes, salt)
#     return hashed.decode('utf-8')

# def verify_password(plain_password: str, hashed_password: str) -> bool:
#     """Verificar password usando bcrypt"""
#     try:
#         plain_bytes = plain_password.encode('utf-8')
#         if len(plain_bytes) > 72:
#             plain_bytes = plain_bytes[:72]
#         hashed_bytes = hashed_password.encode('utf-8')
#         return bcrypt.checkpw(plain_bytes, hashed_bytes)
#     except Exception:
#         return False

# def init_db():
#     """Inicializar tablas en PostgreSQL"""
#     from models import Usuario, Paciente, Vacuna
#     try:
#         Base.metadata.create_all(bind=engine)
#         print("✅ Tablas creadas en PostgreSQL")
#     except Exception as e:
#         print(f"❌ Error inicializando tablas: {e}")
#         raise


import os
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, declarative_base
from dotenv import load_dotenv
import bcrypt
import time
import logging

# Configurar logging
logger = logging.getLogger(__name__)

Base = declarative_base()

def get_database_url():
    """
    Obtener URL de PostgreSQL para Railway.
    Railway automáticamente inyecta DATABASE_URL.
    """
    # Railway siempre inyecta DATABASE_URL cuando se conecta a PostgreSQL
    database_url = os.environ.get('DATABASE_URL')
    
    if not database_url:
        logger.error("❌ DATABASE_URL no encontrada en variables de entorno")
        logger.info("ℹ️  Variables disponibles: " + ", ".join([k for k in os.environ.keys() if 'DATABASE' in k or 'POSTGRES' in k]))
        
        # Para Railway, si no hay DATABASE_URL, algo está mal configurado
        raise ValueError(
            "DATABASE_URL no encontrada. "
            "En Railway, asegúrate de conectar el servicio PostgreSQL a tu API "
            "o define las variables de conexión manualmente."
        )
    
    logger.info(f"✅ DATABASE_URL encontrada: {database_url[:50]}...")
    
    # Railway usa postgres://, SQLAlchemy necesita postgresql://
    if database_url.startswith("postgres://"):
        database_url = database_url.replace("postgres://", "postgresql://", 1)
        logger.info("✅ URL convertida a formato postgresql://")
    
    return database_url

def create_engine_with_retry(max_retries=10, initial_wait=3):
    """Crear engine con reintentos para Railway"""
    wait_time = initial_wait
    
    for attempt in range(max_retries):
        try:
            database_url = get_database_url()
            
            logger.info(f"🔄 Intento {attempt + 1}/{max_retries} de conexión a PostgreSQL...")
            
            engine = create_engine(
                database_url,
                echo=False,  # Desactivar en producción
                pool_pre_ping=True,
                pool_recycle=300,
                pool_size=5,
                max_overflow=10,
                connect_args={
                    "connect_timeout": 10,
                    "keepalives": 1,
                    "keepalives_idle": 30,
                    "sslmode": "require" if "railway.app" in database_url else "prefer"
                }
            )
            
            # Test connection
            with engine.connect() as conn:
                result = conn.execute("SELECT version()")
                version = result.scalar()
                logger.info(f"✅ PostgreSQL conectado: {version.split(',')[0]}")
            
            return engine
            
        except Exception as e:
            logger.warning(f"⚠️  Error en intento {attempt + 1}: {str(e)[:100]}...")
            if attempt < max_retries - 1:
                logger.info(f"⏳ Esperando {wait_time}s antes de reintentar...")
                time.sleep(wait_time)
                wait_time = min(wait_time * 1.5, 30)  # Backoff exponencial, max 30s
            else:
                logger.error(f"❌ Error conectando a PostgreSQL después de {max_retries} intentos")
                logger.error("💡 Soluciones posibles:")
                logger.error("1. Verifica que el servicio PostgreSQL esté 'Running' en Railway")
                logger.error("2. En el servicio API, ve a 'Variables' y verifica DATABASE_URL")
                logger.error("3. En el servicio PostgreSQL, haz clic en 'Connect' → 'API Service'")
                raise

# Inicializar engine
try:
    engine = create_engine_with_retry()
    SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    logger.info("✅ SQLAlchemy engine y SessionLocal configurados")
except Exception as e:
    logger.critical(f"❌ No se pudo inicializar la base de datos: {e}")
    # Crear engine dummy para desarrollo sin DB
    engine = None
    SessionLocal = None

def get_db():
    """Dependencia para obtener sesión de base de datos"""
    if SessionLocal is None:
        raise RuntimeError("Base de datos no inicializada. Verifica la conexión a PostgreSQL.")
    
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
    
    if engine is None:
        logger.error("❌ Engine no disponible, no se pueden crear tablas")
        return False
    
    try:
        Base.metadata.create_all(bind=engine)
        logger.info("✅ Tablas de PostgreSQL creadas/verificadas")
        return True
    except Exception as e:
        logger.error(f"❌ Error inicializando base de datos: {e}")
        return False