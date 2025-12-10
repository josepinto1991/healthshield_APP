import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'user_sync_service.dart';
import 'sync_service.dart';

class AutoSyncManager {
  final UserSyncService userSyncService;
  final SyncService vacunaSyncService;
  final VoidCallback onSyncComplete;
  final VoidCallback onSyncError;

  AutoSyncManager({
    required this.userSyncService,
    required this.vacunaSyncService,
    required this.onSyncComplete,
    required this.onSyncError,
  });

  Future<void> checkAndSync() async {
    try {
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity != ConnectivityResult.none) {
        print('🌐 Conexión detectada - Iniciando sincronización automática...');
        
        // Sincronizar usuarios
        final userSyncResult = await userSyncService.syncPendingUsers();
        
        // Sincronizar vacunas
        final vacunaSyncResult = await vacunaSyncService.fullSync();
        
        if (userSyncResult['success'] || vacunaSyncResult['success']) {
          print('✅ Sincronización automática completada');
          onSyncComplete();
        } else {
          print('⚠️ Sincronización automática parcial');
          onSyncComplete();
        }
      }
    } catch (e) {
      print('❌ Error en sincronización automática: $e');
      onSyncError();
    }
  }

  Future<void> periodicSync() async {
    // Ejecutar cada 5 minutos si hay conexión
    await checkAndSync();
    
    // Programar siguiente sincronización
    Future.delayed(Duration(minutes: 5), () {
      periodicSync();
    });
  }
}