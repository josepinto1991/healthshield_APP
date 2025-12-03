// lib/services/sync_service.dart
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/vacuna.dart';
import 'vacuna_service.dart';
import 'api_service.dart';

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

  // Descargar vacunas actualizadas del servidor
  Future<Map<String, dynamic>> downloadLatestVacunas() async {
    if (!await hasInternetConnection()) {
      return {
        'success': false,
        'message': 'No hay conexión a internet',
        'downloaded': 0,
      };
    }

    try {
      final result = await apiService.getVacunasFromServer();
      
      if (result['success']) {
        final List<dynamic> serverVacunas = result['data'];
        int downloadedCount = 0;

        for (final serverVacuna in serverVacunas) {
          await vacunaService.saveVacunaFromServer(
            Vacuna.fromJson(serverVacuna)
          );
          downloadedCount++;
        }

        return {
          'success': true,
          'message': 'Descargadas $downloadedCount vacunas',
          'downloaded': downloadedCount,
        };
      } else {
        return {
          'success': false,
          'message': result['error'],
          'downloaded': 0,
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error descargando vacunas: $e',
        'downloaded': 0,
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

      // 1. Subir vacunas pendientes
      final uploadResult = await syncPendingVacunas();
      
      // 2. Descargar vacunas actualizadas
      final downloadResult = await downloadLatestVacunas();

      return {
        'success': uploadResult['success'] && downloadResult['success'],
        'message': '${uploadResult['message']} | ${downloadResult['message']}',
        'uploaded': uploadResult['synced'],
        'downloaded': downloadResult['downloaded'],
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error en sincronización completa: $e',
      };
    }
  }

  // Sincronización automática al iniciar la app
  Future<void> autoSync() async {
    if (await hasInternetConnection()) {
      print('🌐 Conexión detectada - Sincronizando automáticamente...');
      await fullSync();
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