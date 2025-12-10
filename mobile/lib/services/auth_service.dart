import '../db_sqlite/cache_service.dart';
import '../models/usuario.dart';
import 'api_service.dart';

class AuthService {
  final CacheService cacheService;
  Usuario? _currentUser;
  final ApiService _apiService = ApiService();

  AuthService({required this.cacheService});

  // ✅ CORRECTO: currentUser es una propiedad getter, no un método
  Usuario? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  bool get isAdmin => _currentUser?.isAdmin ?? false;

  Future<void> init() async {
    print('🚀 Inicializando AuthService');
    
    // Cargar usuario actual al iniciar
    _currentUser = await cacheService.getUsuarioActual();
    
    // Crear usuario admin si no existe
    await _ensureAdminUser();
    
    print('✅ AuthService inicializado');
  }

  Future<void> _ensureAdminUser() async {
    final usuarios = await getUsuarios();
    final adminExists = usuarios.any((user) => user.username == 'admin');
    
    if (!adminExists) {
      print('⚠️ Creando usuario admin por defecto...');
      final adminUser = Usuario(
        id: null,
        serverId: null,
        username: 'admin',
        email: 'admin@healthshield.com',
        password: 'admin123',
        telefono: '123456789',
        isProfessional: true,
        professionalLicense: 'ADM-001',
        isVerified: true,
        role: 'admin',
        isSynced: true,
        createdAt: DateTime.now(),
      );
      
      await registrarUsuarioLocal(adminUser);
      _currentUser = adminUser;
      print('✅ Usuario admin creado');
    }
  }

  // ========== REGISTRO LOCAL ==========
  Future<bool> registrarUsuarioLocal(Usuario usuario) async {
    try {
      final usuarios = await cacheService.getUsuarios();
      final existingUser = usuarios.firstWhere(
        (u) => u.username == usuario.username || u.email == usuario.email,
        orElse: () => Usuario.empty(),
      );

      if (!existingUser.isEmpty) {
        print('⚠️ Usuario ya existe localmente');
        return false;
      }

      await cacheService.insertUsuario(usuario);
      return true;
    } catch (e) {
      print('❌ Error registrando usuario local: $e');
      return false;
    }
  }

  // ✅ AÑADIR: Método necesario para admin_usuarios_screen.dart
  Future<bool> registrarUsuario(Usuario usuario) async {
    return await registrarUsuarioLocal(usuario);
  }

  Future<Map<String, dynamic>> registrarUsuarioProfesional({
    required Usuario usuario,
    required String cedulaVerificacion,
  }) async {
    try {
      final usuarios = await cacheService.getUsuarios();
      final existsLocally = usuarios.any((u) => 
        u.username == usuario.username || u.email == usuario.email);
      
      if (existsLocally) {
        return {
          'success': false,
          'error': 'Usuario ya existe en el sistema',
          'isOffline': true,
        };
      }

      bool verificationSuccessful = false;
      Map<String, dynamic> verificationResult = {};
      
      final hasConnection = await _checkInternetConnection();
      
      if (hasConnection) {
        print('🌐 Verificando profesional en línea...');
        verificationResult = await _apiService.verifyProfessional(cedulaVerificacion);
        verificationSuccessful = verificationResult['success'] ?? false;
        
        if (!verificationSuccessful) {
          return {
            'success': false,
            'error': verificationResult['message'] ?? 'Error en verificación',
            'isOffline': false,
          };
        }
      } else {
        print('📴 Modo offline - Saltando verificación inicial');
        verificationSuccessful = true;
      }

      if (hasConnection && verificationSuccessful) {
        return await _registrarProfesionalOnline(usuario, cedulaVerificacion, verificationResult);
      } else {
        return await _registrarProfesionalOffline(usuario, cedulaVerificacion);
      }
    } catch (e) {
      print('❌ Error registrando profesional: $e');
      return {
        'success': false,
        'error': 'Error inesperado: $e',
        'isOffline': true,
      };
    }
  }

  Future<Map<String, dynamic>> _registrarProfesionalOnline(
    Usuario usuario, 
    String cedulaVerificacion,
    Map<String, dynamic> verificationResult
  ) async {
    try {
      final registerResult = await _apiService.registerProfessional(usuario, cedulaVerificacion);
      
      if (registerResult['success']) {
        final userData = registerResult['data']['user'];
        final serverToken = registerResult['data']['token'];
        
        final localUser = Usuario(
          id: null,
          serverId: userData['id'],
          username: userData['username'] ?? usuario.username,
          email: userData['email'] ?? usuario.email,
          password: usuario.password,
          telefono: userData['telefono'] ?? usuario.telefono,
          isProfessional: true,
          professionalLicense: verificationResult['professional_license'] ?? usuario.professionalLicense,
          isVerified: true,
          role: 'professional',
          isSynced: true,
          createdAt: DateTime.parse(userData['created_at'] ?? DateTime.now().toIso8601String()),
        );
        
        await registrarUsuarioLocal(localUser);
        _apiService.token = serverToken;
        _currentUser = localUser;
        
        return {
          'success': true,
          'message': 'Profesional registrado exitosamente',
          'user': localUser,
          'token': serverToken,
          'isOffline': false,
          'requiresSync': false,
        };
      } else {
        return {
          'success': false,
          'error': registerResult['error'],
          'isOffline': false,
        };
      }
    } catch (e) {
      print('❌ Error en registro online, intentando offline: $e');
      return await _registrarProfesionalOffline(usuario, cedulaVerificacion);
    }
  }

  Future<Map<String, dynamic>> _registrarProfesionalOffline(
    Usuario usuario, 
    String cedulaVerificacion
  ) async {
    try {
      final professionalUser = Usuario(
        id: null,
        serverId: null,
        username: usuario.username,
        email: usuario.email,
        password: usuario.password,
        telefono: usuario.telefono,
        isProfessional: true,
        professionalLicense: usuario.professionalLicense,
        isVerified: false,
        role: 'professional',
        isSynced: false,
        createdAt: DateTime.now(),
      );
      
      final success = await registrarUsuarioLocal(professionalUser);
      
      if (success) {
        await _guardarVerificacionPendiente(professionalUser, cedulaVerificacion);
        
        return {
          'success': true,
          'message': 'Profesional registrado offline. Se sincronizará cuando haya conexión.',
          'user': professionalUser,
          'isOffline': true,
          'requiresSync': true,
        };
      } else {
        return {
          'success': false,
          'error': 'Error guardando usuario localmente',
          'isOffline': true,
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Error en registro offline: $e',
        'isOffline': true,
      };
    }
  }

  Future<void> _guardarVerificacionPendiente(Usuario usuario, String cedula) async {
    try {
      final db = await cacheService.getDatabase();
      
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='pending_verifications'"
      );
      
      if (tables.isEmpty) {
        await db.execute('''
          CREATE TABLE pending_verifications (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            usuario_id INTEGER NOT NULL,
            cedula TEXT NOT NULL,
            created_at TEXT NOT NULL
          )
        ''');
      }
      
      await db.insert('pending_verifications', {
        'usuario_id': usuario.id,
        'cedula': cedula,
        'created_at': DateTime.now().toIso8601String(),
      });
      print('📝 Verificación pendiente guardada para usuario ${usuario.username}');
    } catch (e) {
      print('❌ Error guardando verificación pendiente: $e');
    }
  }

  Future<Map<String, dynamic>> loginUsuario(String username, String password) async {
    try {
      final offlineUser = await cacheService.getUsuarioByCredentials(username, password);
      if (offlineUser != null) {
        _currentUser = offlineUser;
        
        if (offlineUser.username == 'admin' && offlineUser.password == 'admin123') {
          final adminUser = offlineUser.copyWith(role: 'admin');
          _currentUser = adminUser;
          await cacheService.actualizarUsuario(adminUser);
        }
        
        return {
          'success': true,
          'user': _currentUser,
          'message': 'Login offline exitoso',
          'isOffline': true,
        };
      }

      final hasConnection = await _checkInternetConnection();
      if (hasConnection) {
        final onlineResult = await _apiService.login(username, password);
        
        if (onlineResult['success']) {
          final userData = onlineResult['data']['user'];
          final user = Usuario(
            id: null,
            serverId: userData['id'],
            username: userData['username'],
            email: userData['email'],
            password: password,
            telefono: userData['telefono'],
            isProfessional: userData['is_professional'] ?? false,
            professionalLicense: userData['professional_license'],
            isVerified: userData['is_verified'] ?? false,
            role: userData['role'] ?? 'user',
            isSynced: true,
            createdAt: DateTime.parse(userData['created_at']),
            updatedAt: userData['updated_at'] != null 
                ? DateTime.parse(userData['updated_at'])
                : null,
          );
          
          await cacheService.insertUsuario(user);
          _currentUser = user;
          
          return {
            'success': true,
            'user': user,
            'message': 'Login online exitoso',
            'isOffline': false,
          };
        }
      }

      return {
        'success': false,
        'error': 'Usuario o contraseña incorrectos',
      };
    } catch (e) {
      print('❌ Error en login: $e');
      return {
        'success': false,
        'error': 'Error en el servidor: $e',
      };
    }
  }

  Future<bool> _checkInternetConnection() async {
    try {
      return await _apiService.checkServerStatus();
    } catch (e) {
      return false;
    }
  }

  Future<bool> actualizarUsuario(Usuario usuario) async {
    try {
      final success = await cacheService.actualizarUsuario(usuario);
      if (success && usuario.id == _currentUser?.id) {
        _currentUser = usuario;
      }
      return success;
    } catch (e) {
      print('❌ Error actualizando usuario: $e');
      return false;
    }
  }

  Future<bool> cambiarPassword(int usuarioId, String nuevaPassword) async {
    try {
      final usuario = await cacheService.getUsuarioById(usuarioId);
      if (usuario == null) return false;
      
      final usuarioActualizado = usuario.copyWith(password: nuevaPassword);
      return await cacheService.actualizarUsuario(usuarioActualizado);
    } catch (e) {
      print('❌ Error cambiando password: $e');
      return false;
    }
  }

  Future<List<Usuario>> getUsuarios() async {
    try {
      return await cacheService.getUsuarios();
    } catch (e) {
      print('❌ Error obteniendo usuarios: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> syncOfflineUsers() async {
    try {
      final hasConnection = await _checkInternetConnection();
      if (!hasConnection) {
        return {
          'success': false,
          'message': 'No hay conexión a internet',
          'synced': 0,
        };
      }

      final db = await cacheService.getDatabase();
      final pendingVerifications = await db.query('pending_verifications');
      int syncedCount = 0;

      for (final verification in pendingVerifications) {
        final userId = verification['usuario_id'] as int;
        final cedula = verification['cedula'] as String;
        
        final user = await cacheService.getUsuarioById(userId);
        if (user == null) continue;
        
        try {
          final verificationResult = await _apiService.verifyProfessional(cedula);
          
          if (verificationResult['success'] ?? false) {
            final registerResult = await _apiService.registerProfessional(user, cedula);
            
            if (registerResult['success']) {
              final serverData = registerResult['data']['user'];
              
              final updatedUser = user.copyWith(
                serverId: serverData['id'],
                isVerified: true,
                isSynced: true,
                professionalLicense: verificationResult['professional_license'] ?? user.professionalLicense,
              );
              
              await cacheService.actualizarUsuario(updatedUser);
              
              await db.delete(
                'pending_verifications',
                where: 'id = ?',
                whereArgs: [verification['id']],
              );
              
              syncedCount++;
              print('✅ Usuario profesional sincronizado: ${user.username}');
            }
          }
        } catch (e) {
          print('❌ Error sincronizando usuario ${user.username}: $e');
        }
      }

      return {
        'success': true,
        'message': 'Sincronizados $syncedCount usuarios',
        'synced': syncedCount,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error sincronizando usuarios: $e',
        'synced': 0,
      };
    }
  }

  Future<void> logout() async {
    try {
      _currentUser = null;
      _apiService.token = null;
      await cacheService.clearSensitiveData();
      print('✅ Sesión cerrada exitosamente');
    } catch (e) {
      print('❌ Error en logout: $e');
    }
  }

  Future<void> close() async {
    await cacheService.close();
  }
}