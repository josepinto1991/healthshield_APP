class Paciente {
  int? id;
  int? serverId;
  String cedula;
  String nombre;
  String fechaNacimiento;
  String? telefono;
  String? direccion;
  bool isSynced;
  DateTime? createdAt;
  DateTime? updatedAt;

  Paciente({
    this.id,
    this.serverId,
    required this.cedula,
    required this.nombre,
    required this.fechaNacimiento,
    this.telefono,
    this.direccion,
    this.isSynced = false,
    this.createdAt,
    this.updatedAt,
  });

  factory Paciente.fromJson(Map<String, dynamic> json) {
    return Paciente(
      id: json['id'],
      serverId: json['server_id'],
      cedula: json['cedula'],
      nombre: json['nombre'],
      fechaNacimiento: json['fecha_nacimiento'],
      telefono: json['telefono'],
      direccion: json['direccion'],
      isSynced: json['is_synced'] == 1 || json['is_synced'] == true,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'server_id': serverId,
      'cedula': cedula,
      'nombre': nombre,
      'fecha_nacimiento': fechaNacimiento,
      'telefono': telefono,
      'direccion': direccion,
      'is_synced': isSynced ? 1 : 0,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  Map<String, dynamic> toServerJson() {
    return {
      'cedula': cedula,
      'nombre': nombre,
      'fecha_nacimiento': fechaNacimiento,
      'telefono': telefono,
      'direccion': direccion,
      'local_id': id,
    };
  }

  String get fechaNacimientoFormateada {
    try {
      final parts = fechaNacimiento.split('-');
      if (parts.length == 3) {
        return '${parts[2]}/${parts[1]}/${parts[0]}';
      }
      return fechaNacimiento;
    } catch (e) {
      return fechaNacimiento;
    }
  }

  int? get edad {
    try {
      final parts = fechaNacimiento.split('-');
      if (parts.length == 3) {
        final nacimiento = DateTime(
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2]),
        );
        final ahora = DateTime.now();
        int edad = ahora.year - nacimiento.year;
        if (ahora.month < nacimiento.month ||
            (ahora.month == nacimiento.month && ahora.day < nacimiento.day)) {
          edad--;
        }
        return edad;
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}