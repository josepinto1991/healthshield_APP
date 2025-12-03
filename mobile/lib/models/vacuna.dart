class Vacuna {
  int? id;
  int? serverId;
  int pacienteId;
  String nombreVacuna;
  String fechaAplicacion;
  String? lote;
  String? proximaDosis;
  int? usuarioId;
  bool isSynced;
  String? syncError;
  DateTime createdAt;
  DateTime? updatedAt;

  Vacuna({
    this.id,
    this.serverId,
    required this.pacienteId,
    required this.nombreVacuna,
    required this.fechaAplicacion,
    this.lote,
    this.proximaDosis,
    this.usuarioId,
    this.isSynced = false,
    this.syncError,
    required this.createdAt,
    this.updatedAt,
  });

  factory Vacuna.fromJson(Map<String, dynamic> json) {
    return Vacuna(
      id: json['id'],
      serverId: json['server_id'],
      pacienteId: json['paciente_id'],
      nombreVacuna: json['nombre_vacuna'],
      fechaAplicacion: json['fecha_aplicacion'],
      lote: json['lote'],
      proximaDosis: json['proxima_dosis'],
      usuarioId: json['usuario_id'],
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
      'paciente_id': pacienteId,
      'nombre_vacuna': nombreVacuna,
      'fecha_aplicacion': fechaAplicacion,
      'lote': lote,
      'proxima_dosis': proximaDosis,
      'usuario_id': usuarioId,
      'is_synced': isSynced ? 1 : 0,
      'sync_error': syncError,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  Map<String, dynamic> toServerJson() {
    return {
      'paciente_id': pacienteId,
      'nombre_vacuna': nombreVacuna,
      'fecha_aplicacion': fechaAplicacion,
      'lote': lote,
      'proxima_dosis': proximaDosis,
      'usuario_id': usuarioId,
      'local_id': id,
    };
  }

  String get fechaFormateada {
    try {
      final date = DateTime.parse(fechaAplicacion);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return fechaAplicacion;
    }
  }

  @override
  String toString() {
    return 'Vacuna{id: $id, nombreVacuna: $nombreVacuna, pacienteId: $pacienteId, isSynced: $isSynced}';
  }
}