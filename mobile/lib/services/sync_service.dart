import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'paciente_service.dart';
import 'vacuna_service.dart';
import 'api_service.dart';
import '../models/paciente.dart';
import '../models/vacuna.dart';

class SyncService {
  final PacienteService pacienteService;
  final VacunaService vacunaService;
  final ApiService apiService;

  SyncService({
    required this.pacienteService,
    required this.vacunaService,
    required this.apiService,
  });

  Future<bool> hasInternetConnection() async {
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity == ConnectivityResult.none) return false;
    
    try {
      return await apiService.checkServerStatus();
    } catch (e) {
      return false;
    }
  }

  // Sincronización completa
  Future<Map<String, dynamic>> syncAll() async {
    if (!await hasInternetConnection()) {
      return {
        'success': false,
        'message': 'Sin conexión a internet',
        'syncedPacientes': 0,
        'syncedVacunas': 0,
      };
    }

    try {
      print('🔄 Iniciando sincronización completa...');

      // 1. Obtener datos locales no sincronizados
      final unsyncedPacientes = await pacienteService.getUnsyncedPacientes();
      final unsyncedVacunas = await vacunaService.getUnsyncedVacunas();

      // 2. Convertir a formato para enviar al servidor
      final pacientesToUpload = unsyncedPacientes.map((p) => p.toServerJson()).toList();
      final vacunasToUpload = unsyncedVacunas.map((v) => v.toServerJson()).toList();

      // 3. Enviar al servidor
      final syncResult = await apiService.fullSync(
        pacientes: pacientesToUpload,
        vacunas: vacunasToUpload,
      );

      if (!syncResult['success']) {
        return {
          'success': false,
          'message': 'Error en sincronización: ${syncResult['error']}',
          'syncedPacientes': 0,
          'syncedVacunas': 0,
        };
      }

      final data = syncResult['data'];
      
      // 4. Procesar resultados de pacientes
      int pacientesSubidos = 0;
      if (data['upload_results']['pacientes'] != null) {
        for (final result in data['upload_results']['pacientes']) {
          if (result['success'] == true && result['local_id'] != null && result['server_id'] != null) {
            await pacienteService.markPacienteAsSynced(
              result['local_id'],
              result['server_id'],
            );
            pacientesSubidos++;
          }
        }
      }

      // 5. Procesar resultados de vacunas
      int vacunasSubidas = 0;
      if (data['upload_results']['vacunas'] != null) {
        for (final result in data['upload_results']['vacunas']) {
          if (result['success'] == true && result['local_id'] != null && result['server_id'] != null) {
            await vacunaService.markVacunaAsSynced(
              result['local_id'],
              result['server_id'],
            );
            vacunasSubidas++;
          }
        }
      }

      // 6. Descargar datos actualizados del servidor
      int pacientesDescargados = 0;
      int vacunasDescargadas = 0;
      
      if (data['download_data']['pacientes'] != null) {
        for (final pacienteData in data['download_data']['pacientes']) {
          await pacienteService.savePacienteFromServer(pacienteData);
          pacientesDescargados++;
        }
      }
      
      if (data['download_data']['vacunas'] != null) {
        for (final vacunaData in data['download_data']['vacunas']) {
          await vacunaService.saveVacunaFromServer(vacunaData);
          vacunasDescargadas++;
        }
      }

      return {
        'success': true,
        'message': 'Sincronización completada',
        'pacientesSubidos': pacientesSubidos,
        'vacunasSubidas': vacunasSubidas,
        'pacientesDescargados': pacientesDescargados,
        'vacunasDescargadas': vacunasDescargadas,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error en sincronización: $e',
        'syncedPacientes': 0,
        'syncedVacunas': 0,
      };
    }
  }

  // Sincronización manual desde la UI
  Future<Map<String, dynamic>> manualSync() async {
    final result = await syncAll();
    
    if (result['success']) {
      print('✅ Sincronización manual exitosa');
    } else {
      print('❌ Error en sincronización manual: ${result['message']}');
    }
    
    return result;
  }

  // Sincronización automática al iniciar la app
  Future<void> autoSync() async {
    if (await hasInternetConnection()) {
      print('🌐 Conexión detectada - Sincronizando automáticamente...');
      await syncAll();
    }
  }

  // Obtener estado de sincronización
  Future<Map<String, dynamic>> getSyncStatus() async {
    final unsyncedPacientes = await pacienteService.getUnsyncedPacientes();
    final unsyncedVacunas = await vacunaService.getUnsyncedVacunas();
    final hasConnection = await hasInternetConnection();

    return {
      'hasConnection': hasConnection,
      'pacientesPendientes': unsyncedPacientes.length,
      'vacunasPendientes': unsyncedVacunas.length,
      'totalPendientes': unsyncedPacientes.length + unsyncedVacunas.length,
      'ultimaSincronizacion': DateTime.now().toIso8601String(),
    };
  }
}