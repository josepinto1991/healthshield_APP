import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/vacuna.dart';

class VacunaService {
  static const _databaseName = 'healthshield_vacunas.db';
  static const _databaseVersion = 3; // ✅ Cambiar de 2 a 3

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
      onUpgrade: _onUpgrade, // ✅ Agregar onUpgrade para migraciones
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE vacunas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        server_id INTEGER,
        paciente_id INTEGER, -- Cambiado a opcional
        paciente_server_id INTEGER, -- ✅ Agregada esta columna
        nombre_vacuna TEXT NOT NULL,
        fecha_aplicacion TEXT NOT NULL,
        lote TEXT,
        proxima_dosis TEXT,
        usuario_id INTEGER,
        is_synced INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT,
        nombre_paciente TEXT, -- ✅ AGREGADA
        cedula_paciente TEXT  -- ✅ AGREGADA
      )
    ''');
    print('✅ Tabla vacunas creada con columnas adicionales');
  }

  // ✅ Nuevo método para manejar migraciones
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    print('🔄 Actualizando tabla vacunas de versión $oldVersion a $newVersion');
    
    if (oldVersion < 3) {
      // Agregar columnas faltantes si vienen de versión anterior
      try {
        await db.execute('ALTER TABLE vacunas ADD COLUMN nombre_paciente TEXT');
        print('✅ Columna nombre_paciente agregada');
      } catch (e) {
        print('ℹ️ Columna nombre_paciente ya existe: $e');
      }
      
      try {
        await db.execute('ALTER TABLE vacunas ADD COLUMN cedula_paciente TEXT');
        print('✅ Columna cedula_paciente agregada');
      } catch (e) {
        print('ℹ️ Columna cedula_paciente ya existe: $e');
      }
      
      try {
        await db.execute('ALTER TABLE vacunas ADD COLUMN paciente_server_id INTEGER');
        print('✅ Columna paciente_server_id agregada');
      } catch (e) {
        print('ℹ️ Columna paciente_server_id ya existe: $e');
      }
    }
  }

  // Método de inicialización
  Future<void> init() async {
    await database;
    print('✅ VacunaService inicializado correctamente');
  }

  // Crear vacuna - MÉTODO CORREGIDO
  Future<int> crearVacuna(Vacuna vacuna) async {
    final db = await database;
    
    try {
      // Asegurar que los campos opcionales sean null si están vacíos
      final Map<String, dynamic> vacunaData = {
        'id': vacuna.id,
        'server_id': vacuna.serverId,
        'paciente_id': vacuna.pacienteId,
        'paciente_server_id': vacuna.pacienteServerId,
        'nombre_vacuna': vacuna.nombreVacuna,
        'fecha_aplicacion': vacuna.fechaAplicacion,
        'lote': vacuna.lote?.isNotEmpty == true ? vacuna.lote : null,
        'proxima_dosis': vacuna.proximaDosis?.isNotEmpty == true ? vacuna.proximaDosis : null,
        'usuario_id': vacuna.usuarioId,
        'is_synced': vacuna.isSynced ? 1 : 0,
        'created_at': vacuna.createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
        'updated_at': vacuna.updatedAt?.toIso8601String(),
        'nombre_paciente': vacuna.nombrePaciente?.isNotEmpty == true ? vacuna.nombrePaciente : null,
        'cedula_paciente': vacuna.cedulaPaciente?.isNotEmpty == true ? vacuna.cedulaPaciente : null,
      };
      
      // Eliminar valores null del mapa para usar solo columnas existentes
      vacunaData.removeWhere((key, value) => value == null);
      
      print('📝 Insertando vacuna: $vacunaData');
      final id = await db.insert('vacunas', vacunaData);
      print('✅ Vacuna insertada con ID: $id');
      return id;
    } catch (e) {
      print('❌ Error insertando vacuna: $e');
      rethrow;
    }
  }

  // Obtener todas las vacunas
  Future<List<Vacuna>> getVacunas() async {
    final db = await database;
    final results = await db.query(
      'vacunas', 
      orderBy: 'fecha_aplicacion DESC'
    );
    print('📊 Obtenidas ${results.length} vacunas');
    return results.map((json) => Vacuna.fromJson(json)).toList();
  }

  // Obtener vacunas no sincronizadas
  Future<List<Vacuna>> getUnsyncedVacunas() async {
    final db = await database;
    final results = await db.query(
      'vacunas',
      where: 'is_synced = 0'
    );
    print('📊 Vacunas no sincronizadas: ${results.length}');
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
    print('✅ Vacuna $localId marcada como sincronizada');
  }

  // Guardar vacuna desde servidor
  Future<void> saveVacunaFromServer(Vacuna vacuna) async {
    final db = await database;
    await db.insert('vacunas', vacuna.toJson());
    print('✅ Vacuna del servidor guardada: ${vacuna.nombrePaciente}');
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
    print('🔍 Buscando por cédula "$cedula": ${results.length} resultados');
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
    print('🔍 Buscando por nombre "$nombre": ${results.length} resultados');
    return results.map((json) => Vacuna.fromJson(json)).toList();
  }

  // ✅ NUEVO MÉTODO: Verificar estructura de la tabla
  Future<void> verificarEstructuraTabla() async {
    final db = await database;
    final tablaInfo = await db.rawQuery('PRAGMA table_info(vacunas)');
    print('📋 Estructura de tabla vacunas:');
    for (var columna in tablaInfo) {
      print('  ${columna['name']} (${columna['type']})');
    }
  }

  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
      print('✅ VacunaService cerrado');
    }
  }
}