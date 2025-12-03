import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'https://healthshield-backend.onrender.com/api';

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

  // ========== AUTENTICACIÓN ==========
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

  Future<Map<String, dynamic>> register(Map<String, dynamic> userData) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: headers,
        body: json.encode(userData),
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

  // ========== PACIENTES ==========
  Future<Map<String, dynamic>> getPacientes() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/pacientes'),
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
          'error': 'Error obteniendo pacientes: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Error de conexión: $e',
      };
    }
  }

  Future<Map<String, dynamic>> addPaciente(Map<String, dynamic> paciente) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/pacientes'),
        headers: headers,
        body: json.encode(paciente),
      ).timeout(Duration(seconds: 15));

      if (response.statusCode == 201) {
        return {
          'success': true,
          'data': json.decode(response.body),
        };
      } else {
        return {
          'success': false,
          'error': 'Error agregando paciente: ${response.statusCode}',
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
  Future<Map<String, dynamic>> getVacunas() async {
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

  Future<Map<String, dynamic>> addVacuna(Map<String, dynamic> vacuna) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/vacunas'),
        headers: headers,
        body: json.encode(vacuna),
      ).timeout(Duration(seconds: 15));

      if (response.statusCode == 201) {
        return {
          'success': true,
          'data': json.decode(response.body),
        };
      } else {
        return {
          'success': false,
          'error': 'Error agregando vacuna: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Error de conexión: $e',
      };
    }
  }

  // ========== SINCRONIZACIÓN ==========
  Future<Map<String, dynamic>> syncPacientes(List<Map<String, dynamic>> pacientes) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/sync/pacientes'),
        headers: headers,
        body: json.encode({'pacientes': pacientes}),
      ).timeout(Duration(seconds: 30));

      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': json.decode(response.body),
        };
      } else {
        return {
          'success': false,
          'error': 'Error sincronizando pacientes: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Error de conexión: $e',
      };
    }
  }

  Future<Map<String, dynamic>> syncVacunas(List<Map<String, dynamic>> vacunas) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/sync/vacunas'),
        headers: headers,
        body: json.encode({'vacunas': vacunas}),
      ).timeout(Duration(seconds: 30));

      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': json.decode(response.body),
        };
      } else {
        return {
          'success': false,
          'error': 'Error sincronizando vacunas: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Error de conexión: $e',
      };
    }
  }

  Future<Map<String, dynamic>> fullSync({
    required List<Map<String, dynamic>> pacientes,
    required List<Map<String, dynamic>> vacunas,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/sync/full'),
        headers: headers,
        body: json.encode({
          'pacientes': pacientes,
          'vacunas': vacunas,
        }),
      ).timeout(Duration(seconds: 45));

      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': json.decode(response.body),
        };
      } else {
        return {
          'success': false,
          'error': 'Error en sincronización completa: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Error de conexión: $e',
      };
    }
  }

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