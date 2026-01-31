import os
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, declarative_base
from dotenv import load_dotenv
import bcrypt
import time
import logging

# Configurar logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

Base = declarative_base()

# ==================== CONFIGURACIÓN RAILWAY ====================

def get_database_url():
    """
    Obtener URL de PostgreSQL para Railway.
    Railway siempre inyecta DATABASE_URL cuando conectas PostgreSQL.
    """
    # 1. PRIORIDAD: DATABASE_URL de Railway (siempre existe cuando PostgreSQL está conectado)
    database_url = os.environ.get('DATABASE_URL')
    
    if database_url:
        logger.info(f"✅ Usando DATABASE_URL de Railway (longitud: {len(database_url)})")
        
        # Railway usa postgres://, SQLAlchemy necesita postgresql://
        if database_url.startswith("postgres://"):
            database_url = database_url.replace("postgres://", "postgresql://", 1)
            logger.info("✅ URL convertida de postgres:// a postgresql://")
        
        return database_url
    
    # 2. FALLBACK: Variables individuales (para desarrollo o Railway sin conexión automática)
    logger.warning("⚠️  DATABASE_URL no encontrada, usando variables individuales")
    
    # Railway también puede inyectar estas variables
    db_host = os.environ.get('PGHOST') or os.environ.get('DB_HOST', 'localhost')
    db_port = os.environ.get('PGPORT') or os.environ.get('DB_PORT', '5432')
    db_name = os.environ.get('PGDATABASE') or os.environ.get('DB_NAME', 'railway')
    db_user = os.environ.get('PGUSER') or os.environ.get('DB_USER', 'postgres')
    db_pass = os.environ.get('PGPASSWORD') or os.environ.get('DB_PASSWORD', '')
    
    # Construir URL
    database_url = f"postgresql://{db_user}:{db_pass}@{db_host}:{db_port}/{db_name}"
    logger.info(f"🔗 URL construida: postgresql://{db_user}:***@{db_host}:{db_port}/{db_name}")
    
    return database_url

def create_engine_with_retry(max_retries=5, initial_wait=2):
    """Crear engine con reintentos para Railway"""
    wait_time = initial_wait
    
    for attempt in range(max_retries):
        try:
            database_url = get_database_url()
            
            logger.info(f"🔄 Intento {attempt + 1}/{max_retries} de conexión a PostgreSQL")
            
            # Configurar parámetros SSL para Railway
            connect_args = {
                "connect_timeout": 10,
                "keepalives": 1,
                "keepalives_idle": 30,
            }
            
            # Si es Railway (dominio railway.app), forzar SSL
            if "railway.app" in database_url or "up.railway.app" in database_url:
                connect_args["sslmode"] = "require"
                logger.info("🔐 Usando SSL para Railway")
            
            engine = create_engine(
                database_url,
                echo=False,  # Desactivar en producción
                pool_pre_ping=True,
                pool_recycle=300,
                pool_size=5,
                max_overflow=10,
                connect_args=connect_args
            )
            
            # Test connection
            with engine.connect() as conn:
                result = conn.execute("SELECT version()")
                version = result.scalar()
                logger.info(f"✅ PostgreSQL conectado: {version.split(',')[0]}")
            
            return engine
            
        except Exception as e:
            error_msg = str(e)
            logger.warning(f"⚠️  Error en intento {attempt + 1}: {error_msg[:100]}...")
            
            # Verificar si es error de autenticación
            if "password authentication failed" in error_msg:
                logger.error("❌ ERROR: Autenticación fallida")
                logger.error("💡 Verifica que DATABASE_URL sea correcta en Railway")
                logger.error("   En Railway Dashboard:")
                logger.error("   1. Ve a PostgreSQL service")
                logger.error("   2. Haz clic en 'Connect'")
                logger.error("   3. Selecciona tu API service")
            
            if attempt < max_retries - 1:
                logger.info(f"⏳ Esperando {wait_time}s antes de reintentar...")
                time.sleep(wait_time)
                wait_time = min(wait_time * 1.5, 10)  # Backoff, máximo 10s
            else:
                logger.error(f"❌ Error conectando a PostgreSQL después de {max_retries} intentos")
                # NO levantar excepción, devolver None para que la app pueda iniciar
                return None
    
    return None

# ==================== INICIALIZACIÓN GLOBAL ====================

# Diagnosticar entorno Railway antes de crear engine
logger.info(f"🔍 Entorno Railway: {os.environ.get('RAILWAY_ENVIRONMENT', 'No configurado')}")
logger.info(f"🔍 Servicio: {os.environ.get('RAILWAY_SERVICE_NAME', 'No configurado')}")

# Verificar si DATABASE_URL está presente
if os.environ.get('DATABASE_URL'):
    logger.info("✅ DATABASE_URL detectada en variables de entorno")
else:
    logger.warning("⚠️  DATABASE_URL no encontrada")
    logger.info("🔍 Buscando variables PostgreSQL de Railway...")
    pg_vars = ['PGHOST', 'PGPORT', 'PGDATABASE', 'PGUSER', 'PGPASSWORD']
    found_vars = [var for var in pg_vars if os.environ.get(var)]
    if found_vars:
        logger.info(f"✅ Variables PostgreSQL encontradas: {', '.join(found_vars)}")
    else:
        logger.warning("⚠️  No se encontraron variables de conexión a PostgreSQL")

# Crear engine
engine = create_engine_with_retry()

if engine is None:
    logger.error("❌ No se pudo crear engine de base de datos")
    logger.warning("⚠️  La aplicación iniciará SIN base de datos")
    logger.info("💡 Los endpoints que requieran DB mostrarán un error apropiado")
    SessionLocal = None
else:
    SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    logger.info("✅ SQLAlchemy configurado correctamente")

# ==================== FUNCIONES PÚBLICAS ====================

def get_db():
    """Dependencia para obtener sesión de base de datos"""
    if SessionLocal is None:
        raise RuntimeError(
            "Base de datos no disponible. "
            "Por favor, verifica la configuración de PostgreSQL en Railway: "
            "1. Conecta PostgreSQL a tu API service "
            "2. Verifica que DATABASE_URL está configurada "
            "3. Reinicia el servicio si es necesario"
        )
    
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
    if engine is None:
        logger.error("❌ No se puede inicializar DB: engine no disponible")
        return False
    
    try:
        from models import Usuario, Paciente, Vacuna
        
        logger.info("🔄 Creando tablas en PostgreSQL...")
        Base.metadata.create_all(bind=engine)
        logger.info("✅ Tablas creadas/verificadas en PostgreSQL")
        return True
        
    except Exception as e:
        logger.error(f"❌ Error inicializando base de datos: {e}")
        return False

# ==================== DIAGNÓSTICO FINAL ====================

if __name__ == "__main__":
    print("\n" + "="*60)
    print("DIAGNÓSTICO DE CONEXIÓN RAILWAY")
    print("="*60)
    
    # Mostrar información de Railway
    railway_vars = {
        'RAILWAY_ENVIRONMENT': os.environ.get('RAILWAY_ENVIRONMENT'),
        'RAILWAY_SERVICE_NAME': os.environ.get('RAILWAY_SERVICE_NAME'),
        'RAILWAY_SERVICE_ID': os.environ.get('RAILWAY_SERVICE_ID'),
        'DATABASE_URL': 'PRESENTE' if os.environ.get('DATABASE_URL') else 'AUSENTE',
    }
    
    for key, value in railway_vars.items():
        print(f"{key}: {value}")
    
    print("="*60)