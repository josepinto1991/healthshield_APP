import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/paciente.dart';

class PacienteService {
  static const _databaseName = 'healthshield_local.db';
  static const _databaseVersion = 1;

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<void> init() async {
    await database;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), _databaseName);
    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE pacientes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        server_id INTEGER,
        cedula TEXT,
        nombre TEXT NOT NULL,
        fecha_nacimiento TEXT NOT NULL,
        telefono TEXT,
        direccion TEXT,
        is_synced INTEGER DEFAULT 0,
        sync_error TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE vacunas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        server_id INTEGER,
        paciente_id INTEGER NOT NULL,
        nombre_vacuna TEXT NOT NULL,
        fecha_aplicacion TEXT NOT NULL,
        lote TEXT,
        proxima_dosis TEXT,
        usuario_id INTEGER,
        is_synced INTEGER DEFAULT 0,
        sync_error TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT,
        FOREIGN KEY (paciente_id) REFERENCES pacientes (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE sync_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        table_name TEXT NOT NULL,
        local_id INTEGER NOT NULL,
        server_id INTEGER,
        operation TEXT NOT NULL,
        status TEXT DEFAULT 'pending',
        error_message TEXT,
        created_at TEXT NOT NULL,
        synced_at TEXT
      )
    ''');
  }

  // CRUD Pacientes
  Future<int> createPaciente(Paciente paciente) async {
    final db = await database;
    return await db.insert('pacientes', paciente.toJson());
  }

  Future<List<Paciente>> getPacientes() async {
    final db = await database;
    final results = await db.query('pacientes', orderBy: 'created_at DESC');
    return results.map((json) => Paciente.fromJson(json)).toList();
  }

  Future<Paciente?> getPacienteById(int id) async {
    final db = await database;
    final results = await db.query('pacientes', where: 'id = ?', whereArgs: [id]);
    return results.isNotEmpty ? Paciente.fromJson(results.first) : null;
  }

  Future<Paciente?> getPacienteByCedula(String cedula) async {
    final db = await database;
    final results = await db.query('pacientes', where: 'cedula = ?', whereArgs: [cedula]);
    return results.isNotEmpty ? Paciente.fromJson(results.first) : null;
  }

  Future<List<Paciente>> getUnsyncedPacientes() async {
    final db = await database;
    final results = await db.query(
      'pacientes',
      where: 'is_synced = 0',
    );
    return results.map((json) => Paciente.fromJson(json)).toList();
  }

  Future<void> markPacienteAsSynced(int localId, int serverId) async {
    final db = await database;
    await db.update(
      'pacientes',
      {
        'is_synced': 1,
        'server_id': serverId,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [localId],
    );
  }

  Future<void> savePacienteFromServer(Map<String, dynamic> pacienteData) async {
    final db = await database;
    
    // Verificar si ya existe por server_id
    final existing = await db.query(
      'pacientes',
      where: 'server_id = ?',
      whereArgs: [pacienteData['id']],
    );
    
    if (existing.isEmpty) {
      // Crear nuevo
      final paciente = Paciente(
        serverId: pacienteData['id'],
        cedula: pacienteData['cedula'] ?? '',
        nombre: pacienteData['nombre'],
        fechaNacimiento: pacienteData['fecha_nacimiento'],
        telefono: pacienteData['telefono'],
        direccion: pacienteData['direccion'],
        isSynced: true,
        createdAt: DateTime.parse(pacienteData['created_at']),
        updatedAt: pacienteData['updated_at'] != null 
            ? DateTime.parse(pacienteData['updated_at']) 
            : null,
      );
      
      await db.insert('pacientes', paciente.toJson());
    }
  }

  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
    }
  }
}