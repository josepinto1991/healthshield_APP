import os
from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker, declarative_base
from sqlalchemy.pool import NullPool
from sqlalchemy.exc import OperationalError
import logging
import time
import bcrypt

# Configurar logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

Base = declarative_base()

# ==================== CONEXIÓN NEON POSTGRESQL ====================

def get_neon_database_url():
    """
    Obtener URL de conexión para Neon PostgreSQL.
    """
    # 1. DATABASE_URL (Vercel Marketplace la inyecta automáticamente)
    database_url = os.environ.get('DATABASE_URL')
    if database_url:
        logger.info("✅ Usando DATABASE_URL de Vercel/Neon")
        # Asegurar formato postgresql://
        if database_url.startswith('postgres://'):
            database_url = database_url.replace('postgres://', 'postgresql://', 1)
        return database_url
    
    # 2. NEON_DATABASE_URL
    database_url = os.environ.get('NEON_DATABASE_URL')
    if database_url:
        logger.info("✅ Usando NEON_DATABASE_URL")
        if database_url.startswith('postgres://'):
            database_url = database_url.replace('postgres://', 'postgresql://', 1)
        return database_url
    
    # 3. POSTGRES_URL (para compatibilidad)
    database_url = os.environ.get('POSTGRES_URL')
    if database_url:
        logger.info("✅ Usando POSTGRES_URL")
        if database_url.startswith('postgres://'):
            database_url = database_url.replace('postgres://', 'postgresql://', 1)
        return database_url
    
    # 4. Variables individuales
    pg_host = os.environ.get('PGHOST')
    pg_user = os.environ.get('PGUSER')
    pg_password = os.environ.get('PGPASSWORD')
    pg_database = os.environ.get('PGDATABASE')
    
    if all([pg_host, pg_user, pg_password, pg_database]):
        database_url = f"postgresql://{pg_user}:{pg_password}@{pg_host}/{pg_database}"
        logger.info("🔗 URL construida desde variables individuales")
        return database_url
    
    # 5. Error - no hay configuración
    logger.error("""
    ❌ ERROR: No se encontró configuración de base de datos
    
    🔧 SOLUCIÓN RÁPIDA:
    1. Para desarrollo local, crea un archivo .env con:
       DATABASE_URL=postgresql://user:pass@localhost:5432/healthshield
    
    2. Para Vercel, conecta Neon:
       - Ve a Vercel Dashboard → Storage
       - Busca 'Neon' en Marketplace
       - Haz clic en 'Create'
       - Vercel inyectará DATABASE_URL automáticamente
    """)
    
    return None

def create_neon_engine():
    """Crear engine SQLAlchemy para Neon PostgreSQL - CORREGIDO"""
    try:
        database_url = get_neon_database_url()
        
        if not database_url:
            logger.error("❌ No se pudo obtener URL de base de datos")
            return None
        
        logger.info("🔗 Conectando a Neon PostgreSQL...")
        
        # Asegurar parámetros de conexión SSL
        if '?' not in database_url:
            database_url += '?sslmode=require'
        elif 'sslmode=' not in database_url:
            database_url += '&sslmode=require'
        
        # Configuración optimizada para Neon (serverless)
        # ¡IMPORTANTE! NullPool no acepta pool_timeout, max_overflow, pool_use_lifo
        engine = create_engine(
            database_url,
            echo=False,  # Cambiar a True para debug en desarrollo
            poolclass=NullPool,  # IMPORTANTE para serverless
            pool_pre_ping=True,
            pool_recycle=300,
            connect_args={
                "connect_timeout": 15,
                "keepalives": 1,
                "keepalives_idle": 30,
                "keepalives_interval": 10,
                "keepalives_count": 5,
                "application_name": "healthshield-api",
            }
        )
        
        # Test de conexión
        logger.info("🔄 Probando conexión a PostgreSQL...")
        with engine.connect() as conn:
            result = conn.execute(text("""
                SELECT 
                    version() as version,
                    current_database() as database,
                    current_user as username,
                    now() as server_time
            """))
            db_info = result.fetchone()
            
            logger.info(f"""
            ✅ CONEXIÓN EXITOSA:
               Database: {db_info.database}
               Username: {db_info.username}
               Versión: {db_info.version.split(',')[0]}
               Hora Servidor: {db_info.server_time}
            """)
        
        return engine
        
    except OperationalError as e:
        error_msg = str(e)
        logger.error(f"❌ Error de conexión a PostgreSQL: {error_msg}")
        
        # Diagnóstico específico
        if "password authentication failed" in error_msg.lower():
            logger.error("🔑 ERROR: Credenciales incorrectas")
        elif "could not translate host name" in error_msg.lower():
            logger.error("🌐 ERROR: Host no encontrado")
        elif "timeout" in error_msg.lower():
            logger.error("⏱️  ERROR: Timeout de conexión")
        elif "SSL" in error_msg:
            logger.error("🔐 ERROR: Problema con SSL")
        
        return None
        
    except Exception as e:
        logger.error(f"❌ Error inesperado: {e}")
        import traceback
        logger.error(traceback.format_exc())
        return None

# ==================== INICIALIZACIÓN GLOBAL ====================

# Mensaje de inicio
logger.info("="*70)
logger.info("🚀 HEALTHSHIELD API")
logger.info("="*70)

# Información del entorno
env_info = {
    'Entorno': os.environ.get('ENVIRONMENT', 'development'),
    'Vercel': os.environ.get('VERCEL', 'No'),
    'Región': os.environ.get('VERCEL_REGION', 'local'),
}

for key, value in env_info.items():
    logger.info(f"📊 {key}: {value}")

# Verificar variables de base de datos
db_vars_to_check = ['DATABASE_URL', 'NEON_DATABASE_URL', 'POSTGRES_URL', 'PGHOST']
found_db_vars = []

for var in db_vars_to_check:
    value = os.environ.get(var)
    if value:
        found_db_vars.append(var)
        # Mostrar de forma segura
        if var.endswith('_URL') and '@' in value:
            parts = value.split('@')
            if len(parts) == 2:
                user_part = parts[0]
                if '://' in user_part:
                    protocol = user_part.split('://')[0]
                    credentials = user_part.split('://')[1]
                    if ':' in credentials:
                        user = credentials.split(':')[0]
                        logger.info(f"🔗 {var}: {protocol}://{user}:***@{parts[1].split('?')[0][:40]}...")

if found_db_vars:
    logger.info(f"✅ Variables DB encontradas: {', '.join(found_db_vars)}")
else:
    logger.warning("⚠️  No se encontraron variables de base de datos")

logger.info("="*70)

# Crear engine global
engine = create_neon_engine()

if engine:
    SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    logger.info("✅ SQLAlchemy configurado exitosamente")
else:
    SessionLocal = None
    logger.warning("⚠️  La aplicación iniciará SIN base de datos")
    logger.info("💡 Los endpoints que requieran DB mostrarán un error apropiado")

# ==================== FUNCIONES PÚBLICAS ====================

def get_db():
    """
    Dependencia FastAPI para obtener sesión de base de datos.
    """
    if SessionLocal is None:
        raise RuntimeError(
            "🚫 Base de datos no disponible\n\n"
            "🔧 CONFIGURACIÓN REQUERIDA:\n"
            "1. Para desarrollo local, crea un archivo .env con:\n"
            "   DATABASE_URL=postgresql://user:pass@localhost:5432/healthshield\n\n"
            "2. Para Vercel, conecta Neon:\n"
            "   - Ve a Vercel Dashboard → Storage\n"
            "   - Busca 'Neon' en Marketplace\n"
            "   - Haz clic en 'Create'\n"
            "   - Vercel inyectará DATABASE_URL automáticamente\n"
        )
    
    db = SessionLocal()
    try:
        yield db
    except Exception as e:
        logger.error(f"❌ Error en sesión DB: {e}")
        db.rollback()
        raise
    finally:
        db.close()

def hash_password(password: str) -> str:
    """Hashear contraseña usando bcrypt"""
    try:
        password_bytes = password.encode('utf-8')
        # bcrypt solo soporta hasta 72 bytes
        if len(password_bytes) > 72:
            password_bytes = password_bytes[:72]
            logger.warning("⚠️  Contraseña truncada a 72 caracteres para bcrypt")
        
        salt = bcrypt.gensalt(rounds=12)
        hashed = bcrypt.hashpw(password_bytes, salt)
        return hashed.decode('utf-8')
    except Exception as e:
        logger.error(f"❌ Error hasheando contraseña: {e}")
        raise

def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verificar contraseña con hash bcrypt"""
    try:
        plain_bytes = plain_password.encode('utf-8')
        if len(plain_bytes) > 72:
            plain_bytes = plain_bytes[:72]
        
        hashed_bytes = hashed_password.encode('utf-8')
        return bcrypt.checkpw(plain_bytes, hashed_bytes)
    except Exception:
        logger.warning("⚠️  Error verificando contraseña")
        return False

def init_db():
    """Inicializar todas las tablas en la base de datos"""
    if engine is None:
        logger.error("❌ No se puede inicializar DB: engine no disponible")
        return False
    
    try:
        # Importar aquí para evitar dependencias circulares
        from models import Usuario, Paciente, Vacuna
        
        logger.info("🔄 Inicializando base de datos...")
        
        # Crear todas las tablas definidas en los modelos
        Base.metadata.create_all(bind=engine)
        
        logger.info("✅ Tablas creadas exitosamente")
        
        # Verificar tablas creadas
        with engine.connect() as conn:
            result = conn.execute(text("""
                SELECT table_name, table_type
                FROM information_schema.tables 
                WHERE table_schema = 'public'
                ORDER BY table_name
            """))
            tables = result.fetchall()
            
            if tables:
                logger.info("📊 Tablas en la base de datos:")
                for table_name, table_type in tables:
                    logger.info(f"   • {table_name} ({table_type})")
            else:
                logger.warning("⚠️  No se encontraron tablas")
        
        return True
        
    except Exception as e:
        logger.error(f"❌ Error inicializando base de datos: {e}")
        import traceback
        logger.error("Detalles del error:")
        logger.error(traceback.format_exc())
        return False

# ==================== EJECUCIÓN DIRECTA ====================

if __name__ == "__main__":
    print("\n" + "="*70)
    print("🔍 DIAGNÓSTICO BASE DE DATOS")
    print("="*70)
    
    # Mostrar configuración
    config_summary = {
        'ENTORNO': os.environ.get('ENVIRONMENT', 'development'),
        'VERCEL': os.environ.get('VERCEL', 'No'),
        'DATABASE_URL': 'PRESENTE' if os.environ.get('DATABASE_URL') else 'AUSENTE',
        'NEON_DATABASE_URL': 'PRESENTE' if os.environ.get('NEON_DATABASE_URL') else 'AUSENTE',
    }
    
    for key, value in config_summary.items():
        print(f"{key}: {value}")
    
    # Probar conexión si hay engine
    if engine:
        try:
            with engine.connect() as conn:
                result = conn.execute(text("SELECT version(), current_database(), now()"))
                info = result.fetchone()
                print(f"\n✅ Conexión exitosa:")
                print(f"   Database: {info[1]}")
                print(f"   Version: {info[0].split(',')[0]}")
                print(f"   Server Time: {info[2]}")
        except Exception as e:
            print(f"\n❌ Error de conexión: {e}")
    else:
        print("\n❌ No hay conexión a base de datos")
        print("💡 Ejecuta estos pasos:")
        print("   1. Crea un archivo .env con:")
        print("      DATABASE_URL=postgresql://user:pass@localhost:5432/dbname")
        print("   2. O usa una URL de Neon PostgreSQL")
    
    print("="*70)