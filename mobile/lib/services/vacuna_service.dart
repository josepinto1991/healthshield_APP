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
    String path = join(await getDatabasesPath(), _databaseName); // ← CORREGIDO
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
        nombre_paciente TEXT NOT NULL,
        tipo_paciente TEXT NOT NULL,
        cedula_paciente TEXT,
        tipo_vacuna TEXT NOT NULL,
        fecha_vacunacion TEXT NOT NULL,
        lote TEXT,
        proxima_dosis TEXT,
        usuario_id INTEGER,
        is_synced INTEGER DEFAULT 0,
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
    final results = await db.query(
      'vacunas', 
      orderBy: 'fecha_vacunacion DESC'
    );
    return results.map((json) => Vacuna.fromJson(json)).toList();
  }

  Future<List<Vacuna>> buscarPorCedula(String cedula) async {
    final db = await database;
    final results = await db.query(
      'vacunas',
      where: 'cedula_paciente LIKE ?',
      whereArgs: ['%$cedula%'],
      orderBy: 'fecha_vacunacion DESC'
    );
    return results.map((json) => Vacuna.fromJson(json)).toList();
  }

  Future<List<Vacuna>> buscarPorNombre(String nombre) async {
    final db = await database;
    final results = await db.query(
      'vacunas',
      where: 'nombre_paciente LIKE ?',
      whereArgs: ['%$nombre%'],
      orderBy: 'fecha_vacunacion DESC'
    );
    return results.map((json) => Vacuna.fromJson(json)).toList();
  }

  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
    }
  }

  Future<List<Vacuna>> getUnsyncedVacunas() async {
  final db = await database;
  final results = await db.query(
    'vacunas',
    where: 'is_synced = 0'
  );
  return results.map((json) => Vacuna.fromJson(json)).toList();
}

  Future<void> markVacunaAsSynced(int localId, int serverId) async {
    final db = await database;
    await db.update(
      'vacunas',
      {'is_synced': 1, 'server_id': serverId},
      where: 'id = ?',
      whereArgs: [localId],
    );
  }

  // AGREGAR también este método que falta
  Future<void> saveVacunaFromServer(Vacuna vacuna) async {
    final db = await database;
    await db.insert('vacunas', vacuna.toJson());
  }
}