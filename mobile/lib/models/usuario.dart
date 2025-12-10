
class Usuario {
  int? id;
  int? serverId;
  String username;
  String email;
  String password;
  String? telefono;
  bool isProfessional;
  String? professionalLicense;
  bool isVerified;
  String role;
  bool isSynced;
  DateTime createdAt;
  DateTime? updatedAt;

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
    this.role = 'user',
    this.isSynced = false,
    required this.createdAt,
    this.updatedAt,
  });

  factory Usuario.fromJson(Map<String, dynamic> json) {
    return Usuario(
      id: json['id'],
      serverId: json['server_id'],
      username: json['username'],
      email: json['email'],
      password: json['password'],
      telefono: json['telefono'],
      isProfessional: json['is_professional'] == 1 || json['is_professional'] == true,
      professionalLicense: json['professional_license'],
      isVerified: json['is_verified'] == 1 || json['is_verified'] == true,
      role: json['role'] ?? 'user',
      isSynced: json['is_synced'] == 1 || json['is_synced'] == true,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
    );
  }

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
      'role': role,
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
      'role': role,
      'local_id': id,
    };
  }

  Map<String, dynamic> toLoginJson() {
    return {
      'username': username,
      'password': password,
    };
  }

  static Usuario empty() {
    return Usuario(
      username: '',
      email: '',
      password: '',
      role: 'user',
      createdAt: DateTime.now(),
    );
  }

  bool get isEmpty {
    return username.isEmpty || email.isEmpty || password.isEmpty;
  }

  // SOLO UNA VEZ ESTAS PROPIEDADES - ELIMINA LAS DUPLICADAS
  bool get isAdmin => role == 'admin';
  bool get isProfessionalUser => role == 'professional' || isProfessional;
  bool get isUser => role == 'user';

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
    String? role,
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
      role: role ?? this.role,
      isSynced: isSynced ?? this.isSynced,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}