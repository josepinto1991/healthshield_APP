from database import get_db, hash_password
from models import Usuario
from sqlalchemy.orm import Session

def create_admin_user(db: Session):
    # Verificar si ya existe
    existing_admin = db.query(Usuario).filter(Usuario.username == 'admin').first()
    if existing_admin:
        print("✅ Usuario admin ya existe")
        return
    
    # Crear admin
    admin_user = Usuario(
        username='admin',
        email='admin@healthshield.com',
        password=hash_password('admin'),
        telefono='0000000000',
        is_professional=True,
        professional_license='ADMIN-001',
        is_verified=True
    )
    
    db.add(admin_user)
    db.commit()
    print("✅ Usuario admin creado exitosamente")

if __name__ == "__main__":
    db = next(get_db())
    create_admin_user(db)