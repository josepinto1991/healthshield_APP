import os
from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker, declarative_base
from sqlalchemy.pool import NullPool
from sqlalchemy.exc import OperationalError
import logging
import time
import bcrypt

# ==================== CONFIGURACIÓN ====================

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
    Vercel inyecta automáticamente estas variables.
    """
    # Prioridad de variables (Vercel Marketplace las inyecta)
    url_sources = [
        ('DATABASE_URL', 'DATABASE_URL de Vercel/Neon'),
        ('NEON_DATABASE_URL', 'NEON_DATABASE_URL'),
        ('POSTGRES_URL', 'POSTGRES_URL'),
    ]
    
    for var_name, description in url_sources:
        database_url = os.environ.get(var_name)
        if database_url:
            logger.info(f"✅ Usando {description}")
            # Asegurar formato postgresql://
            if database_url.startswith('postgres://'):
                database_url = database_url.replace('postgres://', 'postgresql://', 1)
            return database_url
    
    # Variables individuales (fallback)
    pg_host = os.environ.get('PGHOST')
    pg_user = os.environ.get('PGUSER')
    pg_password = os.environ.get('PGPASSWORD')
    pg_database = os.environ.get('PGDATABASE')
    
    if all([pg_host, pg_user, pg_password, pg_database]):
        database_url = f"postgresql://{pg_user}:{pg_password}@{pg_host}/{pg_database}"
        logger.info("🔗 URL construida desde variables individuales")
        return database_url
    
    # No hay configuración
    logger.error("""
    ❌ ERROR: No se encontró configuración de base de datos
    
    🔧 SOLUCIÓN RÁPIDA:
    1. Ve a Vercel Dashboard → Storage
    2. Busca 'Neon' en 'Marketplace Database Providers'
    3. Haz clic en 'Create'
    4. Sigue los pasos (crea cuenta si es necesario)
    5. Vercel inyectará automáticamente DATABASE_URL
    6. Reinicia el deployment
    
    💡 Neon ofrece 10GB gratis - perfecto para esta aplicación
    """)
    
    return None

def create_neon_engine():
    """Crear engine SQLAlchemy para Neon PostgreSQL"""
    try:
        database_url = get_neon_database_url()
        
        if not database_url:
            logger.error("❌ No se pudo obtener URL de base de datos")
            return None
        
        logger.info("🔗 Configurando conexión a Neon PostgreSQL...")
        
        # Asegurar parámetros de conexión SSL
        if '?' not in database_url:
            database_url += '?sslmode=require'
        elif 'sslmode=' not in database_url:
            database_url += '&sslmode=require'
        
        # Añadir parámetros de optimización para Neon
        if 'options=' not in database_url:
            database_url += '&options=-c%20statement_timeout%3D30000'
        
        # Configuración optimizada para Vercel + Neon (serverless)
        engine = create_engine(
            database_url,
            echo=False,  # Cambiar a True para debug en desarrollo
            poolclass=NullPool,  # CRÍTICO para serverless
            pool_pre_ping=True,
            pool_recycle=300,
            connect_args={
                "connect_timeout": 15,
                "keepalives": 1,
                "keepalives_idle": 30,
                "keepalives_interval": 10,
                "keepalives_count": 5,
                "application_name": "healthshield-api-vercel",
            },
            # Configuración adicional para serverless
            pool_timeout=30,
            max_overflow=0,
            pool_use_lifo=True
        )
        
        # Verificar conexión
        logger.info("🔄 Probando conexión a Neon PostgreSQL...")
        with engine.connect() as conn:
            result = conn.execute(text("""
                SELECT 
                    version() as version,
                    current_database() as database,
                    current_user as username,
                    inet_server_addr() as host,
                    pg_database_size(current_database()) as size_bytes,
                    now() as server_time
            """))
            db_info = result.fetchone()
            
            # Calcular tamaño en MB
            size_mb = db_info.size_bytes / (1024 * 1024)
            
            logger.info(f"""
            ✅ CONEXIÓN EXITOSA A NEON POSTGRESQL:
               Database: {db_info.database}
               Username: {db_info.username}
               Host: {db_info.host}
               Versión: {db_info.version.split(',')[0]}
               Tamaño DB: {size_mb:.2f} MB
               Hora Servidor: {db_info.server_time}
            """)
        
        return engine
        
    except OperationalError as e:
        error_msg = str(e)
        logger.error(f"❌ Error de conexión a Neon: {error_msg}")
        
        # Diagnóstico detallado
        if "password authentication failed" in error_msg.lower():
            logger.error("🔑 ERROR: Credenciales incorrectas")
            logger.info("💡 Verifica que DATABASE_URL tenga usuario/contraseña correctos")
        elif "could not translate host name" in error_msg.lower():
            logger.error("🌐 ERROR: Host no encontrado")
            logger.info("💡 El host de Neon podría estar incorrecto")
        elif "timeout" in error_msg.lower():
            logger.error("⏱️  ERROR: Timeout de conexión")
            logger.info("💡 Neon podría estar en una región diferente")
        elif "SSL" in error_msg:
            logger.error("🔐 ERROR: Problema con SSL")
            logger.info("💡 Asegúrate de que la URL tenga '?sslmode=require'")
        
        return None
        
    except Exception as e:
        logger.error(f"❌ Error inesperado: {e}")
        import traceback
        logger.error(traceback.format_exc())
        return None

# ==================== INICIALIZACIÓN GLOBAL ====================

# Mensaje de inicio
logger.info("="*70)
logger.info("🚀 HEALTHSHIELD API - NEON POSTGRESQL EN VERCEL")
logger.info("="*70)

# Información del entorno
env_info = {
    'Entorno': os.environ.get('ENVIRONMENT', 'development'),
    'Vercel': os.environ.get('VERCEL', 'No'),
    'Región Vercel': os.environ.get('VERCEL_REGION', 'desconocida'),
    'Git Commit': os.environ.get('VERCEL_GIT_COMMIT_SHA', 'local')[:7] if os.environ.get('VERCEL_GIT_COMMIT_SHA') else 'local'
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
    Uso: @app.get("/endpoint", dependencies=[Depends(get_db)])
    """
    if SessionLocal is None:
        raise RuntimeError(
            "🚫 Base de datos no disponible\n\n"
            "📋 CONFIGURACIÓN REQUERIDA PARA VERCEL:\n"
            "1. Ve a Vercel Dashboard → Storage\n"
            "2. En 'Marketplace Database Providers', busca 'Neon'\n"
            "3. Haz clic en 'Create'\n"
            "4. Sigue los pasos para crear la base de datos\n"
            "5. Vercel inyectará automáticamente DATABASE_URL\n"
            "6. Reinicia el deployment\n\n"
            "⚡ Neon es PostgreSQL serverless - 10GB gratis\n"
            "🔗 Se integrará automáticamente con tu API"
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
                    # Contar registros
                    try:
                        count_result = conn.execute(text(f"SELECT COUNT(*) FROM {table_name}"))
                        count = count_result.scalar()
                        logger.info(f"   • {table_name} ({table_type}): {count} registros")
                    except:
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

# ==================== FUNCIÓN DE DIAGNÓSTICO ====================

def check_database_health():
    """Verificar salud de la conexión a la base de datos"""
    if engine is None:
        return {
            "status": "disconnected",
            "message": "Engine no disponible",
            "timestamp": time.time()
        }
    
    try:
        with engine.connect() as conn:
            # Consulta simple para verificar conectividad
            start_time = time.time()
            result = conn.execute(text("SELECT 1 as test, now() as timestamp"))
            end_time = time.time()
            
            row = result.fetchone()
            response_time = (end_time - start_time) * 1000  # en ms
            
            # Obtener estadísticas
            result = conn.execute(text("""
                SELECT 
                    (SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public') as table_count,
                    (SELECT COUNT(*) FROM usuarios) as usuarios_count,
                    (SELECT COUNT(*) FROM pacientes) as pacientes_count,
                    (SELECT COUNT(*) FROM vacunas) as vacunas_count
            """))
            stats = result.fetchone()
            
            return {
                "status": "connected",
                "response_time_ms": round(response_time, 2),
                "server_timestamp": row.timestamp.isoformat(),
                "statistics": {
                    "table_count": stats.table_count if stats else 0,
                    "usuarios": stats.usuarios_count if stats else 0,
                    "pacientes": stats.pacientes_count if stats else 0,
                    "vacunas": stats.vacunas_count if stats else 0
                },
                "timestamp": time.time()
            }
            
    except Exception as e:
        return {
            "status": "error",
            "error": str(e),
            "timestamp": time.time()
        }

# ==================== EJECUCIÓN DIRECTA ====================

if __name__ == "__main__":
    print("\n" + "="*70)
    print("🔍 DIAGNÓSTICO NEON POSTGRESQL")
    print("="*70)
    
    # Mostrar configuración
    config_summary = {
        'VERCEL': os.environ.get('VERCEL', 'No (desarrollo local)'),
        'ENVIRONMENT': os.environ.get('ENVIRONMENT', 'development'),
        'DATABASE_URL_PRESENT': 'Sí' if os.environ.get('DATABASE_URL') else 'No',
        'NEON_DATABASE_URL_PRESENT': 'Sí' if os.environ.get('NEON_DATABASE_URL') else 'No',
    }
    
    for key, value in config_summary.items():
        print(f"{key}: {value}")
    
    # Probar conexión si hay engine
    if engine:
        health = check_database_health()
        print(f"\n📊 Estado de la base de datos: {health['status'].upper()}")
        
        if health['status'] == 'connected':
            print(f"   ⚡ Latencia: {health['response_time_ms']}ms")
            print(f"   🕐 Hora servidor: {health['server_timestamp']}")
            if 'statistics' in health:
                print(f"   📈 Tablas: {health['statistics']['table_count']}")
                print(f"   👥 Usuarios: {health['statistics']['usuarios']}")
                print(f"   👤 Pacientes: {health['statistics']['pacientes']}")
                print(f"   💉 Vacunas: {health['statistics']['vacunas']}")
    else:
        print("\n❌ No hay conexión a base de datos")
        print("💡 Ejecuta estos pasos:")
        print("   1. Ve a Vercel Dashboard → Storage")
        print("   2. Busca 'Neon' y haz clic en 'Create'")
        print("   3. Sigue los pasos para crear la DB")
        print("   4. Reinicia el deployment")
    
    print("="*70)