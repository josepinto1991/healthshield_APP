import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static const _databaseName = 'healthshield_cache.db';
  static const _databaseVersion = 5; // ✅ Cambiar de 4 a 5

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
    print('✅ Creando base de datos versión $version');
    
    // Tabla de verificaciones pendientes
    await db.execute('''
      CREATE TABLE IF NOT EXISTS pending_verifications (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        usuario_id INTEGER NOT NULL,
        cedula TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (usuario_id) REFERENCES usuarios (id)
      )
    ''');

    // Tabla de usuarios
    await db.execute('''
      CREATE TABLE IF NOT EXISTS usuarios (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        server_id INTEGER,
        username TEXT UNIQUE NOT NULL,
        email TEXT UNIQUE NOT NULL,
        password TEXT NOT NULL,
        telefono TEXT,
        is_professional BOOLEAN DEFAULT FALSE,
        professional_license TEXT,
        is_verified BOOLEAN DEFAULT FALSE,
        role TEXT DEFAULT 'user',
        is_synced BOOLEAN DEFAULT FALSE,
        last_sync TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT
      )
    ''');

    // Tabla de pacientes
    await db.execute('''
      CREATE TABLE IF NOT EXISTS pacientes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        server_id INTEGER,
        cedula TEXT UNIQUE NOT NULL,
        nombre TEXT NOT NULL,
        fecha_nacimiento TEXT NOT NULL,
        telefono TEXT,
        direccion TEXT,
        is_synced BOOLEAN DEFAULT FALSE,
        last_sync TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT
      )
    ''');

    // ✅ TABLA VACUNAS ACTUALIZADA
    await db.execute('''
      CREATE TABLE IF NOT EXISTS vacunas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        server_id INTEGER,
        paciente_id INTEGER, -- Cambiado a opcional
        paciente_server_id INTEGER, -- ✅ Agregada
        nombre_vacuna TEXT NOT NULL,
        fecha_aplicacion TEXT NOT NULL,
        lote TEXT,
        proxima_dosis TEXT,
        usuario_id INTEGER,
        is_synced BOOLEAN DEFAULT FALSE,
        last_sync TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT,
        nombre_paciente TEXT, -- ✅ AGREGADA
        cedula_paciente TEXT -- ✅ AGREGADA
      )
    ''');

    // Tabla de sincronización
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

    // Verificar si ya existe usuario admin
    final existingAdmin = await db.query(
      'usuarios',
      where: 'username = ?',
      whereArgs: ['admin'],
    );
    
    if (existingAdmin.isEmpty) {
      await db.insert('usuarios', {
        'username': 'admin',
        'email': 'admin@healthshield.com',
        'password': 'admin123',
        'telefono': '123456789',
        'is_professional': 1,
        'professional_license': 'ADM-001',
        'is_verified': 1,
        'role': 'admin',
        'is_synced': 1,
        'created_at': DateTime.now().toIso8601String(),
      });
      print('✅ Usuario admin creado');
    }
    
    print('✅ Base de datos creada exitosamente');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    print('🔄 Actualizando base de datos de versión $oldVersion a $newVersion');
    
    for (int version = oldVersion + 1; version <= newVersion; version++) {
      await _migrateToVersion(db, version);
    }
  }

  Future<void> _migrateToVersion(Database db, int version) async {
    print('🔄 Migrando a versión $version');
    
    switch (version) {
      case 2:
        await _migrateToVersion2(db);
        break;
      case 3:
        await _migrateToVersion3(db);
        break;
      case 4:
        await _migrateToVersion4(db);
        break;
      case 5:
        await _migrateToVersion5(db); // ✅ NUEVA MIGRACIÓN
        break;
    }
  }

  Future<void> _migrateToVersion2(Database db) async {
    try {
      final tables = ['usuarios', 'pacientes', 'vacunas'];
      
      for (var table in tables) {
        try {
          await db.execute('ALTER TABLE $table ADD COLUMN last_sync TEXT');
          print('✅ Agregada columna last_sync a tabla $table');
        } catch (e) {
          print('ℹ️ Columna last_sync ya existe en $table: $e');
        }
      }
    } catch (e) {
      print('❌ Error en migración a versión 2: $e');
    }
  }

  Future<void> _migrateToVersion3(Database db) async {
    try {
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
      print('✅ Tabla sync_logs creada/verificada');
    } catch (e) {
      print('❌ Error en migración a versión 3: $e');
    }
  }

  Future<void> _migrateToVersion4(Database db) async {
    try {
      try {
        await db.execute('ALTER TABLE usuarios ADD COLUMN role TEXT DEFAULT "user"');
        print('✅ Agregada columna role a tabla usuarios');
        
        await db.update(
          'usuarios',
          {'role': 'admin'},
          where: 'username = ?',
          whereArgs: ['admin'],
        );
        print('✅ Actualizado rol de usuario admin');
      } catch (e) {
        print('ℹ️ Columna role ya existe: $e');
      }
    } catch (e) {
      print('❌ Error en migración a versión 4: $e');
    }
  }

  // ✅ NUEVA MIGRACIÓN PARA VERSIÓN 5
  Future<void> _migrateToVersion5(Database db) async {
    try {
      print('🔄 Actualizando tabla vacunas...');
      
      // Agregar columnas faltantes a tabla vacunas
      try {
        await db.execute('ALTER TABLE vacunas ADD COLUMN nombre_paciente TEXT');
        print('✅ Agregada columna nombre_paciente a tabla vacunas');
      } catch (e) {
        print('ℹ️ Columna nombre_paciente ya existe: $e');
      }
      
      try {
        await db.execute('ALTER TABLE vacunas ADD COLUMN cedula_paciente TEXT');
        print('✅ Agregada columna cedula_paciente a tabla vacunas');
      } catch (e) {
        print('ℹ️ Columna cedula_paciente ya existe: $e');
      }
      
      try {
        await db.execute('ALTER TABLE vacunas ADD COLUMN paciente_server_id INTEGER');
        print('✅ Agregada columna paciente_server_id a tabla vacunas');
      } catch (e) {
        print('ℹ️ Columna paciente_server_id ya existe: $e');
      }
      
      // Cambiar paciente_id a opcional si no lo es ya
      try {
        // No hay ALTER para cambiar NOT NULL, así que manejaremos en la lógica
        print('ℹ️ paciente_id se manejará como opcional en la lógica');
      } catch (e) {
        print('ℹ️ No se pudo modificar paciente_id: $e');
      }
      
      print('✅ Migración a versión 5 completada');
    } catch (e) {
      print('❌ Error en migración a versión 5: $e');
    }
  }

  Future<void> deleteDatabaseFile() async {
    String path = join(await getDatabasesPath(), _databaseName);
    await deleteDatabase(path);
    print('🗑️ Base de datos eliminada');
  }

  // ✅ NUEVO MÉTODO: Verificar estructura de tablas
  Future<void> verificarEstructura() async {
    final db = await database;
    
    final tablas = ['usuarios', 'pacientes', 'vacunas'];
    
    for (var tabla in tablas) {
      print('📋 Estructura de tabla $tabla:');
      final info = await db.rawQuery('PRAGMA table_info($tabla)');
      for (var col in info) {
        print('  ${col['name']} (${col['type']}) - PK: ${col['pk']} - NotNull: ${col['notnull']}');
      }
      print('');
    }
  }

  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}