
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/vacuna_service.dart';
import '../services/paciente_service.dart';

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
    final currentUser = authService.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Panel de Administración',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadStatistics,
            tooltip: 'Actualizar estadísticas',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Información del administrador
                  Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: Colors.red,
                            child: Icon(Icons.admin_panel_settings, color: Colors.white),
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
                                    'ADMINISTRADOR',
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
                    'Estadísticas del Sistema',
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
                      _buildStatCard('Vacunas Registradas', _totalVacunas, Icons.medical_services, Colors.blue),
                      _buildStatCard('Pacientes', _totalPacientes, Icons.people, Colors.green),
                      _buildStatCard('Usuarios', _totalUsuarios, Icons.person, Colors.orange),
                      _buildStatCard('Pendientes Sync', _pendientesSincronizacion, Icons.sync, Colors.red),
                    ],
                  ),

                  SizedBox(height: 32),

                  // Acciones administrativas
                  Text(
                    'Acciones de Administración',
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
                    title: 'Sincronización',
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
                  
                  SizedBox(height: 24),
                  
                  // Botón para volver al menú principal
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      icon: Icon(Icons.arrow_back),
                      label: Text('Volver al Menú Principal'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}