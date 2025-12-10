import 'package:sqflite/sqflite.dart';
import '../models/paciente.dart';
import '../models/vacuna.dart';
import '../db_sqlite/database_helper.dart';

class PacienteService {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<int> crearPaciente(Paciente paciente) async {
    final db = await _dbHelper.database;
    return await db.insert('pacientes', paciente.toJson());
  }

  Future<List<Paciente>> getPacientes() async {
    final db = await _dbHelper.database;
    final results = await db.query('pacientes', orderBy: 'nombre ASC');
    return results.map((json) => Paciente.fromJson(json)).toList();
  }

  Future<Paciente?> getPacienteById(int id) async {
    final db = await _dbHelper.database;
    final results = await db.query(
      'pacientes',
      where: 'id = ?',
      whereArgs: [id],
    );
    return results.isNotEmpty ? Paciente.fromJson(results.first) : null;
  }

  Future<Paciente?> getPacienteByCedula(String cedula) async {
    final db = await _dbHelper.database;
    final results = await db.query(
      'pacientes',
      where: 'cedula = ?',
      whereArgs: [cedula],
    );
    return results.isNotEmpty ? Paciente.fromJson(results.first) : null;
  }

  Future<List<Paciente>> buscarPacientes(String query) async {
    final db = await _dbHelper.database;
    final results = await db.query(
      'pacientes',
      where: 'cedula LIKE ? OR nombre LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'nombre ASC',
    );
    return results.map((json) => Paciente.fromJson(json)).toList();
  }

  Future<bool> actualizarPaciente(Paciente paciente) async {
    final db = await _dbHelper.database;
    final updated = await db.update(
      'pacientes',
      paciente.toJson(),
      where: 'id = ?',
      whereArgs: [paciente.id],
    );
    return updated > 0;
  }

  Future<List<Paciente>> getPacientesNoSincronizados() async {
    final db = await _dbHelper.database;
    final results = await db.query(
      'pacientes',
      where: 'is_synced = ?',
      whereArgs: [0],
    );
    return results.map((json) => Paciente.fromJson(json)).toList();
  }

  Future<void> guardarPacienteDesdeServidor(Paciente paciente) async {
    final db = await _dbHelper.database;
    
    final existente = await getPacienteByCedula(paciente.cedula);
    
    if (existente != null) {
      paciente.id = existente.id;
      await actualizarPaciente(paciente);
    } else {
      await db.insert('pacientes', paciente.toJson());
    }
  }

  Future<void> marcarPacienteComoSincronizado(int localId, int serverId) async {
    final db = await _dbHelper.database;
    await db.update(
      'pacientes',
      {
        'is_synced': 1,
        'server_id': serverId,
        'last_sync': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [localId],
    );
  }

  Future<List<Vacuna>> getVacunasDelPaciente(int pacienteId) async {
    final db = await _dbHelper.database;
    final results = await db.query(
      'vacunas',
      where: 'paciente_id = ?',
      whereArgs: [pacienteId],
      orderBy: 'fecha_aplicacion DESC',
    );
    
    return results.map((json) => Vacuna.fromJson(json)).toList();
  }
}