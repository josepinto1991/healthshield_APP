class Usuario {
  final int? id;
  final int? serverId;
  final String username;
  final String email;
  final String password;
  final String? telefono;
  final bool isProfessional;
  final String? professionalLicense;
  final bool isVerified;
  final bool isSynced;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Usuario({
    this.id,
    this.serverId,
    required this.username,
    required this.email,
    required this.password,
    this.telefono,
    this.isProfessional = false,
    this.professionalLicense,
    this.isVerified = false,
    this.isSynced = false,
    required this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'server_id': serverId,
      'username': username,
      'email': email,
      'password': password,
      'telefono': telefono,
      'is_professional': isProfessional ? 1 : 0,
      'professional_license': professionalLicense,
      'is_verified': isVerified ? 1 : 0,
      'is_synced': isSynced ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  Map<String, dynamic> toServerJson() {
    return {
      'username': username,
      'email': email,
      'password': password,
      'telefono': telefono,
      'is_professional': isProfessional,
      'professional_license': professionalLicense,
    };
  }
}