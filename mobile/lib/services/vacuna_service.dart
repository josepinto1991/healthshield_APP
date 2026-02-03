import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/vacuna.dart';

class VacunaService {
  static const _databaseName = 'healthshield_vacunas.db';
  static const _databaseVersion = 4; // ✅ Cambiar de 3 a 4 para nueva versión

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
      onUpgrade: _onUpgrade,
      onOpen: (db) async {
        // ✅ VERIFICAR COLUMNAS FALTANTES AL ABRIR LA BD
        await _verificarColumnasFaltantes(db);
      },
    );
  }

  Future<void> _verificarColumnasFaltantes(Database db) async {
    try {
      print('🔍 Verificando columnas faltantes en tabla vacunas...');
      
      final tablaInfo = await db.rawQuery('PRAGMA table_info(vacunas)');
      final columnasExistentes = tablaInfo.map((col) => col['name'] as String).toList();
      
      print('📋 Columnas existentes: $columnasExistentes');
      
      // Lista de columnas requeridas
      final columnasRequeridas = [
        'es_menor',
        'cedula_tutor', 
        'cedula_propia'
      ];
      
      for (var columna in columnasRequeridas) {
        if (!columnasExistentes.contains(columna)) {
          print('➕ Agregando columna $columna a tabla vacunas...');
          try {
            if (columna == 'es_menor') {
              await db.execute('ALTER TABLE vacunas ADD COLUMN es_menor BOOLEAN DEFAULT FALSE');
            } else {
              await db.execute('ALTER TABLE vacunas ADD COLUMN $columna TEXT');
            }
            print('✅ Columna $columna agregada');
          } catch (e) {
            print('❌ Error agregando columna $columna: $e');
          }
        } else {
          print('ℹ️ Columna $columna ya existe');
        }
      }
    } catch (e) {
      print('❌ Error verificando columnas: $e');
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE vacunas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        server_id INTEGER,
        paciente_id INTEGER,
        paciente_server_id INTEGER,
        nombre_vacuna TEXT NOT NULL,
        fecha_aplicacion TEXT NOT NULL,
        lote TEXT,
        proxima_dosis TEXT,
        usuario_id INTEGER,
        is_synced INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT,
        nombre_paciente TEXT,
        cedula_paciente TEXT,
        es_menor BOOLEAN DEFAULT FALSE, -- ✅ COLUMNA AGREGADA
        cedula_tutor TEXT, -- ✅ COLUMNA AGREGADA
        cedula_propia TEXT -- ✅ COLUMNA AGREGADA
      )
    ''');
    print('✅ Tabla vacunas creada con todas las columnas (incluyendo es_menor)');
  }

  // ✅ Nuevo método para manejar migraciones
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    print('🔄 Actualizando tabla vacunas de versión $oldVersion a $newVersion');
    
    // Si viene de versión anterior a 4, agregar columnas nuevas
    if (oldVersion < 4) {
      try {
        await db.execute('ALTER TABLE vacunas ADD COLUMN es_menor BOOLEAN DEFAULT FALSE');
        print('✅ Columna es_menor agregada');
      } catch (e) {
        print('ℹ️ Columna es_menor ya existe: $e');
      }
      
      try {
        await db.execute('ALTER TABLE vacunas ADD COLUMN cedula_tutor TEXT');
        print('✅ Columna cedula_tutor agregada');
      } catch (e) {
        print('ℹ️ Columna cedula_tutor ya existe: $e');
      }
      
      try {
        await db.execute('ALTER TABLE vacunas ADD COLUMN cedula_propia TEXT');
        print('✅ Columna cedula_propia agregada');
      } catch (e) {
        print('ℹ️ Columna cedula_propia ya existe: $e');
      }
    }
  }

  // Método de inicialización
  Future<void> init() async {
    await database;
    print('✅ VacunaService inicializado correctamente');
    
    // ✅ Verificar estructura después de inicializar
    await verificarEstructuraTabla();
  }

  // Crear vacuna - MÉTODO ACTUALIZADO CON TODOS LOS CAMPOS
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
        // ✅ AGREGAR LOS NUEVOS CAMPOS
        'es_menor': vacuna.esMenor ? 1 : 0,
        'cedula_tutor': vacuna.cedulaTutor,
        'cedula_propia': vacuna.cedulaPropia,
      };
      
      // Eliminar valores null del mapa para usar solo columnas existentes
      vacunaData.removeWhere((key, value) => value == null);
      
      // ✅ LOG DETALLADO PARA DEPURACIÓN
      print('📝 Insertando vacuna:');
      print('  Nombre: ${vacuna.nombrePaciente}');
      print('  Cédula: ${vacuna.cedulaPaciente}');
      print('  Es Menor: ${vacuna.esMenor}');
      print('  Cédula Tutor: ${vacuna.cedulaTutor}');
      print('  Cédula Propia: ${vacuna.cedulaPropia}');
      print('  Datos a insertar: $vacunaData');
      
      final id = await db.insert('vacunas', vacunaData);
      print('✅ Vacuna insertada con ID: $id');
      return id;
    } catch (e) {
      print('❌ Error insertando vacuna: $e');
      
      // ✅ INTENTAR VERIFICAR ESTRUCTURA SI HAY ERROR
      print('🔄 Intentando verificar estructura de tabla...');
      await verificarEstructuraTabla();
      
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
    
    // ✅ LOG DETALLADO DE LOS RESULTADOS
    for (var i = 0; i < results.length; i++) {
      final vacuna = Vacuna.fromJson(results[i]);
      print('  Resultado ${i + 1}: ${vacuna.nombrePaciente} - Es Menor: ${vacuna.esMenor}');
    }
    
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
    print('\n📋 Estructura de tabla vacunas:');
    for (var columna in tablaInfo) {
      print('  ${columna['name']} (${columna['type']})');
    }
  }

  // ✅ NUEVO MÉTODO: Depurar últimas vacunas registradas
  Future<void> depurarVacunasRecientes() async {
    final db = await database;
    final resultados = await db.query(
      'vacunas',
      orderBy: 'id DESC',
      limit: 10,
    );
    
    print('\n=== ÚLTIMAS 10 VACUNAS REGISTRADAS ===');
    for (var i = 0; i < resultados.length; i++) {
      final vacuna = Vacuna.fromJson(resultados[i]);
      print('Vacuna ${i + 1}:');
      print('  ID: ${vacuna.id}');
      print('  Nombre: ${vacuna.nombrePaciente}');
      print('  Cédula: ${vacuna.cedulaPaciente}');
      print('  Es Menor: ${vacuna.esMenor}');
      print('  Cédula Tutor: ${vacuna.cedulaTutor}');
      print('  Cédula Propia: ${vacuna.cedulaPropia}');
      print('  Fecha: ${vacuna.fechaAplicacion}');
      print('  --------------------');
    }
  }

  // ✅ NUEVO MÉTODO: Reparar tabla si es necesario
  Future<void> repararTablaVacunas() async {
    final db = await database;
    print('🛠️ Reparando tabla vacunas...');
    
    try {
      // 1. Verificar columnas existentes
      final tablaInfo = await db.rawQuery('PRAGMA table_info(vacunas)');
      final columnasExistentes = tablaInfo.map((col) => col['name'] as String).toList();
      
      // 2. Crear nueva tabla temporal
      await db.execute('''
        CREATE TABLE IF NOT EXISTS vacunas_temp (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          server_id INTEGER,
          paciente_id INTEGER,
          paciente_server_id INTEGER,
          nombre_vacuna TEXT NOT NULL,
          fecha_aplicacion TEXT NOT NULL,
          lote TEXT,
          proxima_dosis TEXT,
          usuario_id INTEGER,
          is_synced INTEGER DEFAULT 0,
          created_at TEXT NOT NULL,
          updated_at TEXT,
          nombre_paciente TEXT,
          cedula_paciente TEXT,
          es_menor BOOLEAN DEFAULT FALSE,
          cedula_tutor TEXT,
          cedula_propia TEXT
        )
      ''');
      
      // 3. Copiar datos existentes
      await db.execute('''
        INSERT INTO vacunas_temp 
        SELECT * FROM vacunas
      ''');
      
      // 4. Eliminar tabla original
      await db.execute('DROP TABLE vacunas');
      
      // 5. Renombrar tabla temporal
      await db.execute('ALTER TABLE vacunas_temp RENAME TO vacunas');
      
      print('✅ Tabla vacunas reparada exitosamente');
    } catch (e) {
      print('❌ Error reparando tabla: $e');
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