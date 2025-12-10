import 'package:connectivity_plus/connectivity_plus.dart';
import '../db_sqlite/cache_service.dart';
import '../models/usuario.dart';
import './api_service.dart'; // Importación correcta

class UserSyncService {
  final CacheService cacheService;
  final ApiService apiService;

  UserSyncService({
    required this.cacheService,
    required this.apiService,
  });

  Future<bool> hasInternetConnection() async {
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity == ConnectivityResult.none) return false;
    return await apiService.checkServerStatus();
  }

  Future<Map<String, dynamic>> syncPendingUsers() async {
    if (!await hasInternetConnection()) {
      return {
        'success': false,
        'message': 'Sin conexión a internet',
        'synced': 0,
      };
    }

    try {
      print('🔄 Sincronizando usuarios pendientes...');
      int syncedCount = 0;

      return {
        'success': true,
        'message': 'Sincronización completada',
        'synced': syncedCount,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error en sincronización: $e',
        'synced': 0,
      };
    }
  }

  Future<void> autoSync() async {
    if (await hasInternetConnection()) {
      print('🌐 Conexión detectada - Sincronizando usuarios...');
      await syncPendingUsers();
    }
  }
}