import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/usuario.dart';
import '../models/vacuna.dart';

class ApiService {
  static const String baseUrl = 'http://192.168.1.100:5001/api';

  final Map<String, String> headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  String? _token;

  set token(String? token) {
    _token = token;
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    } else {
      headers.remove('Authorization');
    }
  }

  // ========== VERIFICACIÓN DE PROFESIONALES ==========
  Future<Map<String, dynamic>> verifyProfessional(String cedula) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/verify/professional'),
        headers: headers,
        body: json.encode({'cedula': cedula}),
      ).timeout(Duration(seconds: 30));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {
          'success': false,
          'is_valid': false,
          'message': 'Error en verificación: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'is_valid': false,
        'message': 'Error de conexión: $e',
      };
    }
  }

  Future<Map<String, dynamic>> registerProfessional(Usuario usuario, String cedula) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/register-professional?cedula_verificacion=$cedula'),
        headers: headers,
        body: json.encode(usuario.toServerJson()),
      ).timeout(Duration(seconds: 30));

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        if (data['token'] != null) {
          token = data['token'];
        }
        return {
          'success': true,
          'data': data,
        };
      } else {
        return {
          'success': false,
          'error': 'Error en registro profesional: ${response.body}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Error de conexión: $e',
      };
    }
  }

  // ========== VERIFICAR CONEXIÓN ==========
  Future<bool> checkServerStatus() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/health'),
        headers: headers,
      ).timeout(Duration(seconds: 10));
      
      return response.statusCode == 200;
    } catch (e) {
      print('❌ Servidor no disponible: $e');
      return false;
    }
  }

  // ========== USUARIOS ==========
  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: headers,
        body: json.encode({
          'username': username,
          'password': password,
        }),
      ).timeout(Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['token'] != null) {
          token = data['token'];
        }
        return {
          'success': true,
          'data': data,
        };
      } else {
        return {
          'success': false,
          'error': 'Credenciales incorrectas',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Error de conexión: $e',
      };
    }
  }

  Future<Map<String, dynamic>> register(Usuario usuario) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: headers,
        body: json.encode(usuario.toServerJson()),
      ).timeout(Duration(seconds: 15));

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        if (data['token'] != null) {
          token = data['token'];
        }
        return {
          'success': true,
          'data': data,
        };
      } else {
        return {
          'success': false,
          'error': 'Error en registro: ${response.body}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Error de conexión: $e',
      };
    }
  }

  Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
    required int userId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/users/change-password'),
        headers: headers,
        body: json.encode({
          'current_password': currentPassword,
          'new_password': newPassword,
          'user_id': userId,
        }),
      ).timeout(Duration(seconds: 15));

      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': json.decode(response.body),
        };
      } else {
        return {
          'success': false,
          'error': 'Error cambiando contraseña: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Error de conexión: $e',
      };
    }
  }

  Future<Map<String, dynamic>> syncUser(Usuario usuario) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: headers,
        body: json.encode(usuario.toServerJson()),
      ).timeout(Duration(seconds: 15));

      if (response.statusCode == 201) {
        return {
          'success': true,
          'data': json.decode(response.body),
        };
      } else {
        return {
          'success': false,
          'error': 'Error sincronizando usuario: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Error de conexión: $e',
      };
    }
  }

  // ========== VACUNAS ==========
  Future<Map<String, dynamic>> syncVacuna(Vacuna vacuna) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/vacunas'),
        headers: headers,
        body: json.encode(vacuna.toServerJson()),
      ).timeout(Duration(seconds: 15));

      if (response.statusCode == 201) {
        return {
          'success': true,
          'data': json.decode(response.body),
        };
      } else {
        return {
          'success': false,
          'error': 'Error sincronizando vacuna: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Error de conexión: $e',
      };
    }
  }

  Future<Map<String, dynamic>> getVacunasFromServer() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/vacunas'),
        headers: headers,
      ).timeout(Duration(seconds: 15));

      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': json.decode(response.body),
        };
      } else {
        return {
          'success': false,
          'error': 'Error obteniendo vacunas: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Error de conexión: $e',
      };
    }
  }

  // ========== SINCRONIZACIÓN MASIVA ==========
  Future<Map<String, dynamic>> bulkSync(List<Vacuna> vacunas) async {
    try {
      final vacunasData = vacunas.map((v) => v.toServerJson()).toList();
      
      final response = await http.post(
        Uri.parse('$baseUrl/sync/bulk'),
        headers: headers,
        body: json.encode({'vacunas': vacunasData}),
      ).timeout(Duration(seconds: 30));

      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': json.decode(response.body),
        };
      } else {
        return {
          'success': false,
          'error': 'Error en sincronización masiva: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Error de conexión: $e',
      };
    }
  }

  // ========== OBTENER ACTUALIZACIONES ==========
  Future<Map<String, dynamic>> getUpdates(String lastSync) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/sync/updates?last_sync=$lastSync'),
        headers: headers,
      ).timeout(Duration(seconds: 15));

      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': json.decode(response.body),
        };
      } else {
        return {
          'success': false,
          'error': 'Error obteniendo actualizaciones: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Error de conexión: $e',
      };
    }
  }
}