import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../models/usuario.dart';

class AdminUsuariosScreen extends StatefulWidget {
  @override
  _AdminUsuariosScreenState createState() => _AdminUsuariosScreenState();
}

class _AdminUsuariosScreenState extends State<AdminUsuariosScreen> {
  List<Usuario> _usuarios = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUsuarios();
  }

  Future<void> _loadUsuarios() async {
    setState(() {
      _isLoading = true;
    });

    final authService = Provider.of<AuthService>(context, listen: false);
    final usuarios = await authService.getUsuarios();
    
    setState(() {
      _usuarios = usuarios;
      _isLoading = false;
    });
  }

  Future<void> _crearUsuarioAdmin() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Crear Usuario Admin'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('¿Crear usuario administrador por defecto?'),
            SizedBox(height: 16),
            Text('Usuario: admin'),
            Text('Contraseña: admin123'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _crearAdmin();
            },
            child: Text('Crear'),
          ),
        ],
      ),
    );
  }

  Future<void> _crearAdmin() async {
    final nuevoUsuario = Usuario(
      username: 'admin',
      email: 'admin@healthshield.com',
      password: 'admin123',
      role: 'admin',
      isProfessional: true,
      professionalLicense: 'ADM-001',
      isVerified: true,
      isSynced: true,
      createdAt: DateTime.now(),
    );

    final authService = Provider.of<AuthService>(context, listen: false);
    final success = await authService.registrarUsuario(nuevoUsuario);
    
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Usuario admin creado'),
          backgroundColor: Colors.green,
        ),
      );
      await _loadUsuarios();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error creando usuario o usuario ya existe'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _cambiarRol(Usuario usuario, String nuevoRol) async {
    final usuarioActualizado = usuario.copyWith(role: nuevoRol);
    final authService = Provider.of<AuthService>(context, listen: false);
    
    final success = await authService.actualizarUsuario(usuarioActualizado);
    
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Rol actualizado a $nuevoRol'),
          backgroundColor: Colors.green,
        ),
      );
      await _loadUsuarios();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error actualizando rol'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildRoleChip(String role) {
    Color color;
    switch (role) {
      case 'admin':
        color = Colors.red;
        break;
      case 'professional':
        color = Colors.blue;
        break;
      default:
        color = Colors.green;
    }
    
    return Chip(
      label: Text(
        role.toUpperCase(),
        style: TextStyle(color: Colors.white, fontSize: 10),
      ),
      backgroundColor: color,
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    // CORRECCIÓN: Usar currentUser en lugar de getUsuarioActual()
    final currentUser = authService.currentUser;
    
    // Filtrar usuarios según búsqueda
    final filteredUsuarios = _searchController.text.isEmpty
        ? _usuarios
        : _usuarios.where((user) =>
            user.username.toLowerCase().contains(_searchController.text.toLowerCase()) ||
            (user.email?.toLowerCase().contains(_searchController.text.toLowerCase()) ?? false))
          .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Gestión de Usuarios'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (currentUser?.isAdmin ?? false)
            IconButton(
              icon: Icon(Icons.add),
              onPressed: _crearUsuarioAdmin,
              tooltip: 'Crear usuario admin',
            ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadUsuarios,
            tooltip: 'Actualizar lista',
          ),
        ],
      ),
      body: Column(
        children: [
          // Barra de búsqueda
          Padding(
            padding: EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Buscar usuarios',
                hintText: 'Por nombre o email',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {});
                  },
                ),
              ),
              onChanged: (value) => setState(() {}),
            ),
          ),

          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : filteredUsuarios.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.people_outline, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text(
                              'No hay usuarios registrados',
                              style: TextStyle(fontSize: 16, color: Colors.grey),
                            ),
                            SizedBox(height: 16),
                            if (currentUser?.isAdmin ?? false)
                              ElevatedButton(
                                onPressed: _crearUsuarioAdmin,
                                child: Text('Crear Usuario Admin'),
                              ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: filteredUsuarios.length,
                        itemBuilder: (context, index) {
                          final usuario = filteredUsuarios[index];
                          final isCurrentUser = usuario.id == currentUser?.id;
                          
                          return Card(
                            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: usuario.isAdmin ? Colors.red : Colors.blue,
                                child: Icon(
                                  usuario.isAdmin ? Icons.admin_panel_settings : Icons.person,
                                  color: Colors.white,
                                ),
                              ),
                              title: Text(usuario.username),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (usuario.email != null) Text(usuario.email!),
                                  SizedBox(height: 4),
                                  _buildRoleChip(usuario.role),
                                  if (usuario.isProfessional)
                                    Chip(
                                      label: Text('PROFESIONAL'),
                                      backgroundColor: Colors.blue[100],
                                    ),
                                ],
                              ),
                              trailing: !isCurrentUser && (currentUser?.isAdmin ?? false)
                                  ? PopupMenuButton<String>(
                                      onSelected: (value) => _cambiarRol(usuario, value),
                                      itemBuilder: (context) => [
                                        PopupMenuItem(
                                          value: 'user',
                                          child: Text('Cambiar a Usuario'),
                                        ),
                                        PopupMenuItem(
                                          value: 'professional',
                                          child: Text('Cambiar a Profesional'),
                                        ),
                                        if (currentUser?.isAdmin ?? false)
                                          PopupMenuItem(
                                            value: 'admin',
                                            child: Text('Cambiar a Administrador'),
                                          ),
                                      ],
                                    )
                                  : isCurrentUser
                                      ? Chip(
                                          label: Text('TÚ', style: TextStyle(color: Colors.white)),
                                          backgroundColor: Colors.blue,
                                        )
                                      : null,
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}