// class Vacuna {
//   int? id;
//   int? serverId;
//   int? pacienteId;
//   int? pacienteServerId;
//   String nombreVacuna;
//   String fechaAplicacion;
//   String? lote;
//   String? proximaDosis;
//   int? usuarioId;
//   bool isSynced;
//   DateTime? createdAt;
//   DateTime? updatedAt;

//   String? nombrePaciente;
//   String? cedulaPaciente;

//   Vacuna({
//     this.id,
//     this.serverId,
//     this.pacienteId,
//     this.pacienteServerId,
//     required this.nombreVacuna,
//     required this.fechaAplicacion,
//     this.lote,
//     this.proximaDosis,
//     this.usuarioId,
//     this.isSynced = false,
//     this.createdAt,
//     this.updatedAt,
//     this.nombrePaciente,
//     this.cedulaPaciente,
//   });

//   factory Vacuna.fromJson(Map<String, dynamic> json) {
//     return Vacuna(
//       id: json['id'],
//       serverId: json['server_id'],
//       pacienteId: json['paciente_id'],
//       pacienteServerId: json['paciente_server_id'],
//       nombreVacuna: json['nombre_vacuna'],
//       fechaAplicacion: json['fecha_aplicacion'],
//       lote: json['lote'],
//       proximaDosis: json['proxima_dosis'],
//       usuarioId: json['usuario_id'],
//       isSynced: json['is_synced'] == 1 || json['is_synced'] == true,
//       createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
//       updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
//       nombrePaciente: json['nombre_paciente'],
//       cedulaPaciente: json['cedula_paciente'],
//     );
//   }

//   Map<String, dynamic> toJson() {
//     return {
//       'id': id,
//       'server_id': serverId,
//       'paciente_id': pacienteId,
//       'paciente_server_id': pacienteServerId,
//       'nombre_vacuna': nombreVacuna,
//       'fecha_aplicacion': fechaAplicacion,
//       'lote': lote,
//       'proxima_dosis': proximaDosis,
//       'usuario_id': usuarioId,
//       'is_synced': isSynced ? 1 : 0,
//       'created_at': createdAt?.toIso8601String(),
//       'updated_at': updatedAt?.toIso8601String(),
//       'nombre_paciente': nombrePaciente,
//       'cedula_paciente': cedulaPaciente,
//     };
//   }

//   Map<String, dynamic> toServerJson() {
//     return {
//       'paciente_id': pacienteServerId ?? pacienteId,
//       'nombre_vacuna': nombreVacuna,
//       'fecha_aplicacion': fechaAplicacion,
//       'lote': lote,
//       'proxima_dosis': proximaDosis,
//       'local_id': id,
//     };
//   }

//   String get fechaAplicacionFormateada {
//     try {
//       final parts = fechaAplicacion.split('-');
//       if (parts.length == 3) {
//         return '${parts[2]}/${parts[1]}/${parts[0]}';
//       }
//       return fechaAplicacion;
//     } catch (e) {
//       return fechaAplicacion;
//     }
//   }

//   String? get proximaDosisFormateada {
//     if (proximaDosis == null) return null;
//     try {
//       final parts = proximaDosis!.split('-');
//       if (parts.length == 3) {
//         return '${parts[2]}/${parts[1]}/${parts[0]}';
//       }
//       return proximaDosis;
//     } catch (e) {
//       return proximaDosis;
//     }
//   }

//   bool get proximaDosisPasada {
//     if (proximaDosis == null) return false;
//     try {
//       final parts = proximaDosis!.split('-');
//       if (parts.length == 3) {
//         final fechaProxima = DateTime(
//           int.parse(parts[0]),
//           int.parse(parts[1]),
//           int.parse(parts[2]),
//         );
//         return DateTime.now().isAfter(fechaProxima);
//       }
//       return false;
//     } catch (e) {
//       return false;
//     }
//   }
// }


class Vacuna {
  int? id;
  int? serverId;
  int? pacienteId;
  int? pacienteServerId;
  String nombreVacuna;
  String fechaAplicacion;
  String? lote;
  String? proximaDosis;
  int? usuarioId;
  bool isSynced;
  DateTime? createdAt;
  DateTime? updatedAt;

  String? nombrePaciente;
  String? cedulaPaciente;
  bool esMenor; // true = niño, false = adulto
  String? cedulaTutor; // para niños
  String? cedulaPropia; // para adultos

  Vacuna({
    this.id,
    this.serverId,
    this.pacienteId,
    this.pacienteServerId,
    required this.nombreVacuna,
    required this.fechaAplicacion,
    this.lote,
    this.proximaDosis,
    this.usuarioId,
    this.isSynced = false,
    this.createdAt,
    this.updatedAt,
    this.nombrePaciente,
    this.cedulaPaciente,
    required this.esMenor,
    this.cedulaTutor,
    this.cedulaPropia,
  });

  factory Vacuna.fromJson(Map<String, dynamic> json) {
    return Vacuna(
      id: json['id'],
      serverId: json['server_id'],
      pacienteId: json['paciente_id'],
      pacienteServerId: json['paciente_server_id'],
      nombreVacuna: json['nombre_vacuna'],
      fechaAplicacion: json['fecha_aplicacion'],
      lote: json['lote'],
      proximaDosis: json['proxima_dosis'],
      usuarioId: json['usuario_id'],
      isSynced: json['is_synced'] == 1 || json['is_synced'] == true,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
      nombrePaciente: json['nombre_paciente'],
      cedulaPaciente: json['cedula_paciente'],
      esMenor: json['es_menor'] == 1 || json['es_menor'] == true,
      cedulaTutor: json['cedula_tutor'],
      cedulaPropia: json['cedula_propia'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'server_id': serverId,
      'paciente_id': pacienteId,
      'paciente_server_id': pacienteServerId,
      'nombre_vacuna': nombreVacuna,
      'fecha_aplicacion': fechaAplicacion,
      'lote': lote,
      'proxima_dosis': proximaDosis,
      'usuario_id': usuarioId,
      'is_synced': isSynced ? 1 : 0,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'nombre_paciente': nombrePaciente,
      'cedula_paciente': cedulaPaciente,
      'es_menor': esMenor ? 1 : 0,
      'cedula_tutor': cedulaTutor,
      'cedula_propia': cedulaPropia,
    };
  }

  // ✅ AGREGAR ESTE MÉTODO QUE FALTA
  Map<String, dynamic> toServerJson() {
    return {
      'paciente_id': pacienteServerId ?? pacienteId,
      'nombre_vacuna': nombreVacuna,
      'fecha_aplicacion': fechaAplicacion,
      'lote': lote,
      'proxima_dosis': proximaDosis,
      'local_id': id,
      'nombre_paciente': nombrePaciente,
      'cedula_paciente': cedulaPaciente,
      'es_menor': esMenor,
      'cedula_tutor': cedulaTutor,
      'cedula_propia': cedulaPropia,
    };
  }

  // Para identificación única del paciente
  String get pacienteIdUnico {
    if (esMenor) {
      // Para niños: cédula + nombre único
      return '${cedulaPaciente}_${nombrePaciente}_nino';
    } else {
      // Para adultos: cédula + nombre
      return '${cedulaPaciente}_${nombrePaciente}';
    }
  }

  // Nombre para mostrar
  String get nombreMostrar {
    if (nombrePaciente == null) return 'Paciente';
    if (esMenor) {
      return '$nombrePaciente 👶';
    } else {
      return '$nombrePaciente 👤';
    }
  }

  String get fechaAplicacionFormateada {
    try {
      final parts = fechaAplicacion.split('-');
      if (parts.length == 3) {
        return '${parts[2]}/${parts[1]}/${parts[0]}';
      }
      return fechaAplicacion;
    } catch (e) {
      return fechaAplicacion;
    }
  }

  String? get proximaDosisFormateada {
    if (proximaDosis == null) return null;
    try {
      final parts = proximaDosis!.split('-');
      if (parts.length == 3) {
        return '${parts[2]}/${parts[1]}/${parts[0]}';
      }
      return proximaDosis;
    } catch (e) {
      return proximaDosis;
    }
  }

  bool get proximaDosisPasada {
    if (proximaDosis == null) return false;
    try {
      final parts = proximaDosis!.split('-');
      if (parts.length == 3) {
        final fechaProxima = DateTime(
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2]),
        );
        return DateTime.now().isAfter(fechaProxima);
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}