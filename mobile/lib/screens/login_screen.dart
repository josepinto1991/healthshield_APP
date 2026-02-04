import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _scrollController = ScrollController();
  
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _keyboardVisible = false;

  @override
  void initState() {
    super.initState();
    _usernameFocus.addListener(_onFocusChange);
    _passwordFocus.addListener(_onFocusChange);
    
    // Escuchar cambios en el teclado
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkKeyboard();
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _usernameFocus.dispose();
    _passwordFocus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (_usernameFocus.hasFocus || _passwordFocus.hasFocus) {
      // Scroll automático cuando un campo recibe foco
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToField(_usernameFocus.hasFocus ? _usernameFocus : _passwordFocus);
      });
    }
  }

  void _scrollToField(FocusNode focusNode) {
    final renderObject = focusNode.context?.findRenderObject();
    if (renderObject != null) {
      final position = renderObject.getTransformTo(null).getTranslation().y;
      _scrollController.animateTo(
        position.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
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

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      // Cerrar teclado primero
      FocusScope.of(context).unfocus();
      
      setState(() {
        _isLoading = true;
      });

      final authService = Provider.of<AuthService>(context, listen: false);
      
      final result = await authService.loginUsuario(
        _usernameController.text,
        _passwordController.text,
      );

      setState(() {
        _isLoading = false;
      });

      if (result['success']) {
        Navigator.pushReplacementNamed(context, '/main-menu');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error'] ?? 'Error en el login'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;
    
    return Scaffold(
      resizeToAvoidBottomInset: false, // IMPORTANTE: Previene redibujado completo
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: GestureDetector(
        onTap: () {
          // Cierra teclado al tocar fuera de campos
          FocusScope.of(context).unfocus();
        },
        child: Container(
          color: Colors.white,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  physics: ClampingScrollPhysics(), // Suave para Android
                  padding: EdgeInsets.only(
                    bottom: _keyboardVisible ? 200 : 50,
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: 32),
                          
                          Center(
                            child: Text(
                              'Iniciar Sesión',
                              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                            ),
                          ),
                          
                          SizedBox(height: 32),
                          
                          // Campo Usuario
                          Text('Usuario', style: TextStyle(fontWeight: FontWeight.bold)),
                          SizedBox(height: 8),
                          TextFormField(
                            controller: _usernameController,
                            focusNode: _usernameFocus,
                            decoration: InputDecoration(
                              hintText: 'Tu nombre de usuario',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.person),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Por favor ingresa tu usuario';
                              }
                              return null;
                            },
                            textInputAction: TextInputAction.next,
                            onFieldSubmitted: (_) {
                              FocusScope.of(context).requestFocus(_passwordFocus);
                            },
                          ),
                          
                          SizedBox(height: 16),
                          
                          // Campo Contraseña
                          Text('Contraseña', style: TextStyle(fontWeight: FontWeight.bold)),
                          SizedBox(height: 8),
                          TextFormField(
                            controller: _passwordController,
                            focusNode: _passwordFocus,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              hintText: 'Tu contraseña',
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
                                return 'Por favor ingresa tu contraseña';
                              }
                              return null;
                            },
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) {
                              FocusScope.of(context).unfocus();
                              _login();
                            },
                          ),
                          
                          SizedBox(height: 32),
                          
                          // Botón Iniciar Sesión
                          Container(
                            margin: EdgeInsets.only(bottom: 24),
                            child: SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _login,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: _isLoading 
                                    ? CircularProgressIndicator(color: Colors.white)
                                    : Text('Iniciar Sesión', style: TextStyle(fontSize: 16)),
                              ),
                            ),
                          ),
                          
                          // Opción de registro
                          Center(
                            child: TextButton(
                              onPressed: () {
                                Navigator.pushNamed(context, '/register');
                              },
                              child: Text(
                                '¿No tienes cuenta? Regístrate',
                                style: TextStyle(color: Colors.blue),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              
              // Espacio seguro para botones del dispositivo
              SizedBox(height: bottomPadding > 0 ? bottomPadding : 16),
            ],
          ),
        ),
      ),
    );
  }
}