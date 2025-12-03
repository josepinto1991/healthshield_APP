import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/vacuna_service.dart';
import '../models/usuario.dart';
import '../models/vacuna.dart';

class DashboardScreen extends StatefulWidget {
  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<Usuario> _usuarios = [];
  List<Vacuna> _vacunas = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final vacunaService = Provider.of<VacunaService>(context, listen: false);
      
      // Obtener usuarios y vacunas
      _usuarios = await authService.getUsuarios();
      _vacunas = await vacunaService.getVacunas();
    } catch (e) {
      print('Error cargando datos del dashboard: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _logout(BuildContext context) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    await authService.logout();
    Navigator.pushNamedAndRemoveUntil(context, '/welcome', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'HealthShield - Dashboard Admin',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadDashboardData,
            tooltip: 'Actualizar datos',
          ),
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () => _logout(context),
            tooltip: 'Cerrar sesión',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Estadísticas generales
                  Text(
                    'Dashboard Administrativo',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  
                  SizedBox(height: 16),
                  
                  // Tarjetas de estadísticas
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Total Usuarios',
                          _usuarios.length.toString(),
                          Icons.people,
                          Colors.blue,
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: _buildStatCard(
                          'Total Vacunas',
                          _vacunas.length.toString(),
                          Icons.medical_services,
                          Colors.green,
                        ),
                      ),
                    ],
                  ),
                  
                  SizedBox(height: 16),
                  
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Profesionales',
                          _usuarios.where((u) => u.isProfessional).length.toString(),
                          Icons.verified_user,
                          Colors.orange,
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: _buildStatCard(
                          'Usuarios Verificados',
                          _usuarios.where((u) => u.isVerified).length.toString(),
                          Icons.verified,
                          Colors.purple,
                        ),
                      ),
                    ],
                  ),
                  
                  SizedBox(height: 32),
                  
                  // Lista de usuarios
                  Text(
                    'Usuarios Registrados',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 16),
                  
                  if (_usuarios.isEmpty)
                    _buildEmptyState('No hay usuarios registrados')
                  else
                    ..._usuarios.map((usuario) => _buildUserCard(usuario)).toList(),
                  
                  SizedBox(height: 32),
                  
                  // Lista de vacunas recientes
                  Text(
                    'Registros de Vacunas Recientes',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 16),
                  
                  if (_vacunas.isEmpty)
                    _buildEmptyState('No hay registros de vacunas')
                  else
                    ..._vacunas.take(10).map((vacuna) => _buildVacunaCard(vacuna)).toList(),
                ],
              ),
            ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(icon, size: 40, color: color),
            SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
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

  Widget _buildUserCard(Usuario usuario) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: usuario.isProfessional ? Colors.blue : Colors.grey,
          child: Icon(
            usuario.isProfessional ? Icons.verified_user : Icons.person,
            color: Colors.white,
          ),
        ),
        title: Text(usuario.username),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(usuario.email),
            if (usuario.telefono != null) Text(usuario.telefono!),
            Row(
              children: [
                Chip(
                  label: Text(
                    usuario.isProfessional ? 'Profesional' : 'Usuario',
                    style: TextStyle(fontSize: 10, color: Colors.white),
                  ),
                  backgroundColor: usuario.isProfessional ? Colors.blue : Colors.grey,
                ),
                SizedBox(width: 4),
                Chip(
                  label: Text(
                    usuario.isVerified ? 'Verificado' : 'No verificado',
                    style: TextStyle(fontSize: 10, color: Colors.white),
                  ),
                  backgroundColor: usuario.isVerified ? Colors.green : Colors.orange,
                ),
              ],
            ),
          ],
        ),
        trailing: Text(
          'ID: ${usuario.id}',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ),
    );
  }

  Widget _buildVacunaCard(Vacuna vacuna) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Icon(
          vacuna.tipoPaciente == 'niño' ? Icons.child_care : Icons.person,
          color: Colors.blue,
        ),
        title: Text(vacuna.nombrePaciente),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Vacuna: ${vacuna.tipoVacuna}'),
            Text('Fecha: ${vacuna.fechaFormateada}'),
            if (vacuna.cedulaPaciente.isNotEmpty)
              Text('Cédula: ${vacuna.cedulaPaciente}'),
          ],
        ),
        trailing: Chip(
          label: Text(
            vacuna.tipoPaciente,
            style: TextStyle(color: Colors.white, fontSize: 10),
          ),
          backgroundColor: vacuna.tipoPaciente == 'niño' ? Colors.orange : Colors.green,
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      padding: EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(Icons.info_outline, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}