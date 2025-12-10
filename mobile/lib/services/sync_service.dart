// lib/services/sync_service.dart
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/vacuna.dart';
import './vacuna_service.dart';
import './api_service.dart'; // Importación corregida

class SyncService {
  final VacunaService vacunaService;
  final ApiService apiService;

  SyncService({
    required this.vacunaService,
    required this.apiService,
  });

  // Verificar conectividad
  Future<bool> hasInternetConnection() async {
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity == ConnectivityResult.none) {
      return false;
    }
    
    // Verificar que el servidor esté respondiendo
    return await apiService.checkServerStatus();
  }

  // Sincronizar vacunas pendientes
  Future<Map<String, dynamic>> syncPendingVacunas() async {
    if (!await hasInternetConnection()) {
      return {
        'success': false,
        'message': 'No hay conexión a internet',
        'synced': 0,
      };
    }

    try {
      final pendingVacunas = await vacunaService.getUnsyncedVacunas();
      int syncedCount = 0;

      for (final vacuna in pendingVacunas) {
        final result = await apiService.syncVacuna(vacuna);
        
        if (result['success']) {
          final serverData = result['data'];
          await vacunaService.markVacunaAsSynced(
            vacuna.id!, 
            serverData['id']
          );
          syncedCount++;
          print('✅ Vacuna sincronizada: ${vacuna.nombrePaciente}');
        } else {
          print('❌ Error sincronizando vacuna: ${result['error']}');
        }
      }

      return {
        'success': true,
        'message': 'Sincronizadas $syncedCount vacunas',
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

  // Sincronización completa
  Future<Map<String, dynamic>> fullSync() async {
    if (!await hasInternetConnection()) {
      return {
        'success': false,
        'message': 'No hay conexión a internet',
      };
    }

    try {
      print('🔄 Iniciando sincronización completa...');
      
      final uploadResult = await syncPendingVacunas();
      
      return {
        'success': uploadResult['success'],
        'message': uploadResult['message'],
        'uploaded': uploadResult['synced'],
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error en sincronización completa: $e',
      };
    }
  }

  // Métodos de compatibilidad
  Future<bool> checkConnectivity() async {
    return await hasInternetConnection();
  }

  Future<void> syncAllData() async {
    await fullSync();
  }
}