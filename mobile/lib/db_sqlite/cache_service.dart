
import 'package:sqflite/sqflite.dart';
import '../models/usuario.dart';
import '../models/vacuna.dart';
import 'database_helper.dart';

class CacheService {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<Database> getDatabase() async {
    return await _dbHelper.database;
  }

  // ========== USUARIOS ==========
  Future<int> insertUsuario(Usuario usuario) async {
    final db = await _dbHelper.database;
    return await db.insert('usuarios', usuario.toJson());
  }

  Future<List<Usuario>> getUsuarios() async {
    final db = await _dbHelper.database;
    final results = await db.query('usuarios');
    return results.map((json) => Usuario.fromJson(json)).toList();
  }

  Future<Usuario?> getUsuarioByCredentials(String username, String password) async {
    final db = await _dbHelper.database;
    final results = await db.query(
      'usuarios',
      where: 'username = ? AND password = ?',
      whereArgs: [username, password],
    );
    return results.isNotEmpty ? Usuario.fromJson(results.first) : null;
  }

  Future<Usuario?> getUsuarioActual() async {
    final db = await _dbHelper.database;
    final results = await db.query('usuarios', limit: 1);
    return results.isNotEmpty ? Usuario.fromJson(results.first) : null;
  }

  Future<Usuario?> getUsuarioById(int usuarioId) async {
    final db = await _dbHelper.database;
    final results = await db.query(
      'usuarios',
      where: 'id = ?',
      whereArgs: [usuarioId],
    );
    return results.isNotEmpty ? Usuario.fromJson(results.first) : null;
  }

  Future<bool> actualizarUsuario(Usuario usuario) async {
    final db = await _dbHelper.database;
    final updated = await db.update(
      'usuarios',
      usuario.toJson(),
      where: 'id = ?',
      whereArgs: [usuario.id],
    );
    return updated > 0;
  }

  // ========== SINCRONIZACIÓN ==========
  Future<void> logSyncOperation(String tableName, int recordId, String operation) async {
    final db = await _dbHelper.database;
    await db.insert('sync_logs', {
      'table_name': tableName,
      'record_id': recordId,
      'operation': operation,
      'sync_status': false,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getPendingSyncs() async {
    final db = await _dbHelper.database;
    return await db.query(
      'sync_logs',
      where: 'sync_status = ?',
      whereArgs: [0],
    );
  }

  Future<void> markSyncAsCompleted(int syncId) async {
    final db = await _dbHelper.database;
    await db.update(
      'sync_logs',
      {'sync_status': 1},
      where: 'id = ?',
      whereArgs: [syncId],
    );
  }

  // ========== DATOS SINCRONIZABLES ==========
  Future<List<Map<String, dynamic>>> getUnsyncedData(String tableName) async {
    final db = await _dbHelper.database;
    return await db.query(
      tableName,
      where: 'is_synced = ?',
      whereArgs: [0],
    );
  }

  Future<void> markDataAsSynced(String tableName, int localId, int serverId) async {
    final db = await _dbHelper.database;
    await db.update(
      tableName,
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

  Future<void> clearSensitiveData() async {
    final db = await _dbHelper.database;
    await _dbHelper.close();
  }

  Future<void> close() async {
    await _dbHelper.close();
  }
}