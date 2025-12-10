import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/vacuna.dart';
import 'paciente_service.dart';

class VacunaService {
  static const _databaseName = 'healthshield_vacunas.db';
  static const _databaseVersion = 2;

  Database? _database;

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
        created_at TEXT NOT NULL,
        updated_at TEXT
      )
    ''');
  }

  // Método de inicialización
  Future<void> init() async {
    await database;
  }

  // Crear vacuna
  Future<int> crearVacuna(Vacuna vacuna) async {
    final db = await database;
    return await db.insert('vacunas', vacuna.toJson());
  }

  // Obtener todas las vacunas
  Future<List<Vacuna>> getVacunas() async {
    final db = await database;
    final results = await db.query(
      'vacunas', 
      orderBy: 'fecha_aplicacion DESC'
    );
    return results.map((json) => Vacuna.fromJson(json)).toList();
  }

  // Obtener vacunas no sincronizadas
  Future<List<Vacuna>> getUnsyncedVacunas() async {
    final db = await database;
    final results = await db.query(
      'vacunas',
      where: 'is_synced = 0'
    );
    return results.map((json) => Vacuna.fromJson(json)).toList();
  }

  // Marcar vacuna como sincronizada
  Future<void> markVacunaAsSynced(int localId, int serverId) async {
    final db = await database;
    await db.update(
      'vacunas',
      {
        'is_synced': 1, 
        'server_id': serverId,
        'updated_at': DateTime.now().toIso8601String()
      },
      where: 'id = ?',
      whereArgs: [localId],
    );
  }

  // Guardar vacuna desde servidor
  Future<void> saveVacunaFromServer(Vacuna vacuna) async {
    final db = await database;
    await db.insert('vacunas', vacuna.toJson());
  }

  // Buscar por cédula
  Future<List<Vacuna>> buscarPorCedula(String cedula) async {
    final db = await database;
    final results = await db.query(
      'vacunas',
      where: 'cedula_paciente LIKE ?',
      whereArgs: ['%$cedula%'],
      orderBy: 'fecha_aplicacion DESC'
    );
    return results.map((json) => Vacuna.fromJson(json)).toList();
  }

  // Buscar por nombre
  Future<List<Vacuna>> buscarPorNombre(String nombre) async {
    final db = await database;
    final results = await db.query(
      'vacunas',
      where: 'nombre_paciente LIKE ?',
      whereArgs: ['%$nombre%'],
      orderBy: 'fecha_aplicacion DESC'
    );
    return results.map((json) => Vacuna.fromJson(json)).toList();
  }

  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
    }
  }
}