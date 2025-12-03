import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/vacuna.dart';

class VacunaService {
  static const _databaseName = 'healthshield_vacunas.db';
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
        updated_at TEXT
      )
    ''');
  }

  Future<int> crearVacuna(Vacuna vacuna) async {
    final db = await database;
    return await db.insert('vacunas', vacuna.toJson());
  }

  Future<List<Vacuna>> getVacunas() async {
    final db = await database;
    final results = await db.query('vacunas', orderBy: 'fecha_aplicacion DESC');
    return results.map((json) => Vacuna.fromJson(json)).toList();
  }

  Future<List<Vacuna>> buscarPorPaciente(int pacienteId) async {
    final db = await database;
    final results = await db.query(
      'vacunas',
      where: 'paciente_id = ?',
      whereArgs: [pacienteId],
      orderBy: 'fecha_aplicacion DESC'
    );
    return results.map((json) => Vacuna.fromJson(json)).toList();
  }

  Future<List<Vacuna>> getUnsyncedVacunas() async {
    final db = await database;
    final results = await db.query('vacunas', where: 'is_synced = 0');
    return results.map((json) => Vacuna.fromJson(json)).toList();
  }

  Future<void> markVacunaAsSynced(int localId, int serverId) async {
    final db = await database;
    await db.update(
      'vacunas',
      {
        'is_synced': 1,
        'server_id': serverId,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [localId],
    );
  }

  Future<void> saveVacunaFromServer(Map<String, dynamic> vacunaData) async {
    final db = await database;
    
    // Verificar si ya existe por server_id
    final existing = await db.query(
      'vacunas',
      where: 'server_id = ?',
      whereArgs: [vacunaData['id']],
    );
    
    if (existing.isEmpty) {
      // Crear nueva vacuna
      final vacuna = Vacuna(
        serverId: vacunaData['id'],
        pacienteId: vacunaData['paciente_id'],
        nombreVacuna: vacunaData['nombre_vacuna'],
        fechaAplicacion: vacunaData['fecha_aplicacion'],
        lote: vacunaData['lote'],
        proximaDosis: vacunaData['proxima_dosis'],
        usuarioId: vacunaData['usuario_id'],
        isSynced: true,
        createdAt: DateTime.parse(vacunaData['created_at']),
        updatedAt: vacunaData['updated_at'] != null 
            ? DateTime.parse(vacunaData['updated_at']) 
            : null,
      );
      
      await db.insert('vacunas', vacuna.toJson());
    }
  }

  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
    }
  }
}