class Vacuna {
  int? id;
  int? serverId;
  String nombrePaciente;
  String tipoPaciente;
  String cedulaPaciente;
  String tipoVacuna;
  String fechaVacunacion;
  String? lote;
  String? proximaDosis;
  int? usuarioId;
  bool isSynced;
  DateTime? createdAt;
  DateTime? updatedAt;

  Vacuna({
    this.id,
    this.serverId,
    required this.nombrePaciente,
    required this.tipoPaciente,
    required this.cedulaPaciente,
    required this.tipoVacuna,
    required this.fechaVacunacion,
    this.lote,
    this.proximaDosis,
    this.usuarioId,
    this.isSynced = false,
    this.createdAt,
    this.updatedAt,
  });

  factory Vacuna.fromJson(Map<String, dynamic> json) {
    return Vacuna(
      id: json['id'],
      serverId: json['server_id'],
      nombrePaciente: json['nombre_paciente'],
      tipoPaciente: json['tipo_paciente'],
      cedulaPaciente: json['cedula_paciente'] ?? '',
      tipoVacuna: json['tipo_vacuna'],
      fechaVacunacion: json['fecha_vacunacion'],
      lote: json['lote'],
      proximaDosis: json['proxima_dosis'],
      usuarioId: json['usuario_id'],
      isSynced: json['is_synced'] == 1,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'server_id': serverId,
      'nombre_paciente': nombrePaciente,
      'tipo_paciente': tipoPaciente,
      'cedula_paciente': cedulaPaciente,
      'tipo_vacuna': tipoVacuna,
      'fecha_vacunacion': fechaVacunacion,
      'lote': lote,
      'proxima_dosis': proximaDosis,
      'usuario_id': usuarioId,
      'is_synced': isSynced ? 1 : 0,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  Map<String, dynamic> toServerJson() {
    return {
      'nombre_paciente': nombrePaciente,
      'tipo_paciente': tipoPaciente,
      'cedula_paciente': cedulaPaciente,
      'tipo_vacuna': tipoVacuna,
      'fecha_vacunacion': fechaVacunacion,
      'lote': lote,
      'proxima_dosis': proximaDosis,
      'local_id': id,
    };
  }

  String get fechaFormateada {
    final parts = fechaVacunacion.split('-');
    if (parts.length == 3) {
      return '${parts[2]}/${parts[1]}/${parts[0]}';
    }
    return fechaVacunacion;
  }
}