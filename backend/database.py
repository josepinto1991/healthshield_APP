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

# ==================== RAILWAY CONFIGURATION ====================

def get_database_url():
    """
    Obtener URL de PostgreSQL para Railway.
    EN RAILWAY, LA VARIABLE DATABASE_URL SE INYECTA AUTOMÁTICAMENTE.
    """
    # DEBUG: Imprimir variables relevantes
    print("🔍 BUSCANDO DATABASE_URL EN RAILWAY...")
    
    # Lista de posibles nombres de variables que Railway podría usar
    possible_db_vars = [
        'DATABASE_URL',           # Railway estándar
        'POSTGRES_URL',           # Alternativa
        'POSTGRES_CONNECTION_STRING',
        'RAILWAY_DATABASE_URL',
        'DB_URL',
        'POSTGRESQL_URL',
    ]
    
    for var_name in possible_db_vars:
        value = os.environ.get(var_name)
        if value:
            print(f"✅ ENCONTRADO: {var_name}")
            print(f"   Valor: {value[:50]}..." if len(value) > 50 else f"   Valor: {value}")
            
            # Railway usa postgres://, SQLAlchemy necesita postgresql://
            if value.startswith("postgres://"):
                value = value.replace("postgres://", "postgresql://", 1)
                print(f"   Convertido a: {value[:50]}..." if len(value) > 50 else f"   Convertido a: {value}")
            
            return value
    
    # Si no encontramos DATABASE_URL, es un error CRÍTICO en Railway
    print("❌ ERROR CRÍTICO: DATABASE_URL NO ENCONTRADA EN RAILWAY")
    print("🔍 Variables de entorno disponibles:")
    for key, val in os.environ.items():
        if 'DATABASE' in key or 'POSTGRES' in key or 'DB' in key or 'RAILWAY' in key:
            safe_val = '***HIDDEN***' if any(s in key.lower() for s in ['pass', 'secret', 'key']) else val[:80]
            print(f"   {key}: {safe_val}")
    
    # EN RAILWAY, NO USAR CREDENCIALES POR DEFECTO
    # Esto asegura que falle claramente si no está configurado
    raise RuntimeError(
        "DATABASE_URL no encontrada en Railway. "
        "Por favor, conecta el servicio PostgreSQL a tu API en Railway Dashboard: "
        "1. Ve a PostgreSQL service → 'Connect' "
        "2. Selecciona tu API service "
        "3. Railway inyectará DATABASE_URL automáticamente"
    )

def create_engine_safe():
    """
    Crear engine de forma segura para Railway.
    """
    try:
        database_url = get_database_url()
        print(f"🔗 Conectando a PostgreSQL en Railway...")
        
        # Configurar engine para Railway
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
        
        # Test de conexión
        print("🔄 Probando conexión a PostgreSQL...")
        with engine.connect() as conn:
            result = conn.execute("SELECT version()")
            version = result.scalar()
            print(f"✅ PostgreSQL conectado: {version.split(',')[0]}")
        
        return engine
        
    except Exception as e:
        print(f"❌ Error creando engine: {str(e)[:200]}")
        
        # En Railway, si no podemos conectar a la DB, creamos un engine dummy
        # para que la app pueda iniciar (los endpoints de DB fallarán)
        print("⚠️  Creando engine dummy (modo sin base de datos)")
        return None

# ==================== GLOBAL ENGINE ====================

# Intentar crear el engine
engine = create_engine_safe()

if engine is None:
    print("⚠️  ADVERTENCIA: Engine no disponible. La aplicación iniciará sin base de datos.")
    print("   Los endpoints que requieran DB mostrarán un error apropiado.")
    SessionLocal = None
else:
    SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    print("✅ SQLAlchemy configurado correctamente para Railway")

# ==================== FUNCIONES PÚBLICAS ====================

def get_db():
    """
    Dependencia para obtener sesión de base de datos.
    """
    if SessionLocal is None:
        raise RuntimeError(
            "Base de datos no disponible. "
            "Por favor, verifica la conexión a PostgreSQL en Railway: "
            "1. Conecta PostgreSQL a tu API service "
            "2. Verifica que DATABASE_URL está configurada"
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
    """
    Inicializar tablas en PostgreSQL.
    Devuelve True si éxito, False si error.
    """
    if engine is None:
        print("❌ No se puede inicializar DB: engine no disponible")
        return False
    
    try:
        from models import Usuario, Paciente, Vacuna
        
        print("🔄 Creando tablas en PostgreSQL...")
        Base.metadata.create_all(bind=engine)
        print("✅ Tablas creadas/verificadas en PostgreSQL")
        return True
        
    except Exception as e:
        print(f"❌ Error inicializando base de datos: {e}")
        return False

# ==================== DIAGNÓSTICO INICIAL ====================

if __name__ == "__main__":
    print("\n" + "="*60)
    print("DIAGNÓSTICO DE CONFIGURACIÓN RAILWAY")
    print("="*60)
    
    # Mostrar información del entorno
    print(f"Entorno: {os.environ.get('ENVIRONMENT', 'No definido')}")
    print(f"RAILWAY_SERVICE_NAME: {os.environ.get('RAILWAY_SERVICE_NAME', 'No definido')}")
    print(f"RAILWAY_ENVIRONMENT: {os.environ.get('RAILWAY_ENVIRONMENT', 'No definido')}")
    
    # Verificar DATABASE_URL
    db_url = os.environ.get('DATABASE_URL')
    if db_url:
        print(f"✅ DATABASE_URL encontrada ({len(db_url)} caracteres)")
        masked_url = db_url
        if '@' in db_url:
            # Enmascarar contraseña
            parts = db_url.split('@')
            user_pass = parts[0]
            if ':' in user_pass:
                user = user_pass.split(':')[0]
                masked_url = f"{user}:***@{parts[1]}"
        print(f"   URL: {masked_url[:80]}..." if len(masked_url) > 80 else f"   URL: {masked_url}")
    else:
        print("❌ DATABASE_URL NO ENCONTRADA")
        print("   Railway no está inyectando la variable")
        print("   Solución: Conecta PostgreSQL a tu API service")
    
    print("="*60)