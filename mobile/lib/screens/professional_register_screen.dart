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
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _professionalLicenseController = TextEditingController();
  
  bool _isRegistering = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

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

    final nuevoUsuario = Usuario(
      username: _usernameController.text,
      email: _emailController.text,
      password: _passwordController.text,
      telefono: _telefonoController.text.isEmpty ? null : _telefonoController.text,
      isProfessional: true,
      professionalLicense: _professionalLicenseController.text.isEmpty 
          ? null 
          : _professionalLicenseController.text,
      isVerified: true,
      role: 'professional',
      isSynced: false,
      createdAt: DateTime.now(),
    );

    final result = await authService.registrarUsuarioProfesional(
      usuario: nuevoUsuario,
      cedulaVerificacion: '',
    );

    setState(() {
      _isRegistering = false;
    });

    if (result['success']) {
      final bool isOffline = result['isOffline'] ?? true;
      
      String message = '✅ Profesional registrado exitosamente\n\n';
      message += 'Puedes iniciar sesión con:\n';
      message += 'Usuario: ${nuevoUsuario.username}\n';
      message += 'Contraseña: ${_passwordController.text}\n\n';
      message += 'Rol: Profesional de Salud';
      
      if (isOffline) {
        message += '\n\n📱 Los datos se sincronizarán cuando haya conexión.';
      }
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('✅ Registro Exitoso'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message),
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.all(12),
                  color: Colors.blue[50],
                  child: Text(
                    '💡 Guarda estas credenciales. Necesitarás iniciar sesión después.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushReplacementNamed(context, '/login');
              },
              child: Text('Ir al Login'),
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
    // 🔥 OBTENER PADDING INFERIOR SEGURO
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    
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
        // 🔥 PADDING DINÁMICO CON ESPACIO PARA BOTONES DEL DISPOSITIVO
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: 24 + bottomPadding + bottomInset,
        ),
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
                'Crear cuenta para profesionales de la salud',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
              
              SizedBox(height: 32),
              
              // Usuario
              Text('Usuario *', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              TextFormField(
                controller: _usernameController,
                decoration: InputDecoration(
                  hintText: 'Nombre de usuario único',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'El usuario es obligatorio';
                  }
                  if (value.length < 3) {
                    return 'Mínimo 3 caracteres';
                  }
                  return null;
                },
              ),
              
              SizedBox(height: 16),
              
              // Email
              Text('Correo Electrónico *', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                  hintText: 'ejemplo@email.com',
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
              
              // Teléfono (Opcional)
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
              
              // Matrícula Profesional (Opcional)
              Text('Matrícula Profesional *', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              TextFormField(
                controller: _professionalLicenseController,
                decoration: InputDecoration(
                  hintText: 'Ej: MP-12345',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.badge),
                ),
              ),
              
              SizedBox(height: 16),
              
              // Contraseña
              Text('Contraseña *', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  hintText: 'Mínimo 6 caracteres',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
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
              
              // Confirmar Contraseña
              Text('Confirmar Contraseña *', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirmPassword,
                decoration: InputDecoration(
                  hintText: 'Repite tu contraseña',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock_reset),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureConfirmPassword = !_obscureConfirmPassword;
                      });
                    },
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Confirma tu contraseña';
                  }
                  return null;
                },
              ),
              
              SizedBox(height: 32),
              
              // 🔥 BOTÓN CON MARGEN DINÁMICO PARA EVITAR SUPERPOSICIÓN
              Container(
                margin: EdgeInsets.only(bottom: 24 + bottomPadding),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isRegistering ? null : _completeRegistration,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isRegistering
                        ? CircularProgressIndicator(color: Colors.white)
                        : Text(
                            'Registrarse como Profesional',
                            style: TextStyle(fontSize: 16),
                          ),
                  ),
                ),
              ),
              
              // Información
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.medical_services, color: Colors.blue),
                          SizedBox(width: 8),
                          Text(
                            'Cuenta de Profesional',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text('• Acceso completo a todas las funciones'),
                      Text('• Puede registrar vacunas y pacientes'),
                      Text('• Panel administrativo si es necesario'),
                      Text('• Sincronización con el servidor'),
                      SizedBox(height: 8),
                      Text(
                        'Nota: No se requiere verificación externa.',
                        style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
              
              SizedBox(height: 16),
              
              // Enlace para usuarios normales
              Center(
                child: TextButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Para registro normal, usa el botón "Regístrate" en la pantalla de inicio')),
                    );
                  },
                  child: Text(
                    '¿Eres usuario normal?',
                    style: TextStyle(color: Colors.blue),
                  ),
                ),
              ),
              
              // 🔥 ESPACIO EXTRA ADICIONAL CUANDO EL TECLADO ESTÁ VISIBLE
              SizedBox(height: bottomInset > 0 ? 80 : 24),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _telefonoController.dispose();
    _professionalLicenseController.dispose();
    super.dispose();
  }
}