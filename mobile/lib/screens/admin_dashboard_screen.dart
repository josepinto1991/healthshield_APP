import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/vacuna_service.dart';
import '../services/paciente_service.dart';
import '../services/sync_service.dart';
import '../models/usuario.dart';

class AdminDashboardScreen extends StatefulWidget {
  @override
  _AdminDashboardScreenState createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _totalVacunas = 0;
  int _totalPacientes = 0;
  int _totalUsuarios = 0;
  int _pendientesSincronizacion = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final vacunaService = Provider.of<VacunaService>(context, listen: false);
      final authService = Provider.of<AuthService>(context, listen: false);
      
      final vacunas = await vacunaService.getVacunas();
      _totalVacunas = vacunas.length;

      final usuarios = await authService.getUsuarios();
      _totalUsuarios = usuarios.length;

      final unsyncedVacunas = await vacunaService.getUnsyncedVacunas();
      _pendientesSincronizacion = unsyncedVacunas.length;

      try {
        final pacienteService = Provider.of<PacienteService>(context, listen: false);
        final pacientes = await pacienteService.getPacientes();
        _totalPacientes = pacientes.length;
      } catch (e) {
        print('Servicio de pacientes no disponible: $e');
      }

    } catch (e) {
      print('Error cargando estadísticas: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _sincronizarTodo() async {
    final syncService = Provider.of<SyncService>(context, listen: false);
    final result = await syncService.fullSync();
    
    if (result['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Sincronización completada'),
          backgroundColor: Colors.green,
        ),
      );
      await _loadStatistics();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error: ${result['message']}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _exportarDatos() async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Exportación de datos - Próximamente')),
    );
  }

  Future<void> _abrirLogs() async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Visualización de logs - Próximamente')),
    );
  }

  Widget _buildStatCard(String title, int count, IconData icon, Color color) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: color),
            SizedBox(height: 8),
            Text(
              '$count',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    // CORRECCIÓN: Usar currentUser en lugar de getUsuarioActual()
    final currentUser = authService.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'HealthShield Admin',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.sync),
            onPressed: _sincronizarTodo,
            tooltip: 'Sincronizar todo',
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadStatistics,
            tooltip: 'Actualizar estadísticas',
          ),
        ],
      ),
      drawer: _buildDrawer(context, authService, currentUser),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Información del usuario
                  Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: Colors.blue,
                            child: Icon(Icons.person, color: Colors.white),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  currentUser?.username ?? 'Administrador',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                SizedBox(height: 4),
                                Chip(
                                  label: Text(
                                    'ADMIN',
                                    style: TextStyle(color: Colors.white, fontSize: 10),
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                                if (currentUser?.email != null)
                                  Text(
                                    currentUser!.email!,
                                    style: TextStyle(color: Colors.grey),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: 24),

                  // Estadísticas
                  Text(
                    'Estadísticas',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 16),

                  GridView.count(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    childAspectRatio: 1.0,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    children: [
                      _buildStatCard('Vacunas', _totalVacunas, Icons.medical_services, Colors.blue),
                      _buildStatCard('Pacientes', _totalPacientes, Icons.people, Colors.green),
                      _buildStatCard('Usuarios', _totalUsuarios, Icons.person, Colors.orange),
                      _buildStatCard('Pendientes Sync', _pendientesSincronizacion, Icons.sync, Colors.red),
                    ],
                  ),

                  SizedBox(height: 32),

                  // Acciones administrativas
                  Text(
                    'Acciones',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 16),

                  _buildActionButton(
                    title: 'Gestionar Usuarios',
                    subtitle: 'Crear, editar y eliminar usuarios del sistema',
                    icon: Icons.manage_accounts,
                    color: Colors.purple,
                    onTap: () {
                      Navigator.pushNamed(context, '/admin-usuarios');
                    },
                  ),

                  _buildActionButton(
                    title: 'Ver Todos los Registros',
                    subtitle: 'Ver todas las vacunas registradas en el sistema',
                    icon: Icons.list_alt,
                    color: Colors.blue,
                    onTap: () {
                      Navigator.pushNamed(context, '/visualizar-registros');
                    },
                  ),

                  _buildActionButton(
                    title: 'Registrar Nueva Vacuna',
                    subtitle: 'Agregar un nuevo registro de vacunación',
                    icon: Icons.add_circle,
                    color: Colors.green,
                    onTap: () {
                      Navigator.pushNamed(context, '/registro-vacuna');
                    },
                  ),

                  _buildActionButton(
                    title: 'Sincronización Avanzada',
                    subtitle: 'Configurar y monitorear sincronización',
                    icon: Icons.sync_disabled,
                    color: Colors.orange,
                    onTap: () {
                      Navigator.pushNamed(context, '/sync');
                    },
                  ),

                  _buildActionButton(
                    title: 'Exportar Datos',
                    subtitle: 'Exportar datos a Excel o CSV',
                    icon: Icons.download,
                    color: Colors.teal,
                    onTap: _exportarDatos,
                  ),

                  _buildActionButton(
                    title: 'Ver Logs del Sistema',
                    subtitle: 'Monitorear actividad y errores',
                    icon: Icons.history,
                    color: Colors.brown,
                    onTap: _abrirLogs,
                  ),

                  SizedBox(height: 24),

                  // Información del sistema
                  Card(
                    color: Colors.grey[50],
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Información del Sistema',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 8),
                          ListTile(
                            leading: Icon(Icons.storage, size: 20),
                            title: Text('Base de Datos Local'),
                            subtitle: Text('SQLite - ${_totalVacunas + _totalPacientes + _totalUsuarios} registros'),
                          ),
                          ListTile(
                            leading: Icon(Icons.cloud, size: 20),
                            title: Text('Estado de Sincronización'),
                            subtitle: Text(
                              _pendientesSincronizacion > 0
                                  ? '$_pendientesSincronizacion pendientes'
                                  : 'Sincronizado',
                              style: TextStyle(
                                color: _pendientesSincronizacion > 0 ? Colors.orange : Colors.green,
                              ),
                            ),
                          ),
                          ListTile(
                            leading: Icon(Icons.security, size: 20),
                            title: Text('Modo Administrador'),
                            subtitle: Text('Acceso completo al sistema'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildDrawer(BuildContext context, AuthService authService, Usuario? currentUser) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Colors.blue,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.admin_panel_settings, size: 48, color: Colors.white),
                SizedBox(height: 16),
                Text(
                  'Panel Administrativo',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
                SizedBox(height: 4),
                Text(
                  'HealthShield v1.0',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
          
          ListTile(
            leading: Icon(Icons.dashboard),
            title: Text('Dashboard'),
            selected: true,
            onTap: () {
              Navigator.pop(context);
            },
          ),
          
          ListTile(
            leading: Icon(Icons.people),
            title: Text('Gestión de Usuarios'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/admin-usuarios');
            },
          ),
          
          Divider(),
          
          Text(
            'Módulos de Usuario',
            style: TextStyle(fontSize: 12, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          
          ListTile(
            leading: Icon(Icons.medical_services),
            title: Text('Registrar Vacuna'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/registro-vacuna');
            },
          ),
          
          ListTile(
            leading: Icon(Icons.visibility),
            title: Text('Ver Registros'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/visualizar-registros');
            },
          ),
          
          ListTile(
            leading: Icon(Icons.sync),
            title: Text('Sincronización'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/sync');
            },
          ),
          
          Divider(),
          
          ListTile(
            leading: Icon(Icons.settings),
            title: Text('Configuración'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/change-password');
            },
          ),
          
          ListTile(
            leading: Icon(Icons.help),
            title: Text('Ayuda'),
            onTap: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Centro de ayuda - Próximamente')),
              );
            },
          ),
          
          Divider(),
          
          ListTile(
            leading: Icon(Icons.logout, color: Colors.red),
            title: Text('Cerrar Sesión', style: TextStyle(color: Colors.red)),
            onTap: () async {
              await authService.logout();
              Navigator.pushNamedAndRemoveUntil(
                context, 
                '/welcome', 
                (route) => false
              );
            },
          ),
        ],
      ),
    );
  }
}