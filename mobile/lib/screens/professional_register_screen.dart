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
  
  // Focus nodes para manejo de teclado
  final _usernameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _telefonoFocus = FocusNode();
  final _licenseFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmPasswordFocus = FocusNode();
  
  final _scrollController = ScrollController();
  
  bool _isRegistering = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _keyboardVisible = false;
  String _tipoUsuario = 'professional';
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    
    // Agregar listeners a focus nodes
    final focusNodes = [
      _usernameFocus, _emailFocus, _telefonoFocus,
      _licenseFocus, _passwordFocus, _confirmPasswordFocus
    ];
    
    for (var focus in focusNodes) {
      focus.addListener(() {
        if (focus.hasFocus) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToField(focus);
          });
        }
      });
    }
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkKeyboard();
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _telefonoController.dispose();
    _professionalLicenseController.dispose();
    
    _usernameFocus.dispose();
    _emailFocus.dispose();
    _telefonoFocus.dispose();
    _licenseFocus.dispose();
    _passwordFocus.dispose();
    _confirmPasswordFocus.dispose();
    _scrollController.dispose();
    
    super.dispose();
  }

  void _scrollToField(FocusNode focusNode) {
    final context = focusNode.context;
    if (context != null) {
      final renderObject = context.findRenderObject();
      if (renderObject != null) {
        final translation = renderObject.getTransformTo(null).getTranslation();
        if (translation != null) {
          final position = translation.y;
          _scrollController.animateTo(
            position.clamp(0.0, _scrollController.position.maxScrollExtent),
            duration: Duration(milliseconds: 250),
            curve: Curves.easeInOut,
          );
        }
      }
    }
  }

  void _checkKeyboard() {
    final mediaQuery = MediaQuery.of(context);
    if (mediaQuery.viewInsets.bottom > 0) {
      if (!_keyboardVisible) {
        setState(() {
          _keyboardVisible = true;
        });
      }
    } else {
      if (_keyboardVisible) {
        setState(() {
          _keyboardVisible = false;
        });
      }
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

    // Verificar permisos para crear administrador
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUser = authService.currentUser;
    
    if (_tipoUsuario == 'admin' && !(currentUser?.isAdmin ?? false)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Solo administradores pueden crear otros administradores'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Cerrar teclado antes de registrar
    FocusScope.of(context).unfocus();
    
    setState(() {
      _isRegistering = true;
    });

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
      role: _tipoUsuario,
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
      
      String message = '✅ Usuario registrado exitosamente\n\n';
      message += 'Puedes iniciar sesión con:\n';
      message += 'Usuario: ${nuevoUsuario.username}\n';
      message += 'Contraseña: ${_passwordController.text}\n\n';
      message += 'Rol: ${_tipoUsuario == 'admin' ? 'Administrador 👑' : 'Profesional de Salud 👨‍⚕️'}';
      
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
                Navigator.pop(context, true); // Retornar éxito para refrescar lista
              },
              child: Text('Aceptar'),
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

  Widget _buildTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required IconData icon,
    bool isPassword = false,
    bool obscureText = false,
    VoidCallback? onToggleObscure,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    String? hintText,
    TextInputAction textInputAction = TextInputAction.next,
    FocusNode? nextFocus,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label *', style: TextStyle(fontWeight: FontWeight.bold)),
        SizedBox(height: 8),
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          obscureText: obscureText,
          decoration: InputDecoration(
            hintText: hintText,
            border: OutlineInputBorder(),
            prefixIcon: Icon(icon),
            suffixIcon: isPassword && onToggleObscure != null
                ? IconButton(
                    icon: Icon(
                      obscureText ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: onToggleObscure,
                  )
                : null,
          ),
          keyboardType: keyboardType,
          validator: validator,
          textInputAction: textInputAction,
          onFieldSubmitted: (_) {
            if (nextFocus != null) {
              FocusScope.of(context).requestFocus(nextFocus);
            } else {
              FocusScope.of(context).unfocus();
            }
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;
    final authService = Provider.of<AuthService>(context);
    final currentUser = authService.currentUser;
    final puedeCrearAdmin = currentUser?.isAdmin ?? false;
    
    return Scaffold(
      resizeToAvoidBottomInset: false, // CRÍTICO para rendimiento
      appBar: AppBar(
        title: Text(
          'Crear Nuevo Usuario',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: GestureDetector(
        onTap: () {
          // Cierra teclado al tocar fuera
          FocusScope.of(context).unfocus();
        },
        child: Container(
          color: Colors.white,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  physics: ClampingScrollPhysics(), // Optimizado para Android
                  padding: EdgeInsets.only(
                    bottom: _keyboardVisible ? 300 : 100,
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Registro de Usuario',
                            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                          ),
                          
                          SizedBox(height: 8),
                          
                          Text(
                            'Crear nueva cuenta de usuario',
                            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                          ),
                          
                          SizedBox(height: 24),
                          
                          // Tipo de Usuario
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Tipo de Usuario *', style: TextStyle(fontWeight: FontWeight.bold)),
                              SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: ChoiceChip(
                                      label: Text('Profesional'),
                                      selected: _tipoUsuario == 'professional',
                                      selectedColor: Colors.blue,
                                      onSelected: (selected) {
                                        if (selected) {
                                          setState(() {
                                            _tipoUsuario = 'professional';
                                            _isAdmin = false;
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                  SizedBox(width: 16),
                                  Expanded(
                                    child: ChoiceChip(
                                      label: Text('Administrador'),
                                      selected: _tipoUsuario == 'admin',
                                      selectedColor: Colors.red,
                                      onSelected: puedeCrearAdmin ? (selected) {
                                        if (selected) {
                                          setState(() {
                                            _tipoUsuario = 'admin';
                                            _isAdmin = true;
                                          });
                                        }
                                      } : null,
                                      disabledColor: Colors.grey[300],
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 8),
                              Text(
                                _tipoUsuario == 'admin' 
                                    ? (puedeCrearAdmin 
                                        ? '👑 Usuario con permisos completos del sistema'
                                        : '❌ Solo administradores pueden crear otros administradores')
                                    : '👨‍⚕️ Usuario con permisos profesionales',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _tipoUsuario == 'admin' 
                                      ? (puedeCrearAdmin ? Colors.orange[700] : Colors.red)
                                      : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                          
                          SizedBox(height: 24),
                          
                          // Usuario
                          _buildTextField(
                            controller: _usernameController,
                            focusNode: _usernameFocus,
                            label: 'Usuario',
                            icon: Icons.person,
                            hintText: 'Nombre de usuario único',
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'El usuario es obligatorio';
                              }
                              if (value.length < 3) {
                                return 'Mínimo 3 caracteres';
                              }
                              return null;
                            },
                            textInputAction: TextInputAction.next,
                            nextFocus: _emailFocus,
                          ),
                          
                          SizedBox(height: 16),
                          
                          // Email
                          _buildTextField(
                            controller: _emailController,
                            focusNode: _emailFocus,
                            label: 'Correo Electrónico',
                            icon: Icons.email,
                            hintText: 'ejemplo@email.com',
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'El email es obligatorio';
                              }
                              if (!value.contains('@')) {
                                return 'Ingresa un email válido';
                              }
                              return null;
                            },
                            textInputAction: TextInputAction.next,
                            nextFocus: _telefonoFocus,
                          ),
                          
                          SizedBox(height: 16),
                          
                          // Teléfono (Opcional)
                          _buildTextField(
                            controller: _telefonoController,
                            focusNode: _telefonoFocus,
                            label: 'Teléfono (Opcional)',
                            icon: Icons.phone,
                            hintText: 'Ej: 0412-1234567',
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.next,
                            nextFocus: _licenseFocus,
                          ),
                          
                          SizedBox(height: 16),
                          
                          // Matrícula Profesional (Opcional)
                          _buildTextField(
                            controller: _professionalLicenseController,
                            focusNode: _licenseFocus,
                            label: 'Matrícula Profesional',
                            icon: Icons.badge,
                            hintText: 'Ej: MP-12345',
                            textInputAction: TextInputAction.next,
                            nextFocus: _passwordFocus,
                          ),
                          
                          SizedBox(height: 16),
                          
                          // Contraseña
                          _buildTextField(
                            controller: _passwordController,
                            focusNode: _passwordFocus,
                            label: 'Contraseña',
                            icon: Icons.lock,
                            isPassword: true,
                            obscureText: _obscurePassword,
                            onToggleObscure: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                            hintText: 'Mínimo 6 caracteres',
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'La contraseña es obligatoria';
                              }
                              if (value.length < 6) {
                                return 'La contraseña debe tener al menos 6 caracteres';
                              }
                              return null;
                            },
                            textInputAction: TextInputAction.next,
                            nextFocus: _confirmPasswordFocus,
                          ),
                          
                          SizedBox(height: 16),
                          
                          // Confirmar Contraseña
                          _buildTextField(
                            controller: _confirmPasswordController,
                            focusNode: _confirmPasswordFocus,
                            label: 'Confirmar Contraseña',
                            icon: Icons.lock_reset,
                            isPassword: true,
                            obscureText: _obscureConfirmPassword,
                            onToggleObscure: () {
                              setState(() {
                                _obscureConfirmPassword = !_obscureConfirmPassword;
                              });
                            },
                            hintText: 'Repite tu contraseña',
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Confirma tu contraseña';
                              }
                              return null;
                            },
                            textInputAction: TextInputAction.done,
                          ),
                          
                          SizedBox(height: 32),
                          
                          // Botón de registro
                          Container(
                            margin: EdgeInsets.only(bottom: 24),
                            child: SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: (_isRegistering || (_tipoUsuario == 'admin' && !puedeCrearAdmin)) 
                                    ? null 
                                    : _completeRegistration,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _tipoUsuario == 'admin' ? Colors.red : Colors.green,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: _isRegistering
                                    ? CircularProgressIndicator(color: Colors.white)
                                    : Text(
                                        _tipoUsuario == 'admin' 
                                            ? 'Registrar como Administrador'
                                            : 'Registrar como Profesional',
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
                                      Icon(
                                        _tipoUsuario == 'admin' 
                                            ? Icons.admin_panel_settings 
                                            : Icons.medical_services, 
                                        color: _tipoUsuario == 'admin' ? Colors.red : Colors.blue
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        _tipoUsuario == 'admin' 
                                            ? 'Cuenta de Administrador'
                                            : 'Cuenta de Profesional',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold, 
                                          color: _tipoUsuario == 'admin' ? Colors.red : Colors.blue
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 8),
                                  if (_tipoUsuario == 'admin') ...[
                                    Text('• Acceso completo a todas las funciones del sistema'),
                                    Text('• Puede crear y gestionar otros usuarios'),
                                    Text('• Panel administrativo completo'),
                                    Text('• Permisos de superusuario'),
                                  ] else ...[
                                    Text('• Acceso completo a registro de vacunas y pacientes'),
                                    Text('• Puede registrar vacunas y pacientes'),
                                    Text('• Sincronización con el servidor'),
                                    Text('• Sin acceso administrativo'),
                                  ],
                                  SizedBox(height: 8),
                                  Text(
                                    'Nota: El usuario podrá cambiar su contraseña después.',
                                    style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          
                          SizedBox(height: 16),
                          
                          // Espacio extra cuando hay teclado
                          SizedBox(height: _keyboardVisible ? 60 : 24),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              
              // Espacio para botones del dispositivo
              SizedBox(height: bottomPadding > 0 ? bottomPadding : 16),
            ],
          ),
        ),
      ),
    );
  }
}