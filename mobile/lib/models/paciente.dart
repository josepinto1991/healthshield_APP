class Paciente {
  final int? id;
  final int? serverId;
  final String cedula;
  final String nombre;
  final String fechaNacimiento;
  final String? telefono;
  final String? direccion;
  final bool isSynced;
  final String? syncError;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Paciente({
    this.id,
    this.serverId,
    required this.cedula,
    required this.nombre,
    required this.fechaNacimiento,
    this.telefono,
    this.direccion,
    this.isSynced = false,
    this.syncError,
    required this.createdAt,
    this.updatedAt,
  });

  factory Paciente.fromJson(Map<String, dynamic> json) {
    return Paciente(
      id: json['id'],
      serverId: json['server_id'],
      cedula: json['cedula'] ?? '',
      nombre: json['nombre'],
      fechaNacimiento: json['fecha_nacimiento'],
      telefono: json['telefono'],
      direccion: json['direccion'],
      isSynced: json['is_synced'] == 1,
      syncError: json['sync_error'],
      createdAt: DateTime.parse(json['created_at']),
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
      'sync_error': syncError,
      'created_at': createdAt.toIso8601String(),
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

  Paciente copyWith({
    int? id,
    int? serverId,
    String? cedula,
    String? nombre,
    String? fechaNacimiento,
    String? telefono,
    String? direccion,
    bool? isSynced,
    String? syncError,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Paciente(
      id: id ?? this.id,
      serverId: serverId ?? this.serverId,
      cedula: cedula ?? this.cedula,
      nombre: nombre ?? this.nombre,
      fechaNacimiento: fechaNacimiento ?? this.fechaNacimiento,
      telefono: telefono ?? this.telefono,
      direccion: direccion ?? this.direccion,
      isSynced: isSynced ?? this.isSynced,
      syncError: syncError ?? this.syncError,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'Paciente{id: $id, nombre: $nombre, cedula: $cedula, isSynced: $isSynced}';
  }
}