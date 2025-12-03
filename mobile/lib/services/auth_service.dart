import '../db_sqlite/cache_service.dart';
import '../models/usuario.dart';
import 'api_service.dart';

class AuthService {
  final CacheService cacheService;

  AuthService({required this.cacheService});

  Future<void> init() async {
    // La base de datos ya se inicializa en CacheService
  }

  // Registro de usuario normal
  Future<bool> registrarUsuario(Usuario usuario) async {
    try {
      // Verificar si el usuario ya existe
      final usuarios = await cacheService.getUsuarios();
      final existingUser = usuarios.firstWhere(
        (u) => u.username == usuario.username || u.email == usuario.email,
        orElse: () => Usuario.empty(),
      );

      if (!existingUser.isEmpty) {
        return false; // Usuario ya existe
      }

      await cacheService.insertUsuario(usuario);
      return true;
    } catch (e) {
      print('Error registrando usuario: $e');
      return false;
    }
  }

  // Registro de usuario profesional (requiere verificación online)
  Future<Map<String, dynamic>> registrarUsuarioProfesional({
    required Usuario usuario,
    required String cedulaVerificacion,
  }) async {
    try {
      final apiService = ApiService();
      
      // Verificar profesional online
      final verificationResult = await apiService.verifyProfessional(cedulaVerificacion);
      
      if (!verificationResult['success'] || !verificationResult['is_valid']) {
        return {
          'success': false,
          'error': verificationResult['message'] ?? 'Error en verificación',
        };
      }

      // Registrar en backend
      final registerResult = await apiService.registerProfessional(usuario, cedulaVerificacion);
      
      if (registerResult['success']) {
        // Guardar en cache local para login offline
        final userData = registerResult['data']['user'];
        final localUser = Usuario(
          id: null,
          serverId: userData['id'],
          username: userData['username'],
          email: userData['email'],
          password: usuario.password, // Guardar contraseña para login offline
          telefono: userData['telefono'],
          isProfessional: true,
          professionalLicense: userData['professional_license'],
          isVerified: true,
          isSynced: true,
          createdAt: DateTime.parse(userData['created_at']),
        );
        
        await cacheService.insertUsuario(localUser);
        
        return {
          'success': true,
          'message': 'Profesional registrado exitosamente',
          'user': localUser,
        };
      } else {
        return {
          'success': false,
          'error': registerResult['error'],
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Error registrando profesional: $e',
      };
    }
  }

  // Login de usuario (offline primero, luego online)
  Future<Map<String, dynamic>> loginUsuario(String username, String password) async {
    try {
      // Primero intentar login online
      final apiService = ApiService();
      final onlineResult = await apiService.login(username, password);
      
      if (onlineResult['success']) {
        // Guardar usuario en cache para futuro acceso offline
        final userData = onlineResult['data']['user'];
        final user = Usuario(
          id: null,
          serverId: userData['id'],
          username: userData['username'],
          email: userData['email'],
          password: password,
          telefono: userData['telefono'],
          isProfessional: userData['is_professional'],
          professionalLicense: userData['professional_license'],
          isVerified: userData['is_verified'],
          isSynced: true,
          createdAt: DateTime.parse(userData['created_at']),
          updatedAt: userData['updated_at'] != null 
              ? DateTime.parse(userData['updated_at'])
              : null,
        );
        
        await cacheService.insertUsuario(user);
        
        return {
          'success': true,
          'user': user,
          'message': 'Login online exitoso',
          'isOffline': false,
        };
      } else {
        // Si falla online, intentar offline solo si hay conexión fallida
        final offlineUser = await cacheService.getUsuarioByCredentials(username, password);
        if (offlineUser != null) {
          return {
            'success': true,
            'user': offlineUser,
            'message': 'Login offline exitoso',
            'isOffline': true,
          };
        } else {
          return {
            'success': false,
            'error': onlineResult['error'] ?? 'Credenciales incorrectas',
          };
        }
      }
    } catch (e) {
      // Si hay error de conexión, permitir login offline
      final offlineUser = await cacheService.getUsuarioByCredentials(username, password);
      if (offlineUser != null) {
        return {
          'success': true,
          'user': offlineUser,
          'message': 'Login offline (sin conexión)',
          'isOffline': true,
        };
      } else {
        return {
          'success': false,
          'error': 'Error de conexión y credenciales incorrectas',
        };
      }
    }
  }

  // Verificar si hay usuario logueado
  Future<Usuario?> getUsuarioActual() async {
    try {
      return await cacheService.getUsuarioActual();
    } catch (e) {
      print('Error obteniendo usuario actual: $e');
      return null;
    }
  }

  // Actualizar usuario
  Future<bool> actualizarUsuario(Usuario usuario) async {
    try {
      return await cacheService.actualizarUsuario(usuario);
    } catch (e) {
      print('Error actualizando usuario: $e');
      return false;
    }
  }

  // Cambiar contraseña
  Future<bool> cambiarPassword(int usuarioId, String nuevaPassword) async {
    try {
      final usuario = await cacheService.getUsuarioById(usuarioId);
      if (usuario == null) return false;
      
      final usuarioActualizado = usuario.copyWith(password: nuevaPassword);
      return await cacheService.actualizarUsuario(usuarioActualizado);
    } catch (e) {
      print('Error cambiando password: $e');
      return false;
    }
  }

  Future<List<Usuario>> getUsuarios() async {
    try {
      return await cacheService.getUsuarios();
    } catch (e) {
      print('Error obteniendo usuarios: $e');
      return [];
    }
  }

  // Cerrar sesión
  Future<void> logout() async {
    try {
      // Limpiar datos sensibles
      await cacheService.clearSensitiveData();
      print('Sesión cerrada exitosamente');
    } catch (e) {
      print('Error en logout: $e');
    }
  }

  Future<void> close() async {
    await cacheService.close();
  }
}