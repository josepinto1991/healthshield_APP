// import 'dart:convert';
// import 'package:http/http.dart' as http;
// import '../models/usuario.dart';
// import '../models/vacuna.dart';
// import '../models/paciente.dart';

// class ApiService {
//   // Configuración de la API
//   static const String baseUrl = 'https://healthshield-app.vercel.app/api';

//   final Map<String, String> headers = {
//     'Content-Type': 'application/json',
//     'Accept': 'application/json',
//   };

//   String? _token;

//   set token(String? token) {
//     _token = token;
//     if (token != null) {
//       headers['Authorization'] = 'Bearer $token';
//     } else {
//       headers.remove('Authorization');
//     }
//   }
  
//   // ✅ MÉTODO MEJORADO PARA VERIFICAR CONEXIÓN
//   Future<bool> checkServerStatus() async {
//     try {
//       print('🌐 Verificando conexión con servidor: $baseUrl');
//       final response = await http.get(
//         Uri.parse('$baseUrl/health'),
//         headers: headers,
//       ).timeout(Duration(seconds: 10));
      
//       final isConnected = response.statusCode == 200;
//       print(isConnected ? '✅ Servidor disponible' : '❌ Servidor no responde');
//       return isConnected;
//     } catch (e) {
//       print('⚠️ No se puede conectar al servidor: $e');
//       print('💡 URL intentada: $baseUrl/health');
//       return false;
//     }
//   }
  
//   // ========== VERIFICACIÓN SIMULADA DE PROFESIONALES ==========
//   Future<Map<String, dynamic>> verifyProfessional(String cedula) async {
//     try {
//       // En lugar de verificar, devolvemos éxito automático
//       // Esto elimina la dependencia del SACS
//       await Future.delayed(Duration(seconds: 1)); // Simular delay de red
      
//       return {
//         'success': true,
//         'is_valid': true,
//         'message': 'Verificación automática - Modo desarrollo',
//         'professional_name': 'Profesional de Salud',
//         'especialidad': 'Salud General',
//         'professional_license': 'MP-' + DateTime.now().millisecondsSinceEpoch.toString().substring(5, 10),
//       };
//     } catch (e) {
//       // Si hay error, igual devolvemos éxito para permitir registro offline
//       return {
//         'success': true,
//         'is_valid': true,
//         'message': 'Verificación offline - Se registrará localmente',
//         'professional_name': 'Profesional de Salud',
//         'especialidad': 'Salud General',
//         'professional_license': 'LP-' + DateTime.now().millisecondsSinceEpoch.toString().substring(5, 8),
//       };
//     }
//   }

//   Future<Map<String, dynamic>> registerProfessional(Usuario usuario, String cedula) async {
//     try {
//       // Primero intentar registro online si hay servidor
//       final response = await http.post(
//         Uri.parse('$baseUrl/auth/register-professional'),
//         headers: headers,
//         body: json.encode({
//           ...usuario.toServerJson(),
//           'cedula_verificacion': cedula,
//         }),
//       ).timeout(Duration(seconds: 15));

//       if (response.statusCode == 201) {
//         final data = json.decode(response.body);
//         if (data['token'] != null) {
//           token = data['token'];
//         }
//         return {
//           'success': true,
//           'data': data,
//         };
//       } else {
//         // Si falla, permitir registro offline
//         return {
//           'success': true, // Cambiado a true para permitir registro offline
//           'data': {
//             'user': usuario.toServerJson(),
//             'token': null,
//           },
//           'message': 'Registro offline - Se guardará localmente',
//         };
//       }
//     } catch (e) {
//       // Si hay error de conexión, permitir registro offline
//       return {
//         'success': true, // Cambiado a true para permitir registro offline
//         'data': {
//           'user': usuario.toServerJson(),
//           'token': null,
//         },
//         'message': 'Error de conexión - Registro offline permitido',
//       };
//     }
//   }

//   // ========== USUARIOS ==========
//   Future<Map<String, dynamic>> login(String username, String password) async {
//     try {
//       final response = await http.post(
//         Uri.parse('$baseUrl/auth/login'),
//         headers: headers,
//         body: json.encode({
//           'username': username,
//           'password': password,
//         }),
//       ).timeout(Duration(seconds: 15));

//       if (response.statusCode == 200) {
//         final data = json.decode(response.body);
//         if (data['token'] != null) {
//           token = data['token'];
//         }
//         return {
//           'success': true,
//           'data': data,
//         };
//       } else {
//         return {
//           'success': false,
//           'error': 'Credenciales incorrectas o servidor no disponible',
//         };
//       }
//     } catch (e) {
//       return {
//         'success': false,
//         'error': 'Error de conexión: $e',
//       };
//     }
//   }

//   Future<Map<String, dynamic>> register(Usuario usuario) async {
//     try {
//       final response = await http.post(
//         Uri.parse('$baseUrl/auth/register'),
//         headers: headers,
//         body: json.encode(usuario.toServerJson()),
//       ).timeout(Duration(seconds: 15));

//       if (response.statusCode == 201) {
//         final data = json.decode(response.body);
//         if (data['token'] != null) {
//           token = data['token'];
//         }
//         return {
//           'success': true,
//           'data': data,
//         };
//       } else {
//         return {
//           'success': false,
//           'error': 'Error en registro: ${response.body}',
//         };
//       }
//     } catch (e) {
//       return {
//         'success': false,
//         'error': 'Error de conexión: $e',
//       };
//     }
//   }

//   Future<Map<String, dynamic>> syncUser(Usuario usuario) async {
//     try {
//       final response = await http.post(
//         Uri.parse('$baseUrl/auth/register'),
//         headers: headers,
//         body: json.encode(usuario.toServerJson()),
//       ).timeout(Duration(seconds: 15));

//       if (response.statusCode == 201) {
//         return {
//           'success': true,
//           'data': json.decode(response.body),
//         };
//       } else {
//         return {
//           'success': false,
//           'error': 'Error sincronizando usuario: ${response.statusCode}',
//         };
//       }
//     } catch (e) {
//       return {
//         'success': false,
//         'error': 'Error de conexión: $e',
//       };
//     }
//   }

//   // ========== PACIENTES ==========
//   Future<Map<String, dynamic>> crearPaciente(Paciente paciente) async {
//     try {
//       final response = await http.post(
//         Uri.parse('$baseUrl/pacientes'),
//         headers: headers,
//         body: json.encode(paciente.toServerJson()),
//       ).timeout(Duration(seconds: 15));

//       if (response.statusCode == 201) {
//         return {
//           'success': true,
//           'data': json.decode(response.body),
//         };
//       } else {
//         return {
//           'success': false,
//           'error': 'Error creando paciente: ${response.statusCode} - ${response.body}',
//         };
//       }
//     } catch (e) {
//       return {
//         'success': false,
//         'error': 'Error de conexión: $e',
//       };
//     }
//   }

//   Future<Map<String, dynamic>> getPacientes() async {
//     try {
//       final response = await http.get(
//         Uri.parse('$baseUrl/pacientes'),
//         headers: headers,
//       ).timeout(Duration(seconds: 15));

//       if (response.statusCode == 200) {
//         return {
//           'success': true,
//           'data': json.decode(response.body),
//         };
//       } else {
//         return {
//           'success': false,
//           'error': 'Error obteniendo pacientes: ${response.statusCode}',
//         };
//       }
//     } catch (e) {
//       return {
//         'success': false,
//         'error': 'Error de conexión: $e',
//       };
//     }
//   }

//   Future<Map<String, dynamic>> buscarPacientes(String query) async {
//     try {
//       final response = await http.get(
//         Uri.parse('$baseUrl/pacientes/buscar?q=$query'),
//         headers: headers,
//       ).timeout(Duration(seconds: 15));

//       if (response.statusCode == 200) {
//         return {
//           'success': true,
//           'data': json.decode(response.body),
//         };
//       } else {
//         return {
//           'success': false,
//           'error': 'Error buscando pacientes: ${response.statusCode}',
//         };
//       }
//     } catch (e) {
//       return {
//         'success': false,
//         'error': 'Error de conexión: $e',
//       };
//     }
//   }

//   Future<Map<String, dynamic>> getPacienteByCedula(String cedula) async {
//     try {
//       final response = await http.get(
//         Uri.parse('$baseUrl/pacientes/cedula/$cedula'),
//         headers: headers,
//       ).timeout(Duration(seconds: 15));

//       if (response.statusCode == 200) {
//         return {
//           'success': true,
//           'data': json.decode(response.body),
//         };
//       } else {
//         return {
//           'success': false,
//           'error': 'Paciente no encontrado',
//         };
//       }
//     } catch (e) {
//       return {
//         'success': false,
//         'error': 'Error de conexión: $e',
//       };
//     }
//   }

//   // ========== VACUNAS ==========
//   Future<Map<String, dynamic>> crearVacuna(Vacuna vacuna) async {
//     try {
//       final response = await http.post(
//         Uri.parse('$baseUrl/vacunas'),
//         headers: headers,
//         body: json.encode(vacuna.toServerJson()),
//       ).timeout(Duration(seconds: 15));

//       if (response.statusCode == 201) {
//         return {
//           'success': true,
//           'data': json.decode(response.body),
//         };
//       } else {
//         return {
//           'success': false,
//           'error': 'Error creando vacuna: ${response.statusCode} - ${response.body}',
//         };
//       }
//     } catch (e) {
//       return {
//         'success': false,
//         'error': 'Error de conexión: $e',
//       };
//     }
//   }


//   Future<Map<String, dynamic>> getVacunasFromServer() async {
//     try {
//       final response = await http.get(
//         Uri.parse('$baseUrl/vacunas'),
//         headers: headers,
//       ).timeout(Duration(seconds: 15));

//       if (response.statusCode == 200) {
//         return {
//           'success': true,
//           'data': json.decode(response.body),
//         };
//       } else {
//         return {
//           'success': false,
//           'error': 'Error obteniendo vacunas: ${response.statusCode}',
//         };
//       }
//     } catch (e) {
//       return {
//         'success': false,
//         'error': 'Error de conexión: $e',
//       };
//     }
//   }

//   Future<Map<String, dynamic>> getVacunas() async {
//     try {
//       final response = await http.get(
//         Uri.parse('$baseUrl/vacunas'),
//         headers: headers,
//       ).timeout(Duration(seconds: 15));

//       if (response.statusCode == 200) {
//         return {
//           'success': true,
//           'data': json.decode(response.body),
//         };
//       } else {
//         return {
//           'success': false,
//           'error': 'Error obteniendo vacunas: ${response.statusCode}',
//         };
//       }
//     } catch (e) {
//       return {
//         'success': false,
//         'error': 'Error de conexión: $e',
//       };
//     }
//   }

//   Future<Map<String, dynamic>> getVacunasByPaciente(int pacienteId) async {
//     try {
//       final response = await http.get(
//         Uri.parse('$baseUrl/pacientes/$pacienteId/vacunas'),
//         headers: headers,
//       ).timeout(Duration(seconds: 15));

//       if (response.statusCode == 200) {
//         return {
//           'success': true,
//           'data': json.decode(response.body),
//         };
//       } else {
//         return {
//           'success': false,
//           'error': 'Error obteniendo vacunas del paciente: ${response.statusCode}',
//         };
//       }
//     } catch (e) {
//       return {
//         'success': false,
//         'error': 'Error de conexión: $e',
//       };
//     }
//   }

//   Future<Map<String, dynamic>> syncVacuna(Vacuna vacuna) async {
//     try {
//       final response = await http.post(
//         Uri.parse('$baseUrl/vacunas'),
//         headers: headers,
//         body: json.encode(vacuna.toServerJson()),
//       ).timeout(Duration(seconds: 15));

//       if (response.statusCode == 201) {
//         return {
//           'success': true,
//           'data': json.decode(response.body),
//         };
//       } else {
//         return {
//           'success': false,
//           'error': 'Error sincronizando vacuna: ${response.statusCode}',
//         };
//       }
//     } catch (e) {
//       return {
//         'success': false,
//         'error': 'Error de conexión: $e',
//       };
//     }
//   }

//   // ========== SINCRONIZACIÓN ==========
//   Future<Map<String, dynamic>> bulkSync(List<Vacuna> vacunas) async {
//     try {
//       final vacunasData = vacunas.map((v) => v.toServerJson()).toList();
      
//       final response = await http.post(
//         Uri.parse('$baseUrl/sync/bulk'),
//         headers: headers,
//         body: json.encode({'vacunas': vacunasData}),
//       ).timeout(Duration(seconds: 30));

//       if (response.statusCode == 200) {
//         return {
//           'success': true,
//           'data': json.decode(response.body),
//         };
//       } else {
//         return {
//           'success': false,
//           'error': 'Error en sincronización masiva: ${response.statusCode}',
//         };
//       }
//     } catch (e) {
//       return {
//         'success': false,
//         'error': 'Error de conexión: $e',
//       };
//     }
//   }

//   Future<Map<String, dynamic>> getUpdates(String lastSync) async {
//     try {
//       final response = await http.get(
//         Uri.parse('$baseUrl/sync/updates?last_sync=$lastSync'),
//         headers: headers,
//       ).timeout(Duration(seconds: 15));

//       if (response.statusCode == 200) {
//         return {
//           'success': true,
//           'data': json.decode(response.body),
//         };
//       } else {
//         return {
//           'success': false,
//           'error': 'Error obteniendo actualizaciones: ${response.statusCode}',
//         };
//       }
//     } catch (e) {
//       return {
//         'success': false,
//         'error': 'Error de conexión: $e',
//       };
//     }
//   }

//   // ========== CAMBIO DE CONTRASEÑA ==========
//   Future<Map<String, dynamic>> changePassword({
//     required String currentPassword,
//     required String newPassword,
//     required int userId,
//   }) async {
//     try {
//       final response = await http.post(
//         Uri.parse('$baseUrl/users/change-password'),
//         headers: headers,
//         body: json.encode({
//           'current_password': currentPassword,
//           'new_password': newPassword,
//           'user_id': userId,
//         }),
//       ).timeout(Duration(seconds: 15));

//       if (response.statusCode == 200) {
//         return {
//           'success': true,
//           'data': json.decode(response.body),
//         };
//       } else {
//         return {
//           'success': false,
//           'error': 'Error cambiando contraseña: ${response.statusCode}',
//         };
//       }
//     } catch (e) {
//       return {
//         'success': false,
//         'error': 'Error de conexión: $e',
//       };
//     }
//   }
// }

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/usuario.dart';
import '../models/vacuna.dart';
import '../models/paciente.dart';

class ApiService {
  // Configuración de la API
  static const String baseUrl = 'https://healthshield-app.vercel.app/api';

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
  
  // ✅ MÉTODO MEJORADO PARA VERIFICAR CONEXIÓN
  Future<bool> checkServerStatus() async {
    try {
      print('🌐 Verificando conexión con servidor: $baseUrl');
      final response = await http.get(
        Uri.parse('$baseUrl/health'),
        headers: headers,
      ).timeout(Duration(seconds: 10));
      
      final isConnected = response.statusCode == 200;
      print(isConnected ? '✅ Servidor disponible' : '❌ Servidor no responde');
      return isConnected;
    } catch (e) {
      print('⚠️ No se puede conectar al servidor: $e');
      print('💡 URL intentada: $baseUrl/health');
      return false;
    }
  }
  
  // ========== VERIFICACIÓN SIMULADA DE PROFESIONALES ==========
  Future<Map<String, dynamic>> verifyProfessional(String cedula) async {
    try {
      await Future.delayed(Duration(seconds: 1));
      
      return {
        'success': true,
        'is_valid': true,
        'message': 'Verificación automática - Modo desarrollo',
        'professional_name': 'Profesional de Salud',
        'especialidad': 'Salud General',
        'professional_license': 'MP-' + DateTime.now().millisecondsSinceEpoch.toString().substring(5, 10),
      };
    } catch (e) {
      return {
        'success': true,
        'is_valid': true,
        'message': 'Verificación offline - Se registrará localmente',
        'professional_name': 'Profesional de Salud',
        'especialidad': 'Salud General',
        'professional_license': 'LP-' + DateTime.now().millisecondsSinceEpoch.toString().substring(5, 8),
      };
    }
  }

  Future<Map<String, dynamic>> registerProfessional(Usuario usuario, String cedula) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: headers,
        body: json.encode({
          ...usuario.toServerJson(),
          'professional_license': usuario.professionalLicense,
        }),
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
          'error': 'Credenciales incorrectas o servidor no disponible',
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

  // ========== PACIENTES ==========
  Future<Map<String, dynamic>> crearPaciente(Paciente paciente) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/pacientes'),
        headers: headers,
        body: json.encode({
          'cedula': paciente.cedula,
          'nombre': paciente.nombre,
          'fecha_nacimiento': paciente.fechaNacimiento,
          'telefono': paciente.telefono,
          'direccion': paciente.direccion,
          'local_id': paciente.id,
        }),
      ).timeout(Duration(seconds: 15));

      if (response.statusCode == 201) {
        return {
          'success': true,
          'data': json.decode(response.body),
        };
      } else {
        return {
          'success': false,
          'error': 'Error creando paciente: ${response.statusCode} - ${response.body}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Error de conexión: $e',
      };
    }
  }

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

  Future<Map<String, dynamic>> buscarPacientes(String query) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/pacientes/buscar?q=$query'),
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
          'error': 'Error buscando pacientes: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Error de conexión: $e',
      };
    }
  }

  Future<Map<String, dynamic>> getPacienteByCedula(String cedula) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/pacientes/cedula/$cedula'),
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
          'error': 'Paciente no encontrado',
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
  Future<Map<String, dynamic>> crearVacuna(Vacuna vacuna) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/vacunas'),
        headers: headers,
        body: json.encode({
          'paciente_id': vacuna.pacienteId,
          'paciente_server_id': vacuna.pacienteServerId,
          'nombre_vacuna': vacuna.nombreVacuna,
          'fecha_aplicacion': vacuna.fechaAplicacion,
          'lote': vacuna.lote,
          'proxima_dosis': vacuna.proximaDosis,
          'usuario_id': vacuna.usuarioId,
          'es_menor': vacuna.esMenor,
          'cedula_tutor': vacuna.cedulaTutor,
          'cedula_propia': vacuna.cedulaPropia,
          'nombre_paciente': vacuna.nombrePaciente,
          'cedula_paciente': vacuna.cedulaPaciente,
          'local_id': vacuna.id,
        }),
      ).timeout(Duration(seconds: 15));

      if (response.statusCode == 201) {
        return {
          'success': true,
          'data': json.decode(response.body),
        };
      } else {
        return {
          'success': false,
          'error': 'Error creando vacuna: ${response.statusCode} - ${response.body}',
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

  Future<Map<String, dynamic>> getVacunasByPaciente(int pacienteId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/pacientes/$pacienteId/vacunas'),
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
          'error': 'Error obteniendo vacunas del paciente: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Error de conexión: $e',
      };
    }
  }

  Future<Map<String, dynamic>> syncVacuna(Vacuna vacuna) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/vacunas'),
        headers: headers,
        body: json.encode({
          'paciente_id': vacuna.pacienteId,
          'paciente_server_id': vacuna.pacienteServerId,
          'nombre_vacuna': vacuna.nombreVacuna,
          'fecha_aplicacion': vacuna.fechaAplicacion,
          'lote': vacuna.lote,
          'proxima_dosis': vacuna.proximaDosis,
          'usuario_id': vacuna.usuarioId,
          'es_menor': vacuna.esMenor,
          'cedula_tutor': vacuna.cedulaTutor,
          'cedula_propia': vacuna.cedulaPropia,
          'nombre_paciente': vacuna.nombrePaciente,
          'cedula_paciente': vacuna.cedulaPaciente,
          'local_id': vacuna.id,
        }),
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

  // ========== SINCRONIZACIÓN ==========
  Future<Map<String, dynamic>> bulkSync(List<Vacuna> vacunas) async {
    try {
      final vacunasData = vacunas.map((v) => {
        'local_id': v.id,
        'server_id': v.serverId,
        'paciente_id': v.pacienteId,
        'paciente_server_id': v.pacienteServerId,
        'nombre_vacuna': v.nombreVacuna,
        'fecha_aplicacion': v.fechaAplicacion,
        'lote': v.lote,
        'proxima_dosis': v.proximaDosis,
        'usuario_id': v.usuarioId,
        'es_menor': v.esMenor,
        'cedula_tutor': v.cedulaTutor,
        'cedula_propia': v.cedulaPropia,
        'nombre_paciente': v.nombrePaciente,
        'cedula_paciente': v.cedulaPaciente,
        'is_synced': v.isSynced,
      }).toList();
      
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

  // ========== CAMBIO DE CONTRASEÑA ==========
  Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
    required int userId,
  }) async {
    try {
      // Usar query parameters para cambiar contraseña
      final url = '$baseUrl/users/change-password?current_password=$currentPassword&new_password=$newPassword&user_id=$userId';
      
      final response = await http.post(
        Uri.parse(url),
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
  
  // ✅ MÉTODO PARA PROBAR TOKEN
  Future<Map<String, dynamic>> testToken() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/auth/me'),
        headers: headers,
      ).timeout(Duration(seconds: 15));

      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': json.decode(response.body),
          'message': 'Token válido'
        };
      } else {
        return {
          'success': false,
          'error': 'Token inválido: ${response.statusCode}',
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