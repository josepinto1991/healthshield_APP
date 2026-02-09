import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/usuario.dart';
import '../services/auth_service.dart';

class DetalleUsuarioScreen extends StatefulWidget {
  final Usuario usuario;

  DetalleUsuarioScreen({required this.usuario});

  @override
  _DetalleUsuarioScreenState createState() => _DetalleUsuarioScreenState();
}

class _DetalleUsuarioScreenState extends State<DetalleUsuarioScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _licenseController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  String _tipoUsuario = 'professional';
  bool _isEditing = false;
  bool _isChangingPassword = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    _cargarDatosUsuario();
  }

  void _cargarDatosUsuario() {
    final usuario = widget.usuario;
    _usernameController.text = usuario.username;
    _emailController.text = usuario.email;
    _telefonoController.text = usuario.telefono ?? '';
    _licenseController.text = usuario.professionalLicense ?? '';
    _tipoUsuario = usuario.role;
  }

  Future<void> _actualizarUsuario() async {
    if (_formKey.currentState!.validate()) {
      final authService = Provider.of<AuthService>(context, listen: false);
      
      final usuarioActualizado = widget.usuario.copyWith(
        username: _usernameController.text,
        email: _emailController.text,
        telefono: _telefonoController.text.isNotEmpty ? _telefonoController.text : null,
        professionalLicense: _licenseController.text.isNotEmpty ? _licenseController.text : null,
        role: _tipoUsuario,
        isProfessional: _tipoUsuario == 'professional' || _tipoUsuario == 'admin',
      );
      
      final success = await authService.actualizarUsuario(usuarioActualizado);
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Usuario actualizado exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {
          _isEditing = false;
        });
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error al actualizar usuario'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _cambiarPassword() async {
    if (_newPasswordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Por favor ingresa una nueva contraseña')),
      );
      return;
    }
    
    if (_newPasswordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Las contraseñas no coinciden')),
      );
      return;
    }
    
    final authService = Provider.of<AuthService>(context, listen: false);
    final success = await authService.cambiarPassword(
      widget.usuario.id!, 
      _newPasswordController.text
    );
    
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Contraseña cambiada exitosamente'),
          backgroundColor: Colors.green,
        ),
      );
      setState(() {
        _isChangingPassword = false;
        _newPasswordController.clear();
        _confirmPasswordController.clear();
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error al cambiar contraseña'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _eliminarUsuario() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUser = authService.currentUser;
    
    if (widget.usuario.id == currentUser?.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ No puedes eliminar tu propio usuario'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Eliminar Usuario'),
        content: Text(
          '¿Estás seguro de eliminar al usuario ${widget.usuario.username}?\n\n'
          'Esta acción no se puede deshacer y eliminará todos los datos del usuario.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await authService.eliminarUsuario(widget.usuario.id!);
              
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('✅ Usuario eliminado exitosamente'),
                    backgroundColor: Colors.green,
                  ),
                );
                Navigator.pop(context, true);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('❌ Error al eliminar usuario'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, {IconData? icon}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: Colors.grey[600]),
                SizedBox(width: 8),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final usuario = widget.usuario;
    final authService = Provider.of<AuthService>(context);
    final currentUser = authService.currentUser;
    final isCurrentUser = usuario.id == currentUser?.id;
    final puedeEditar = currentUser?.isAdmin ?? false;
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Detalles del Usuario'),
        actions: [
          if (!_isEditing && !_isChangingPassword && puedeEditar)
            IconButton(
              icon: Icon(Icons.edit),
              onPressed: () {
                setState(() {
                  _isEditing = true;
                });
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isChangingPassword) _buildFormularioPassword()
            else if (_isEditing) _buildFormularioEdicion()
            else _buildVistaDetalle(),
            
            SizedBox(height: 24),
            
            // Botones de acción
            if (!_isEditing && !_isChangingPassword && puedeEditar)
              Column(
                children: [
                  Divider(),
                  SizedBox(height: 16),
                  Text('Acciones', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  SizedBox(height: 16),
                  
                  if (!isCurrentUser)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _isChangingPassword ? null : () {
                          setState(() {
                            _isChangingPassword = true;
                          });
                        },
                        icon: Icon(Icons.lock),
                        label: Text('Cambiar Contraseña'),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          side: BorderSide(color: Colors.blue),
                        ),
                      ),
                    ),
                  
                  if (!isCurrentUser) SizedBox(height: 12),
                  
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _eliminarUsuario,
                      icon: Icon(Icons.delete),
                      label: Text('Eliminar Usuario'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVistaDetalle() {
    final usuario = widget.usuario;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header con avatar
        Center(
          child: Column(
            children: [
              CircleAvatar(
                backgroundColor: usuario.colorRol,
                radius: 40,
                child: Icon(
                  usuario.iconRol,
                  size: 40,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 16),
              Text(
                usuario.username,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Chip(
                label: Text(
                  usuario.tipoUsuarioMostrar,
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
                backgroundColor: usuario.colorRol,
              ),
            ],
          ),
        ),
        
        SizedBox(height: 32),
        
        // Información del usuario
        Card(
          elevation: 2,
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoItem('Usuario', usuario.username, icon: Icons.person),
                Divider(),
                _buildInfoItem('Email', usuario.email ?? 'No especificado', icon: Icons.email),
                Divider(),
                _buildInfoItem('Teléfono', usuario.telefono ?? 'No especificado', icon: Icons.phone),
                Divider(),
                _buildInfoItem('Matrícula Profesional', 
                  usuario.professionalLicense ?? 'No especificada', icon: Icons.badge),
                Divider(),
                _buildInfoItem('Tipo de Usuario', usuario.tipoUsuarioMostrar, icon: Icons.category),
                Divider(),
                _buildInfoItem('Estado', usuario.isVerified ? 'Verificado ✅' : 'No verificado ⚠️', icon: Icons.verified),
                Divider(),
                _buildInfoItem('Sincronización', usuario.isSynced ? 'Sincronizado ☁️' : 'Pendiente 📱', icon: Icons.sync),
                Divider(),
                _buildInfoItem('Fecha de Creación', 
                  '${usuario.createdAt.day}/${usuario.createdAt.month}/${usuario.createdAt.year} '
                  '${usuario.createdAt.hour}:${usuario.createdAt.minute.toString().padLeft(2, '0')}',
                  icon: Icons.calendar_today
                ),
                if (usuario.updatedAt != null) ...[
                  Divider(),
                  _buildInfoItem('Última Actualización', 
                    '${usuario.updatedAt!.day}/${usuario.updatedAt!.month}/${usuario.updatedAt!.year}',
                    icon: Icons.update
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFormularioEdicion() {
    final authService = Provider.of<AuthService>(context);
    final currentUser = authService.currentUser;
    final puedeCrearAdmin = currentUser?.isAdmin ?? false;
    
    return Form(
      key: _formKey,
      child: Column(
        children: [
          Text(
            'Editar Usuario',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 24),
          
          TextFormField(
            controller: _usernameController,
            decoration: InputDecoration(
              labelText: 'Usuario',
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
          
          TextFormField(
            controller: _emailController,
            decoration: InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.email),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'El email es obligatorio';
              }
              if (!value.contains('@')) {
                return 'Email inválido';
              }
              return null;
            },
          ),
          
          SizedBox(height: 16),
          
          TextFormField(
            controller: _telefonoController,
            decoration: InputDecoration(
              labelText: 'Teléfono',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.phone),
            ),
          ),
          
          SizedBox(height: 16),
          
          TextFormField(
            controller: _licenseController,
            decoration: InputDecoration(
              labelText: 'Matrícula Profesional',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.badge),
            ),
          ),
          
          SizedBox(height: 16),
          
          // Tipo de Usuario
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tipo de Usuario', style: TextStyle(fontWeight: FontWeight.bold)),
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
                _tipoUsuario == 'admin' && !puedeCrearAdmin
                    ? '❌ Solo administradores pueden asignar este rol'
                    : _tipoUsuario == 'admin'
                        ? '👑 Usuario con permisos completos'
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
          
          SizedBox(height: 32),
          
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _isEditing = false;
                      _cargarDatosUsuario();
                    });
                  },
                  child: Text('Cancelar'),
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _actualizarUsuario,
                  child: Text('Guardar Cambios'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFormularioPassword() {
    return Column(
      children: [
        Text(
          'Cambiar Contraseña',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 24),
        
        TextFormField(
          controller: _newPasswordController,
          obscureText: _obscurePassword,
          decoration: InputDecoration(
            labelText: 'Nueva Contraseña',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.lock),
            suffixIcon: IconButton(
              icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
              onPressed: () {
                setState(() {
                  _obscurePassword = !_obscurePassword;
                });
              },
            ),
          ),
        ),
        
        SizedBox(height: 16),
        
        TextFormField(
          controller: _confirmPasswordController,
          obscureText: _obscureConfirmPassword,
          decoration: InputDecoration(
            labelText: 'Confirmar Contraseña',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.lock_reset),
            suffixIcon: IconButton(
              icon: Icon(_obscureConfirmPassword ? Icons.visibility : Icons.visibility_off),
              onPressed: () {
                setState(() {
                  _obscureConfirmPassword = !_obscureConfirmPassword;
                });
              },
            ),
          ),
        ),
        
        SizedBox(height: 32),
        
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  setState(() {
                    _isChangingPassword = false;
                    _newPasswordController.clear();
                    _confirmPasswordController.clear();
                  });
                },
                child: Text('Cancelar'),
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                onPressed: _cambiarPassword,
                child: Text('Cambiar Contraseña'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}