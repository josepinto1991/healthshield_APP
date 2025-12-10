import psycopg2
import os
from dotenv import load_dotenv

load_dotenv()

def test_postgres():
    try:
        conn = psycopg2.connect(
            host="localhost",
            port="5444",
            database="healthshield",
            user="healthshield_user",
            password="healthshield_password"
        )
        cur = conn.cursor()
        cur.execute("SELECT 1")
        result = cur.fetchone()
        print(f"✅ PostgreSQL conectado: {result}")
        
        # Verificar tablas
        cur.execute("""
            SELECT table_name 
            FROM information_schema.tables 
            WHERE table_schema = 'public'
        """)
        tables = cur.fetchall()
        print(f"📊 Tablas disponibles: {[t[0] for t in tables]}")
        
        cur.close()
        conn.close()
        return True
        
    except Exception as e:
        print(f"❌ Error: {e}")
        return False

if __name__ == "__main__":
    test_postgres()