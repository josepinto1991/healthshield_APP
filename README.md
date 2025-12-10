HealthShield 🛡️ 
Aplicación móvil Flutter para gestión de pacientes y registro de vacunas, con funcionalidad offline-first y sincronización automática.


 Probar CI/CD

# Limpiar 
docker-compose down -v
# Construir
docker-compose build --no-cache
# Ejecutar
docker-compose up
# Ver logs
docker-compose logs -f
# Probar
curl http://localhost:8000/health


**📱 Características Principales**

- 👥 Gestión de Pacientes - Registrar y administrar información de pacientes
- 💉 Registro de Vacunas - Control completo del historial de vacunación
- ⚡ Trabajo Offline - Funciona sin conexión a internet
- 🔄 Sincronización Automática - Sincroniza datos cuando hay conexión
- 📊 Dashboard Integrado - Visualización del estado de sincronización
- 🔔 Recordatorios - Próximas dosis y citas


**🛠️ Stack Tecnológico**

- Flutter 3.0+ - Framework multiplataforma
- Dart 3.0+ - Lenguaje de programación
- SQLite - Base de datos local
- Provider - Gestión de estado
- HTTP - Cliente para APIs REST
- Connectivity Plus - Monitoreo de conexión
- Intl - Internacionalización

**Flujo de datos**

- 📱 MÓVIL (SQLite) ← HTTP API → 🖥️ BACKEND (PostgreSQL)
-      ↓                              ↓
-    Cache local                   Fuente de verdad
-    Trabajo offline              Datos actualizados

📱 MÓVIL (SQLite) = Cache local / Trabajo offline 
🖥️ BACKEND (PostgreSQL) = Fuente de verdad / Datos actualizados

Se usa un ORM (Object-Relational Mapping) es mucho mejor que SQL directo. SQLAlchemy + Pydantic

**🏗️ Arquitectura de la Aplicación**

healthshield/backend/

healthshield/
├── backend/
│   ├── venv/
│   ├── docker-compose.yml
│   ├── Dockerfile
│   ├── .env
│   ├── database.py
│   ├── main.py
│   ├── models.py
│   ├── repositories.py
│   ├── requirements.txt
│   └── professional_verification.py
│
└── mobile/
    ├── assets/
    │   └── images/
    │       └── logo.png
    │
    ├── lib/
    │   ├── main.dart
    │   │
    │   ├── models/
    │   │   ├── usuario.dart
    │   │   └── vacuna.dart
    │   │
    │   ├── screens/
    │   │   ├── welcome_screen.dart
    │   │   ├── login_screen.dart
    │   │   ├── professional_register_screen.dart
    │   │   ├── main_menu_screen.dart
    │   │   ├── registro_vacuna_screen.dart
    │   │   ├── visualizar_registros_screen.dart
    │   │   ├── sync_screen.dart
    │   │   ├── change_password_screen.dart
    │   │   └── dashboard_screen.dart  # NUEVO
    │   │
    │   ├── services/
    │   │   ├── auth_service.dart
    │   │   ├── vacuna_service.dart
    │   │   ├── api_service.dart
    │   │   ├── sync_service.dart
    │   │   └── bidirectional_sync_service.dart
    │   │
    │   ├── db_sqlite/
    │   │   ├── database_helper.dart
    │   │   └── cache_service.dart
    │   │
    │   └── utils/
    │       ├── app_config.dart
    │       └── app_routes.dart


**🚀 Instalación y Configuración**

_**Prerrequisitos**_

- Flutter SDK 3.0 o superior
- Dart 3.0 o superior
- Dispositivo físico o emulador
- Android Studio / VS Code


_**1. Clonar el Proyecto**_

bash
- git clone https://gitlab.com/KillerPR/healthshield_app.git
- cd healthshield/mobile

_**2. Instalar Dependencias**_
bash
- flutter pub get

_**3. Configurar Backend**_
- En lib/services/sync_service.dart, actualiza la URL del backend:

dart
- final String baseUrl = 'http://0.0.0.0:8000/api'; // IP API

_**4. Ejecutar la Aplicación**_
bash
# Conectar dispositivo o iniciar emulador
- flutter devices 

- flutter clean
- flutter pub get
- flutter run -d emulator-5554 _con emulador_

# Ejecutar en modo desarrollo
- flutter run

# O compilar para release
- flutter build apk --release


_**🔄 Flujo de Sincronización**_

- Almacenamiento Local → Los datos se guardan primero en SQFlite
- Detección de Conexión → El servicio monitorea la conectividad
- Envío al Servidor → Datos no sincronizados se envían al backend
- Confirmación → El servidor responde con IDs asignados
- Actualización Local → Los registros se marcan como sincronizados
- Descarga de Actualizaciones → Se obtienen datos nuevos del servidor

_**📦 Build y Distribución**_

- Android APK
bash
flutter build apk --release

- Android App Bundle
bash
flutter build appbundle --release

- iOS (requiere Mac)
bash
flutter build ios --release
