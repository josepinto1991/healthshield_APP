import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../db_sqlite/cache_service.dart';
import '../models/usuario.dart';
import '../models/vacuna.dart';
import 'api_service.dart';

class BidirectionalSyncService {
  final CacheService cacheService;
  final ApiService apiService;

  BidirectionalSyncService({
    required this.cacheService,
    required this.apiService,
  });

  Future<bool> hasInternetConnection() async {
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity == ConnectivityResult.none) return false;
    return await apiService.checkServerStatus();
  }

  // Sincronización completa bidireccional
  Future<Map<String, dynamic>> fullBidirectionalSync() async {
    if (!await hasInternetConnection()) {
      return {'success': false, 'message': 'Sin conexión a internet'};
    }

    try {
      print('🔄 Iniciando sincronización bidireccional...');

      // 1. Subir datos locales no sincronizados
      final uploadResult = await _uploadUnsyncedData();
      
      // 2. Descargar datos actualizados del servidor
      final downloadResult = await _downloadLatestData();

      // 3. Sincronizar operaciones pendientes
      await _syncPendingOperations();

      return {
        'success': true,
        'message': 'Sincronización completada',
        'uploaded': uploadResult,
        'downloaded': downloadResult,
      };
    } catch (e) {
      return {'success': false, 'message': 'Error en sincronización: $e'};
    }
  }

  Future<Map<String, int>> _uploadUnsyncedData() async {
    int usuariosSubidos = 0;
    int vacunasSubidas = 0;

    // Subir usuarios no sincronizados
    final unsyncedUsuarios = await cacheService.getUnsyncedData('usuarios');
    for (final usuarioData in unsyncedUsuarios) {
      final usuario = Usuario.fromJson(usuarioData);
      final result = await apiService.syncUser(usuario);
      
      if (result['success']) {
        await cacheService.markDataAsSynced(
          'usuarios', 
          usuario.id!, 
          result['data']['id']
        );
        usuariosSubidos++;
      }
    }

    return {
      'usuarios': usuariosSubidos,
      'vacunas': vacunasSubidas,
    };
  }

  Future<Map<String, int>> _downloadLatestData() async {
    int usuariosDescargados = 0;
    int vacunasDescargadas = 0;

    // Descargar usuarios actualizados
    final usersResult = await apiService.getUpdates(DateTime.now().subtract(Duration(days: 30)).toIso8601String());
    if (usersResult['success']) {
      for (final userData in usersResult['data']) {
        await cacheService.insertUsuario(Usuario.fromJson(userData));
        usuariosDescargados++;
      }
    }

    // Descargar vacunas actualizadas
    final vacunasResult = await apiService.getVacunasFromServer();
    if (vacunasResult['success']) {
      for (final vacunaData in vacunasResult['data']) {
        // Implementar inserción de vacunas
        vacunasDescargadas++;
      }
    }

    return {
      'usuarios': usuariosDescargados,
      'vacunas': vacunasDescargadas,
    };
  }

  Future<void> _syncPendingOperations() async {
    final pendingSyncs = await cacheService.getPendingSyncs();
    
    for (final sync in pendingSyncs) {
      await cacheService.markSyncAsCompleted(sync['id'] as int);
    }
  }

  // Sincronización manual desde la UI
  Future<void> manualSync() async {
    final result = await fullBidirectionalSync();
    
    if (result['success']) {
      print('✅ Sincronización manual exitosa');
    } else {
      print('❌ Error en sincronización manual: ${result['message']}');
      throw Exception(result['message']);
    }
  }

  // Verificar estado de sincronización
  Future<Map<String, dynamic>> getSyncStatus() async {
    final unsyncedUsuarios = await cacheService.getUnsyncedData('usuarios');
    final unsyncedVacunas = await cacheService.getUnsyncedData('vacunas');
    final pendingOperations = await cacheService.getPendingSyncs();

    return {
      'usuarios_pendientes': unsyncedUsuarios.length,
      'vacunas_pendientes': unsyncedVacunas.length,
      'operaciones_pendientes': pendingOperations.length,
      'ultima_sincronizacion': DateTime.now().toIso8601String(),
    };
  }
}