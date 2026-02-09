import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../models/usuario.dart';
import 'detalle_usuario_screen.dart';
import 'professional_register_screen.dart';

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

  Future<void> _crearNuevoUsuario() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ProfessionalRegisterScreen()),
    );
    
    if (result == true) {
      await _loadUsuarios();
    }
  }

  Future<void> _cambiarRol(Usuario usuario, String nuevoRol) async {
    final usuarioActualizado = usuario.copyWith(role: nuevoRol);
    final authService = Provider.of<AuthService>(context, listen: false);
    
    final success = await authService.actualizarUsuario(usuarioActualizado);
    
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Rol actualizado a ${nuevoRol.toUpperCase()}'),
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
    IconData icon;
    
    switch (role) {
      case 'admin':
        color = Colors.red;
        icon = Icons.admin_panel_settings;
        break;
      case 'professional':
        color = Colors.blue;
        icon = Icons.medical_services;
        break;
      default:
        color = Colors.green;
        icon = Icons.person;
    }
    
    return Chip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          SizedBox(width: 4),
          Text(
            role.toUpperCase(),
            style: TextStyle(color: Colors.white, fontSize: 10),
          ),
        ],
      ),
      backgroundColor: color,
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final currentUser = authService.currentUser;
    
    // Filtrar usuarios según búsqueda
    final filteredUsuarios = _searchController.text.isEmpty
        ? _usuarios
        : _usuarios.where((user) =>
            user.username.toLowerCase().contains(_searchController.text.toLowerCase()) ||
            (user.email?.toLowerCase().contains(_searchController.text.toLowerCase()) ?? false) ||
            (user.telefono?.toLowerCase().contains(_searchController.text.toLowerCase()) ?? false))
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
              icon: Icon(Icons.person_add),
              onPressed: _crearNuevoUsuario,
              tooltip: 'Crear nuevo usuario',
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
                hintText: 'Por nombre, email o teléfono',
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

          // Estadísticas rápidas
          if (filteredUsuarios.isNotEmpty)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatChip(
                    filteredUsuarios.where((u) => u.isAdmin).length,
                    'Admin',
                    Colors.red,
                  ),
                  _buildStatChip(
                    filteredUsuarios.where((u) => u.isProfessionalUser).length,
                    'Profesionales',
                    Colors.blue,
                  ),
                  _buildStatChip(
                    filteredUsuarios.length,
                    'Total',
                    Colors.green,
                  ),
                ],
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
                              ElevatedButton.icon(
                                onPressed: _crearNuevoUsuario,
                                icon: Icon(Icons.person_add),
                                label: Text('Crear Primer Usuario'),
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
                                backgroundColor: usuario.colorRol,
                                child: Icon(
                                  usuario.iconRol,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                usuario.username,
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (usuario.email != null) 
                                    Text(usuario.email!, style: TextStyle(fontSize: 12)),
                                  SizedBox(height: 4),
                                  _buildRoleChip(usuario.role),
                                  if (usuario.isProfessional)
                                    Chip(
                                      label: Text('PROFESIONAL'),
                                      backgroundColor: Colors.blue[100],
                                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                                    ),
                                ],
                              ),
                              trailing: isCurrentUser
                                  ? Chip(
                                      label: Text('TÚ', style: TextStyle(color: Colors.white)),
                                      backgroundColor: Colors.blue,
                                    )
                                  : Icon(Icons.arrow_forward_ios, size: 14),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => DetalleUsuarioScreen(usuario: usuario),
                                  ),
                                ).then((value) {
                                  if (value == true) {
                                    _loadUsuarios();
                                  }
                                });
                              },
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(int count, String label, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$count',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}