import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static const _databaseName = 'healthshield_cache.db';
  static const _databaseVersion = 3;

  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), _databaseName);
    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Tabla de usuarios
    await db.execute('''
      CREATE TABLE usuarios (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        server_id INTEGER,
        username TEXT UNIQUE NOT NULL,
        email TEXT UNIQUE NOT NULL,
        password TEXT NOT NULL,
        telefono TEXT,
        is_professional BOOLEAN DEFAULT FALSE,
        professional_license TEXT,
        is_verified BOOLEAN DEFAULT FALSE,
        is_synced BOOLEAN DEFAULT FALSE,
        last_sync TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT
      )
    ''');

    // Tabla de pacientes
    await db.execute('''
      CREATE TABLE pacientes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        server_id INTEGER,
        nombre TEXT NOT NULL,
        cedula TEXT UNIQUE,
        telefono TEXT,
        fecha_nacimiento TEXT,
        tipo_paciente TEXT NOT NULL,
        is_synced BOOLEAN DEFAULT FALSE,
        last_sync TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT
      )
    ''');

    // Tabla de vacunas
    await db.execute('''
      CREATE TABLE vacunas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        server_id INTEGER,
        paciente_id INTEGER NOT NULL,
        tipo_vacuna TEXT NOT NULL,
        fecha_vacunacion TEXT NOT NULL,
        lote TEXT,
        proxima_dosis TEXT,
        dosis_numero INTEGER DEFAULT 1,
        is_synced BOOLEAN DEFAULT FALSE,
        last_sync TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT,
        FOREIGN KEY (paciente_id) REFERENCES pacientes (id)
      )
    ''');

    // Tabla de sincronización
    await db.execute('''
      CREATE TABLE sync_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        table_name TEXT NOT NULL,
        record_id INTEGER NOT NULL,
        operation TEXT NOT NULL,
        sync_status BOOLEAN DEFAULT FALSE,
        created_at TEXT NOT NULL
      )
    ''');

    // Insertar usuario admin por defecto
    await db.insert('usuarios', {
      'username': 'admin',
      'email': 'admin@healthshield.com',
      'password': 'admin123',
      'telefono': '123456789',
      'is_professional': 1,
      'professional_license': 'MED-001',
      'is_verified': 1,
      'is_synced': 1,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE usuarios ADD COLUMN last_sync TEXT');
      await db.execute('ALTER TABLE pacientes ADD COLUMN last_sync TEXT');
      await db.execute('ALTER TABLE vacunas ADD COLUMN last_sync TEXT');
    }
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS sync_logs (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          table_name TEXT NOT NULL,
          record_id INTEGER NOT NULL,
          operation TEXT NOT NULL,
          sync_status BOOLEAN DEFAULT FALSE,
          created_at TEXT NOT NULL
        )
      ''');
    }
  }

  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
    }
  }
}