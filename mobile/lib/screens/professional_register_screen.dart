import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../models/usuario.dart';

class ProfessionalRegisterScreen extends StatefulWidget {
  @override
  _ProfessionalRegisterScreenState createState() => _ProfessionalRegisterScreenState();
}

class _ProfessionalRegisterScreenState extends State<ProfessionalRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _cedulaController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _telefonoController = TextEditingController();
  
  bool _isVerifying = false;
  bool _isVerified = false;
  bool _isRegistering = false;
  Map<String, dynamic>? _verificationResult;

  Future<void> _verifyProfessional() async {
    if (_cedulaController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Por favor ingresa tu cédula')),
      );
      return;
    }

    setState(() {
      _isVerifying = true;
      _isVerified = false;
      _verificationResult = null;
    });

    final apiService = Provider.of<ApiService>(context, listen: false);
    
    final result = await apiService.verifyProfessional(_cedulaController.text);

    setState(() {
      _isVerifying = false;
      _isVerified = result['is_valid'] ?? false;
      _verificationResult = result;
    });

    if (_isVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ ${result['message']}'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Auto-completar username con cédula
      if (_usernameController.text.isEmpty) {
        _usernameController.text = _cedulaController.text;
      }
      
      // Sugerir email basado en nombre
      if (_emailController.text.isEmpty && result['professional_name'] != null) {
        final name = result['professional_name'].toString().toLowerCase();
        final email = name.replaceAll(' ', '.').replaceAll(RegExp(r'[^a-z.]'), '');
        _emailController.text = '$email@salud.gob.ve';
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ ${result['message']}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _completeRegistration() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Las contraseñas no coinciden')),
      );
      return;
    }

    setState(() {
      _isRegistering = true;
    });

    final authService = Provider.of<AuthService>(context, listen: false);
    final apiService = Provider.of<ApiService>(context, listen: false);

    final nuevoUsuario = Usuario(
      username: _usernameController.text,
      email: _emailController.text,
      password: _passwordController.text,
      telefono: _telefonoController.text.isEmpty ? null : _telefonoController.text,
      isProfessional: true,
      professionalLicense: _verificationResult?['professional_license']?.toString(),
      isVerified: false, // Inicialmente no verificado en modo offline
      isSynced: false, // Requerirá sincronización
      createdAt: DateTime.now(),
    );

    // Intentar registro con verificación si está disponible
    final cedulaVerificacion = _cedulaController.text.trim();
    final hasVerification = cedulaVerificacion.isNotEmpty && _isVerified;

    final result = await authService.registrarUsuarioProfesional(
      usuario: nuevoUsuario,
      cedulaVerificacion: hasVerification ? cedulaVerificacion : '',
    );

    setState(() {
      _isRegistering = false;
    });

    if (result['success']) {
      final bool isOffline = result['isOffline'] ?? true;
      final bool requiresSync = result['requiresSync'] ?? false;
      
      String message = result['message'] ?? 'Registro exitoso';
      
      if (isOffline) {
        message += '\nTrabajando en modo offline.';
        if (requiresSync) {
          message += '\nLos datos se sincronizarán automáticamente cuando haya conexión.';
        }
      }
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(isOffline ? '📴 Registro Offline' : '✅ Registro Exitoso'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message),
              SizedBox(height: 16),
              if (isOffline && requiresSync)
                Row(
                  children: [
                    Icon(Icons.sync, color: Colors.orange, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Recuerda conectarte a internet para completar la verificación profesional.',
                        style: TextStyle(fontSize: 12, color: Colors.orange),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushReplacementNamed(context, '/login');
              },
              child: Text('Continuar'),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ ${result['error']}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'HealthShield',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Registro de Profesional',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              
              SizedBox(height: 8),
              
              Text(
                'Verificación requerida para profesionales de salud',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
              
              SizedBox(height: 32),
              
              // Cédula para verificación
              Text('Cédula de Identidad *', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _cedulaController,
                      decoration: InputDecoration(
                        hintText: 'Ej: 12345678',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.badge),
                        suffixIcon: _isVerified 
                            ? Icon(Icons.verified, color: Colors.green)
                            : null,
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'La cédula es obligatoria para verificación';
                        }
                        if (value.length < 6) {
                          return 'La cédula debe tener al menos 6 dígitos';
                        }
                        return null;
                      },
                    ),
                  ),
                  SizedBox(width: 8),
                  _isVerifying
                      ? CircularProgressIndicator()
                      : ElevatedButton(
                          onPressed: _isVerifying ? null : _verifyProfessional,
                          child: Text('Verificar'),
                        ),
                ],
              ),
              
              // Resultado de verificación
              if (_verificationResult != null)
                _buildVerificationResultCard(),
              
              SizedBox(height: 24),
              
              // Campos de registro
              Text('Usuario *', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              TextFormField(
                controller: _usernameController,
                decoration: InputDecoration(
                  hintText: 'Nombre de usuario',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'El usuario es obligatorio';
                  }
                  return null;
                },
              ),
              
              SizedBox(height: 16),
              
              Text('Correo Electrónico *', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                  hintText: 'ejemplo@salud.gob.ve',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'El email es obligatorio';
                  }
                  if (!value.contains('@')) {
                    return 'Ingresa un email válido';
                  }
                  return null;
                },
              ),
              
              SizedBox(height: 16),
              
              Text('Teléfono (Opcional)', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              TextFormField(
                controller: _telefonoController,
                decoration: InputDecoration(
                  hintText: 'Ej: 0412-1234567',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
              ),
              
              SizedBox(height: 16),
              
              Text('Contraseña *', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  hintText: 'Mínimo 6 caracteres',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'La contraseña es obligatoria';
                  }
                  if (value.length < 6) {
                    return 'La contraseña debe tener al menos 6 caracteres';
                  }
                  return null;
                },
              ),
              
              SizedBox(height: 16),
              
              Text('Confirmar Contraseña *', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  hintText: 'Repite tu contraseña',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock_reset),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Confirma tu contraseña';
                  }
                  return null;
                },
              ),
              
              SizedBox(height: 32),
              
              // Botón de registro
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isRegistering ? null : _completeRegistration,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isVerified ? Colors.green : Colors.grey,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isRegistering
                      ? CircularProgressIndicator(color: Colors.white)
                      : Text(
                          _isVerified ? 'Completar Registro' : 'Verifica tu cédula primero',
                          style: TextStyle(fontSize: 16),
                        ),
                ),
              ),
              
              SizedBox(height: 16),
              
              // Información
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Información del Proceso',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),
                      Text('• Solo profesionales de salud pueden registrarse'),
                      Text('• La verificación requiere conexión a internet'),
                      Text('• Se consulta el registro oficial del SACS'),
                      Text('• El login posterior funciona sin conexión'),
                      Text('• Fuente: https://sistemas.sacs.gob.ve'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVerificationResultCard() {
    return Card(
      color: _isVerified ? Colors.green[50] : Colors.orange[50],
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _isVerified ? Icons.verified : Icons.warning,
                  color: _isVerified ? Colors.green : Colors.orange,
                ),
                SizedBox(width: 8),
                Text(
                  _isVerified ? 'Verificación Exitosa' : 'Verificación Requerida',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _isVerified ? Colors.green : Colors.orange,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(_verificationResult!['message']),
            if (_verificationResult!['professional_name'] != null)
              Text('Nombre: ${_verificationResult!['professional_name']}'),
            if (_verificationResult!['especialidad'] != null)
              Text('Especialidad: ${_verificationResult!['especialidad']}'),
            if (_verificationResult!['professional_license'] != null)
              Text('Matrícula: ${_verificationResult!['professional_license']}'),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _cedulaController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _telefonoController.dispose();
    super.dispose();
  }
}