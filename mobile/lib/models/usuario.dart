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

  // Constructor para usuario vacío
  Usuario.empty()
      : id = null,
        serverId = null,
        username = '',
        email = '',
        password = '',
        telefono = null,
        isProfessional = false,
        professionalLicense = null,
        isVerified = false,
        isSynced = false,
        createdAt = DateTime.now(),
        updatedAt = null;

  // Verificar si el usuario está vacío
  bool get isEmpty => username.isEmpty;

  // Copiar usuario con nuevos valores
  Usuario copyWith({
    int? id,
    int? serverId,
    String? username,
    String? email,
    String? password,
    String? telefono,
    bool? isProfessional,
    String? professionalLicense,
    bool? isVerified,
    bool? isSynced,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Usuario(
      id: id ?? this.id,
      serverId: serverId ?? this.serverId,
      username: username ?? this.username,
      email: email ?? this.email,
      password: password ?? this.password,
      telefono: telefono ?? this.telefono,
      isProfessional: isProfessional ?? this.isProfessional,
      professionalLicense: professionalLicense ?? this.professionalLicense,
      isVerified: isVerified ?? this.isVerified,
      isSynced: isSynced ?? this.isSynced,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Convertir a JSON para enviar al servidor
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

  // Convertir a JSON para guardar localmente
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

  // Crear usuario desde JSON
  factory Usuario.fromJson(Map<String, dynamic> json) {
    return Usuario(
      id: json['id'],
      serverId: json['server_id'],
      username: json['username'],
      email: json['email'],
      password: json['password'],
      telefono: json['telefono'],
      isProfessional: json['is_professional'] == 1,
      professionalLicense: json['professional_license'],
      isVerified: json['is_verified'] == 1,
      isSynced: json['is_synced'] == 1,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
    );
  }

  @override
  String toString() {
    return 'Usuario{id: $id, username: $username, email: $email, isProfessional: $isProfessional, isVerified: $isVerified}';
  }
}