import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../db_sqlite/cache_service.dart';
import '../services/vacuna_service.dart';
import '../models/usuario.dart';
import '../models/vacuna.dart';
import 'api_service.dart';

class BidirectionalSyncService {
  final CacheService cacheService;
  final ApiService apiService;
  final VacunaService vacunaService;

  BidirectionalSyncService({
    required this.cacheService,
    required this.apiService,
    required this.vacunaService,
  });

  // 🔥 Verificar conexión a internet
  Future<bool> hasInternetConnection() async {
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity == ConnectivityResult.none) return false;
    return await apiService.checkServerStatus();
  }

  // 🔥 Sincronización completa bidireccional (usuarios + vacunas)
  Future<Map<String, dynamic>> fullBidirectionalSync() async {
    if (!await hasInternetConnection()) {
      return {
        'success': false, 
        'message': 'Sin conexión a internet',
        'synced_users': 0,
        'synced_vacunas': 0
      };
    }

    try {
      print('🔄 Iniciando sincronización completa (usuarios + vacunas)...');

      int usuariosSincronizados = 0;
      int vacunasSincronizadas = 0;
      List<String> errores = [];
      List<String> exitosos = [];

      // 🔥 1. Sincronizar usuarios
      try {
        print('👥 Sincronizando usuarios...');
        final usuariosResult = await _syncUsuariosCompleto();
        usuariosSincronizados = usuariosResult['synced'] ?? 0;
        final usuariosExitosos = usuariosResult['successful'] as List<String>?;
        if (usuariosExitosos != null) {
          exitosos.addAll(usuariosExitosos);
        }
        if (usuariosResult['errors'] != null) {
          errores.addAll((usuariosResult['errors'] as List).cast<String>());
        }
      } catch (e) {
        print('❌ Error sincronizando usuarios: $e');
        errores.add('Error usuarios: $e');
      }

      // 🔥 2. Sincronizar vacunas
      try {
        print('💉 Sincronizando vacunas...');
        final vacunasResult = await _syncVacunasCompleto();
        vacunasSincronizadas = vacunasResult['synced'] ?? 0;
        if (vacunasResult['errors'] != null) {
          errores.addAll((vacunasResult['errors'] as List).cast<String>());
        }
      } catch (e) {
        print('❌ Error sincronizando vacunas: $e');
        errores.add('Error vacunas: $e');
      }

      final totalSincronizado = usuariosSincronizados + vacunasSincronizadas;
      final success = totalSincronizado > 0 || (usuariosSincronizados == 0 && vacunasSincronizadas == 0);

      return {
        'success': success,
        'message': success 
            ? 'Sincronización completada: $usuariosSincronizados usuarios, $vacunasSincronizadas vacunas'
            : 'Sincronización fallida',
        'synced_users': usuariosSincronizados,
        'synced_vacunas': vacunasSincronizadas,
        'total_synced': totalSincronizado,
        'successful': exitosos,
        'errors': errores.isNotEmpty ? errores : null,
        'timestamp': DateTime.now().toIso8601String(),
      };
        
    } catch (e) {
      return {
        'success': false,
        'message': 'Error en sincronización: $e',
        'synced_users': 0,
        'synced_vacunas': 0,
        'total_synced': 0,
        'errors': [e.toString()],
      };
    }
  }

  // 🔥 MÉTODO COMPLETO PARA SINCRONIZAR USUARIOS
  Future<Map<String, dynamic>> _syncUsuariosCompleto() async {
    try {
      final usuarios = await cacheService.getUsuarios();
      final unsyncedUsuarios = usuarios.where((u) => !u.isSynced).toList();
      
      if (unsyncedUsuarios.isEmpty) {
        return {'synced': 0, 'message': 'No hay usuarios pendientes'};
      }

      int syncedCount = 0;
      List<String> errores = [];
      List<String> exitosos = [];

      print('👥 Procesando ${unsyncedUsuarios.length} usuarios...');

      // 🔥 OBTENER TOKEN DE AUTENTICACIÓN PRIMERO
      String? token;
      try {
        // Intentar autenticar con admin primero
        final loginResult = await apiService.login('admin', 'admin123');
        if (!loginResult['success']) {
          print('❌ No se pudo autenticar con admin');
          return {'synced': 0, 'errors': ['Error de autenticación con admin']};
        }
        
        token = loginResult['data']['token'];
        apiService.token = token;
        print('✅ Token obtenido para sincronización de usuarios');
        
      } catch (e) {
        print('❌ Error obteniendo token: $e');
        return {'synced': 0, 'errors': ['Error de autenticación: $e']};
      }

      for (final usuario in unsyncedUsuarios) {
        try {
          print('🔄 Sincronizando usuario: ${usuario.username} (${usuario.email})');
          
          // 🔥 REGISTRAR USUARIO EN EL BACKEND
          final registroResult = await apiService.register(usuario);
          
          if (registroResult['success']) {
            final serverData = registroResult['data'];
            int? serverId;
            
            // Buscar el ID del servidor en diferentes formatos
            if (serverData['id'] != null) {
              serverId = serverData['id'] is int ? serverData['id'] : int.tryParse(serverData['id'].toString());
            } else if (serverData['user_id'] != null) {
              serverId = serverData['user_id'] is int ? serverData['user_id'] : int.tryParse(serverData['user_id'].toString());
            } else if (serverData['server_id'] != null) {
              serverId = serverData['server_id'] is int ? serverData['server_id'] : int.tryParse(serverData['server_id'].toString());
            }
            
            // Actualizar usuario con ID del servidor
            final updatedUser = usuario.copyWith(
              serverId: serverId,
              isSynced: true,
              updatedAt: DateTime.now(),
            );
            
            await cacheService.actualizarUsuario(updatedUser);
            syncedCount++;
            exitosos.add('${usuario.username} (nuevo)');
            print('✅ Usuario sincronizado: ${usuario.username}');
            
          } else {
            // 🔥 MANEJAR CASO DONDE USUARIO YA EXISTE
            final error = registroResult['error']?.toString() ?? '';
            final statusCode = registroResult['statusCode'];
            
            if (error.contains('ya existe') || 
                error.contains('already exists') || 
                error.contains('Duplicate') ||
                statusCode == 409 || // Conflict
                statusCode == 400) { // Bad Request (posiblemente ya existe)
              
              print('ℹ️ Usuario ${usuario.username} ya existe en el servidor');
              
              // Intentar obtener el ID del servidor mediante login
              try {
                final loginUserResult = await apiService.login(usuario.username, usuario.password);
                if (loginUserResult['success']) {
                  final userData = loginUserResult['data']['user'];
                  final serverId = userData['id'];
                  
                  if (serverId != null) {
                    final updatedUser = usuario.copyWith(
                      serverId: serverId,
                      isSynced: true,
                      updatedAt: DateTime.now(),
                    );
                    
                    await cacheService.actualizarUsuario(updatedUser);
                    syncedCount++;
                    exitosos.add('${usuario.username} (ya existía)');
                    print('✅ Usuario marcado como sincronizado: ${usuario.username}');
                  }
                } else {
                  // Si no podemos verificar, al menos marcar como sincronizado
                  final updatedUser = usuario.copyWith(
                    isSynced: true,
                    updatedAt: DateTime.now(),
                  );
                  
                  await cacheService.actualizarUsuario(updatedUser);
                  syncedCount++;
                  exitosos.add('${usuario.username} (marcado)');
                  print('⚠️ Usuario marcado como sincronizado sin verificación: ${usuario.username}');
                }
              } catch (loginError) {
                // Si falla el login, marcar de todos modos
                final updatedUser = usuario.copyWith(
                  isSynced: true,
                  updatedAt: DateTime.now(),
                );
                
                await cacheService.actualizarUsuario(updatedUser);
                syncedCount++;
                exitosos.add('${usuario.username} (marcado manual)');
                print('⚠️ Usuario marcado manualmente: ${usuario.username}');
              }
            } else {
              // Error real
              print('❌ Error sincronizando usuario ${usuario.username}: $error');
              errores.add('${usuario.username}: $error');
            }
          }
        } catch (e) {
          print('❌ Error procesando usuario ${usuario.username}: $e');
          errores.add('${usuario.username}: $e');
        }
      }

      return {
        'synced': syncedCount,
        'total': unsyncedUsuarios.length,
        'successful': exitosos,
        'errors': errores.isNotEmpty ? errores : null,
        'message': 'Sincronizados $syncedCount de ${unsyncedUsuarios.length} usuarios',
      };
    } catch (e) {
      return {'synced': 0, 'errors': ['Error general: ${e.toString()}']};
    }
  }

  // 🔥 MÉTODO COMPLETO PARA SINCRONIZAR VACUNAS
  Future<Map<String, dynamic>> _syncVacunasCompleto() async {
    try {
      final vacunas = await vacunaService.getVacunas();
      final unsyncedVacunas = vacunas.where((v) => !v.isSynced).toList();
      
      if (unsyncedVacunas.isEmpty) {
        return {'synced': 0, 'message': 'No hay vacunas pendientes'};
      }

      int syncedCount = 0;
      List<String> errores = [];

      print('💉 Enviando ${unsyncedVacunas.length} vacunas...');

      // 🔥 OBTENER TOKEN DE AUTENTICACIÓN PRIMERO
      String? token;
      try {
        final loginResult = await apiService.login('admin', 'admin123');
        if (!loginResult['success']) {
          print('❌ No se pudo obtener token de autenticación');
          return {
            'synced': 0,
            'errors': ['No se pudo autenticar con el servidor'],
            'message': 'Error de autenticación. Verifica credenciales.'
          };
        }
        
        token = loginResult['data']['token'];
        apiService.token = token;
        print('✅ Token obtenido para sincronización de vacunas');
        
      } catch (e) {
        print('❌ Error obteniendo token: $e');
        return {
          'synced': 0,
          'errors': ['Error de autenticación: $e'],
        };
      }

      // 🔥 Intentar bulk sync primero
      try {
        print('🔄 Intentando bulk sync...');
        final bulkResult = await apiService.bulkSync(unsyncedVacunas);
        
        if (bulkResult['success']) {
          final data = bulkResult['data'];
          final vacunasIds = data['vacunas_ids'] ?? {};
          
          // Marcar vacunas como sincronizadas
          for (final vacuna in unsyncedVacunas) {
            try {
              final localIdStr = vacuna.id?.toString();
              if (localIdStr != null && vacunasIds.containsKey(localIdStr)) {
                final serverInfo = vacunasIds[localIdStr];
                final serverId = serverInfo['server_id'];
                
                if (serverId != null) {
                  await vacunaService.markVacunaAsSynced(
                    vacuna.id!,
                    serverId is int ? serverId : int.tryParse(serverId.toString()) ?? 0
                  );
                  syncedCount++;
                  print('✅ Vacuna sincronizada: ${vacuna.nombrePaciente}');
                }
              }
            } catch (e) {
              print('⚠️ Error marcando vacuna como sincronizada: $e');
              errores.add('Error marcando vacuna: $e');
            }
          }
          
          return {
            'synced': syncedCount,
            'total': unsyncedVacunas.length,
            'method': 'bulk_sync',
            'errors': syncedCount < unsyncedVacunas.length ? ['Algunas vacunas no se sincronizaron'] : null,
          };
        } else {
          print('⚠️ Bulk sync falló: ${bulkResult['error']}');
          errores.add('Bulk sync: ${bulkResult['error']}');
        }
      } catch (e) {
        print('⚠️ Bulk sync falló con excepción: $e');
        errores.add('Excepción bulk sync: $e');
      }

      // 🔥 Si bulk sync falla, intentar una por una
      print('🔄 Intentando sincronización individual...');
      for (final vacuna in unsyncedVacunas) {
        try {
          print('📤 Sincronizando vacuna: ${vacuna.nombrePaciente}');
          final result = await apiService.crearVacuna(vacuna);
          
          if (result['success'] && result['data'] != null) {
            final serverData = result['data'];
            final serverId = serverData['id'] ?? serverData['server_id'];
            
            if (serverId != null) {
              await vacunaService.markVacunaAsSynced(
                vacuna.id!,
                serverId is int ? serverId : int.tryParse(serverId.toString()) ?? 0
              );
              syncedCount++;
              print('✅ Vacuna sincronizada: ${vacuna.nombrePaciente}');
            }
          } else {
            final error = result['error'] ?? 'Error desconocido';
            print('❌ Error vacuna ${vacuna.nombrePaciente}: $error');
            errores.add('${vacuna.nombrePaciente}: $error');
          }
        } catch (e) {
          print('❌ Error sincronizando vacuna ${vacuna.nombrePaciente}: $e');
          errores.add('${vacuna.nombrePaciente}: $e');
        }
      }

      return {
        'synced': syncedCount,
        'total': unsyncedVacunas.length,
        'method': 'individual_sync',
        'errors': errores.isNotEmpty ? errores : null,
      };
    } catch (e) {
      return {'synced': 0, 'errors': [e.toString()]};
    }
  }

  // 🔥 Sincronización manual desde la UI
  Future<Map<String, dynamic>> manualSync() async {
    return await fullBidirectionalSync();
  }

  // 🔥 Verificar estado de sincronización
  Future<Map<String, dynamic>> getSyncStatus() async {
    try {
      final usuarios = await cacheService.getUsuarios();
      final unsyncedUsuarios = usuarios.where((u) => !u.isSynced).length;
      
      final vacunas = await vacunaService.getVacunas();
      final unsyncedVacunas = vacunas.where((v) => !v.isSynced).length;
      
      return {
        'usuarios_pendientes': unsyncedUsuarios,
        'vacunas_pendientes': unsyncedVacunas,
        'total_pendientes': unsyncedUsuarios + unsyncedVacunas,
        'ultima_sincronizacion': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      return {
        'usuarios_pendientes': 0,
        'vacunas_pendientes': 0,
        'total_pendientes': 0,
        'error': e.toString(),
      };
    }
  }

  // 🔥 MÉTODO SIMPLIFICADO PARA SINCRONIZAR SOLO VACUNAS
  Future<Map<String, dynamic>> syncOnlyVacunas() async {
    if (!await hasInternetConnection()) {
      return {
        'success': false, 
        'message': 'Sin conexión a internet',
        'synced': 0
      };
    }

    try {
      print('💉 Sincronizando solo vacunas...');
      return await _syncVacunasCompleto();
    } catch (e) {
      return {
        'success': false,
        'message': 'Error sincronizando vacunas: $e',
        'synced': 0,
      };
    }
  }

  // 🔥 MÉTODO SIMPLIFICADO PARA SINCRONIZAR SOLO USUARIOS
  Future<Map<String, dynamic>> syncOnlyUsuarios() async {
    if (!await hasInternetConnection()) {
      return {
        'success': false, 
        'message': 'Sin conexión a internet',
        'synced': 0
      };
    }

    try {
      print('👥 Sincronizando solo usuarios...');
      return await _syncUsuariosCompleto();
    } catch (e) {
      return {
        'success': false,
        'message': 'Error sincronizando usuarios: $e',
        'synced': 0,
      };
    }
  }
}