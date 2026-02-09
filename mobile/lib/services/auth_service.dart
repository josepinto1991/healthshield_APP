import '../db_sqlite/cache_service.dart';
import '../models/usuario.dart';
import 'api_service.dart';

class AuthService {
  final CacheService cacheService;
  Usuario? _currentUser;
  final ApiService _apiService = ApiService();

  AuthService({required this.cacheService});

  Usuario? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  bool get isAdmin => _currentUser?.isAdmin ?? false;

  Future<void> init() async {
    print('🚀 Inicializando AuthService');
    
    // Cargar usuario actual al iniciar
    _currentUser = await cacheService.getUsuarioActual();
    
    // 🔥 CREAR ADMIN SI NO EXISTE - CON MÁS LOGS
    await _ensureAdminUserWithLogs();
    
    print('✅ AuthService inicializado');
  }

  // 🔥 MÉTODO MEJORADO CON MÁS LOGS
  Future<void> _ensureAdminUserWithLogs() async {
    print('🔍 Verificando usuario admin...');
    
    final usuarios = await getUsuarios();
    print('📊 Total usuarios en sistema: ${usuarios.length}');
    
    // Listar todos los usuarios para debug
    for (var i = 0; i < usuarios.length; i++) {
      final user = usuarios[i];
      print('👤 Usuario $i: ${user.username} | Email: ${user.email} | Rol: ${user.role} | ID: ${user.id}');
    }
    
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
      
      final success = await registrarUsuarioLocal(adminUser);
      if (success) {
        _currentUser = adminUser;
        print('✅ Usuario admin creado exitosamente');
        print('📋 Credenciales creadas:');
        print('   Usuario: admin');
        print('   Contraseña: admin123');
        print('   Email: admin@healthshield.com');
        print('   Rol: Administrador');
      } else {
        print('❌ Error creando usuario admin - Posible duplicado');
      }
    } else {
      print('✅ Usuario admin ya existe');
    }
  }

  // 🔥 MÉTODO PARA FORZAR CREACIÓN DE ADMIN (para diagnóstico)
  Future<bool> crearAdminForzado() async {
    try {
      print('🔄 Creando admin forzado...');
      
      // Obtener base de datos directamente
      final db = await cacheService.getDatabase();
      
      // Primero eliminar si existe
      try {
        await db.delete(
          'usuarios',
          where: 'username = ?',
          whereArgs: ['admin'],
        );
        print('🗑️ Admin anterior eliminado si existía');
      } catch (e) {
        print('ℹ️ No se pudo eliminar admin anterior: $e');
      }
      
      // Crear nuevo admin
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
      
      // Insertar directamente
      final adminId = await db.insert('usuarios', {
        'username': 'admin',
        'email': 'admin@healthshield.com',
        'password': 'admin123', // Nota: en producción esto debería estar hasheado
        'telefono': '123456789',
        'is_professional': 1,
        'professional_license': 'ADM-001',
        'is_verified': 1,
        'role': 'admin',
        'is_synced': 1,
        'created_at': DateTime.now().toIso8601String(),
      });
      
      if (adminId > 0) {
        _currentUser = adminUser;
        print('✅ Admin creado forzadamente con ID: $adminId');
        print('🔑 Credenciales: admin / admin123');
        return true;
      } else {
        print('❌ Error: No se pudo insertar admin');
        return false;
      }
    } catch (e) {
      print('❌ Error en crearAdminForzado: $e');
      return false;
    }
  }

  // 🔥 MÉTODO PARA DIAGNÓSTICO
  Future<void> diagnosticarUsuarios() async {
    print('=== DIAGNÓSTICO DE USUARIOS ===');
    
    try {
      final usuarios = await getUsuarios();
      print('📊 Total usuarios registrados: ${usuarios.length}');
      
      if (usuarios.isEmpty) {
        print('⚠️ No hay usuarios en la base de datos');
        return;
      }
      
      for (var i = 0; i < usuarios.length; i++) {
        final user = usuarios[i];
        print('--- Usuario ${i + 1} ---');
        print('ID: ${user.id}');
        print('Username: ${user.username}');
        print('Email: ${user.email}');
        print('Rol: ${user.role}');
        print('Es Admin: ${user.isAdmin}');
        print('Es Profesional: ${user.isProfessional}');
        print('Verificado: ${user.isVerified}');
        print('Sincronizado: ${user.isSynced}');
        print('');
      }
    } catch (e) {
      print('❌ Error en diagnóstico: $e');
    }
  }

  // ========== REGISTRO LOCAL SIMPLE ==========
  Future<bool> registrarUsuarioLocal(Usuario usuario) async {
    try {
      print('📝 Registrando usuario local: ${usuario.username} (Rol: ${usuario.role})');
      
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
      print('✅ Usuario registrado localmente: ${usuario.username} (Rol: ${usuario.role})');
      return true;
    } catch (e) {
      print('❌ Error registrando usuario local: $e');
      return false;
    }
  }

  Future<bool> registrarUsuario(Usuario usuario) async {
    return await registrarUsuarioLocal(usuario);
  }

  // ========== REGISTRO PROFESIONAL SIMPLIFICADO ==========
  Future<Map<String, dynamic>> registrarUsuarioProfesional({
    required Usuario usuario,
    String cedulaVerificacion = '',
  }) async {
    try {
      print('👨‍⚕️ Registrando usuario: ${usuario.username} (Rol: ${usuario.role})');
      
      // Validar que solo admins puedan crear otros admins
      if (usuario.role == 'admin' && !isAdmin) {
        return {
          'success': false,
          'error': 'Solo administradores pueden crear otros administradores',
          'isOffline': true,
        };
      }
      
      final usuarios = await cacheService.getUsuarios();
      final existsLocally = usuarios.any((u) => 
        u.username == usuario.username || u.email == usuario.email);
      
      if (existsLocally) {
        print('⚠️ Usuario ya existe en el sistema');
        return {
          'success': false,
          'error': 'Usuario ya existe en el sistema',
          'isOffline': true,
        };
      }

      // Asegurar que profesionales tengan isProfessional = true
      final isProfessionalUser = usuario.role == 'professional' || usuario.role == 'admin';
      
      final userToRegister = Usuario(
        id: null,
        serverId: null,
        username: usuario.username,
        email: usuario.email,
        password: usuario.password,
        telefono: usuario.telefono,
        isProfessional: isProfessionalUser,
        professionalLicense: usuario.professionalLicense,
        isVerified: true,
        role: usuario.role,
        isSynced: false,
        createdAt: DateTime.now(),
      );
      
      final success = await registrarUsuarioLocal(userToRegister);
      
      if (success) {
        print('✅ Usuario registrado exitosamente: ${usuario.username} (Rol: ${usuario.role})');
        return {
          'success': true,
          'message': 'Usuario registrado exitosamente',
          'user': userToRegister,
          'isOffline': true,
          'requiresSync': false,
        };
      } else {
        return {
          'success': false,
          'error': 'Error guardando usuario localmente',
          'isOffline': true,
        };
      }
    } catch (e) {
      print('❌ Error registrando usuario: $e');
      return {
        'success': false,
        'error': 'Error inesperado: $e',
        'isOffline': true,
      };
    }
  }

  // ========== LOGIN DUAL (ONLINE/OFFLINE) ==========
  Future<Map<String, dynamic>> loginUsuario(String username, String password) async {
    try {
      print('🔐 Intentando login para: $username');
      
      // Primero intentar login offline
      final offlineUser = await cacheService.getUsuarioByCredentials(username, password);
      if (offlineUser != null) {
        print('📱 Login offline exitoso para: $username');
        _currentUser = offlineUser;
        
        // Si es el usuario admin por defecto, asegurar rol admin
        if (offlineUser.username == 'admin' && offlineUser.password == 'admin123') {
          final adminUser = offlineUser.copyWith(role: 'admin');
          _currentUser = adminUser;
          await cacheService.actualizarUsuario(adminUser);
          print('👑 Usuario admin detectado, rol asegurado');
        }
        
        return {
          'success': true,
          'user': _currentUser,
          'message': 'Login offline exitoso',
          'isOffline': true,
        };
      }

      // Si no existe offline, verificar si hay conexión para login online
      final hasConnection = await _checkInternetConnection();
      if (hasConnection) {
        print('🌐 Intentando login online...');
        final onlineResult = await _apiService.login(username, password);
        
        if (onlineResult['success']) {
          print('✅ Login online exitoso');
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

      print('❌ Login fallido para: $username');
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
      final hasConnection = await _apiService.checkServerStatus();
      print(hasConnection ? '🌐 Conexión a internet disponible' : '📴 Sin conexión a internet');
      return hasConnection;
    } catch (e) {
      return false;
    }
  }

  // ========== GESTIÓN DE USUARIOS ==========
  Future<bool> actualizarUsuario(Usuario usuario) async {
    try {
      print('✏️ Actualizando usuario: ${usuario.username} (Rol: ${usuario.role})');
      
      // Validar que solo admins puedan convertir usuarios en admins
      if (usuario.role == 'admin' && !isAdmin && usuario.id != _currentUser?.id) {
        print('❌ Solo administradores pueden asignar rol de administrador');
        return false;
      }
      
      final success = await cacheService.actualizarUsuario(usuario);
      if (success && usuario.id == _currentUser?.id) {
        _currentUser = usuario;
        print('✅ Usuario actualizado (incluyendo usuario actual)');
      } else if (success) {
        print('✅ Usuario actualizado');
      }
      return success;
    } catch (e) {
      print('❌ Error actualizando usuario: $e');
      return false;
    }
  }

  Future<bool> cambiarPassword(int usuarioId, String nuevaPassword) async {
    try {
      print('🔐 Cambiando password para usuario ID: $usuarioId');
      final usuario = await cacheService.getUsuarioById(usuarioId);
      if (usuario == null) {
        print('❌ Usuario no encontrado');
        return false;
      }
      
      final usuarioActualizado = usuario.copyWith(password: nuevaPassword);
      return await cacheService.actualizarUsuario(usuarioActualizado);
    } catch (e) {
      print('❌ Error cambiando password: $e');
      return false;
    }
  }

  Future<List<Usuario>> getUsuarios() async {
    try {
      final usuarios = await cacheService.getUsuarios();
      print('📊 Obteniendo usuarios: ${usuarios.length} encontrados');
      return usuarios;
    } catch (e) {
      print('❌ Error obteniendo usuarios: $e');
      return [];
    }
  }

  // ========== SINCRONIZACIÓN SIMPLIFICADA ==========
  Future<Map<String, dynamic>> syncOfflineUsers() async {
    try {
      print('🔄 Sincronizando usuarios offline...');
      
      final hasConnection = await _checkInternetConnection();
      if (!hasConnection) {
        return {
          'success': false,
          'message': 'No hay conexión a internet',
          'synced': 0,
        };
      }

      // Solo sincronizar usuarios no sincronizados
      final usuarios = await cacheService.getUsuarios();
      final unsyncedUsers = usuarios.where((u) => !u.isSynced).toList();
      int syncedCount = 0;

      print('📊 Usuarios por sincronizar: ${unsyncedUsers.length}');

      for (final user in unsyncedUsers) {
        try {
          // Intentar registrar en el servidor
          final result = await _apiService.register(user);
          
          if (result['success']) {
            final serverData = result['data']['user'];
            
            final updatedUser = user.copyWith(
              serverId: serverData['id'],
              isSynced: true,
            );
            
            await cacheService.actualizarUsuario(updatedUser);
            syncedCount++;
            print('✅ Usuario sincronizado: ${user.username}');
          }
        } catch (e) {
          print('❌ Error sincronizando usuario ${user.username}: $e');
        }
      }

      return {
        'success': syncedCount > 0,
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

  // ========== ELIMINAR USUARIO ==========
  Future<bool> eliminarUsuario(int usuarioId) async {
    try {
      print('🗑️ Eliminando usuario ID: $usuarioId');
      
      // No permitir eliminar al usuario actual
      if (usuarioId == _currentUser?.id) {
        print('❌ No puedes eliminar tu propio usuario');
        return false;
      }
      
      final db = await cacheService.getDatabase();
      final deleted = await db.delete(
        'usuarios',
        where: 'id = ?',
        whereArgs: [usuarioId],
      );
      
      if (deleted > 0) {
        print('✅ Usuario eliminado exitosamente');
        return true;
      } else {
        print('❌ Usuario no encontrado');
        return false;
      }
    } catch (e) {
      print('❌ Error eliminando usuario: $e');
      return false;
    }
  }

  // ========== LOGOUT ==========
  Future<void> logout() async {
    try {
      print('🚪 Cerrando sesión...');
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

  // 🔥 MÉTODO PARA VERIFICAR ESTADO DEL ADMIN
  Future<bool> verificarAdmin() async {
    try {
      final usuarios = await getUsuarios();
      final adminExists = usuarios.any((user) => user.username == 'admin');
      
      if (adminExists) {
        final adminUser = usuarios.firstWhere((user) => user.username == 'admin');
        print('✅ Admin verificado:');
        print('   Username: ${adminUser.username}');
        print('   Email: ${adminUser.email}');
        print('   Rol: ${adminUser.role}');
        print('   ID: ${adminUser.id}');
        return true;
      } else {
        print('❌ Admin no encontrado');
        return false;
      }
    } catch (e) {
      print('❌ Error verificando admin: $e');
      return false;
    }
  }
}