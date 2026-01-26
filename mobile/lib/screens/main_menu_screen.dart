import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_service.dart';

class MainMenuScreen extends StatelessWidget {
  Future<void> _logout(BuildContext context) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    await authService.logout();
    Navigator.pushNamedAndRemoveUntil(
      context, 
      '/welcome', 
      (route) => false
    );
  }

  Future<void> _launchURL(String url) async {
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      throw 'No se pudo abrir $url';
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final currentUser = authService.currentUser;
    final isAdmin = currentUser?.isAdmin ?? false;
    
    // 🔥 OBTENER PADDING INFERIOR SEGURO
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;
    
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
        actions: [
          if (isAdmin)
            IconButton(
              icon: Icon(Icons.admin_panel_settings, color: Colors.red),
              onPressed: () {
                Navigator.pushNamed(context, '/admin-dashboard');
              },
              tooltip: 'Panel Administrativo',
            ),
          IconButton(
            icon: Icon(Icons.sync),
            onPressed: () {
              Navigator.pushNamed(context, '/sync');
            },
            tooltip: 'Sincronizar datos',
          ),
          IconButton(
            icon: Icon(Icons.lock),
            onPressed: () {
              Navigator.pushNamed(context, '/change-password');
            },
            tooltip: 'Cambiar contraseña',
          ),
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () => _logout(context),
            tooltip: 'Cerrar sesión',
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Información del usuario
            if (currentUser != null)
              Card(
                elevation: 2,
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: isAdmin ? Colors.red : Colors.blue,
                        child: Icon(
                          isAdmin ? Icons.admin_panel_settings : Icons.person,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentUser.username,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            SizedBox(height: 4),
                            Row(
                              children: [
                                Chip(
                                  label: Text(
                                    isAdmin ? 'ADMIN' : 'USUARIO',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  backgroundColor: isAdmin ? Colors.red : Colors.blue,
                                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                ),
                                if (currentUser.isProfessional)
                                  Padding(
                                    padding: EdgeInsets.only(left: 8),
                                    child: Chip(
                                      label: Text(
                                        'PROFESIONAL',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      backgroundColor: Colors.green,
                                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Botón de admin si es administrador
                      if (isAdmin)
                        IconButton(
                          icon: Icon(Icons.admin_panel_settings, color: Colors.red),
                          onPressed: () {
                            Navigator.pushNamed(context, '/admin-dashboard');
                          },
                          tooltip: 'Ir al Panel de Administración',
                        ),
                    ],
                  ),
                ),
              ),
            
            SizedBox(height: isAdmin ? 16 : 24),
            
            // Botones principales
            Row(
              children: [
                Expanded(
                  child: _buildMenuButton(
                    icon: Icons.add_circle,
                    title: 'Registrar Vacuna',
                    color: Colors.blue,
                    onTap: () {
                      Navigator.pushNamed(context, '/registro-vacuna');
                    },
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: _buildMenuButton(
                    icon: Icons.visibility,
                    title: 'Ver Registros',
                    color: Colors.green,
                    onTap: () {
                      Navigator.pushNamed(context, '/visualizar-registros');
                    },
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: _buildMenuButton(
                    icon: Icons.sync,
                    title: 'Sincronizar',
                    color: Colors.orange,
                    onTap: () {
                      Navigator.pushNamed(context, '/sync');
                    },
                  ),
                ),
              ],
            ),
            
            // Botón de admin dashboard (solo para administradores)
            if (isAdmin)
              Column(
                children: [
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildMenuButton(
                          icon: Icons.admin_panel_settings,
                          title: 'Panel Administrativo',
                          color: Colors.red,
                          onTap: () {
                            Navigator.pushNamed(context, '/admin-dashboard');
                          },
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: _buildMenuButton(
                          icon: Icons.people,
                          title: 'Gestionar Usuarios',
                          color: Colors.purple,
                          onTap: () {
                            Navigator.pushNamed(context, '/admin-usuarios');
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            
            SizedBox(height: 32),
            
            // Información General
            Text(
              'Recursos de Información',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            
            SizedBox(height: 16),
            
            Expanded(
              child: ListView(
                children: [
                  _buildInfoCard(
                    title: 'OPS - Organización Panamericana de la Salud',
                    subtitle: 'Sitio oficial con información sobre vacunación en las Américas',
                    icon: Icons.health_and_safety,
                    color: Colors.blue,
                    onTap: () => _launchURL('https://www.paho.org/es/temas/inmunizacion'),
                  ),
                  
                  SizedBox(height: 12),
                  
                  _buildInfoCard(
                    title: 'OMS - Organización Mundial de la Salud',
                    subtitle: 'Información global sobre programas de vacunación',
                    icon: Icons.public,
                    color: Colors.green,
                    onTap: () => _launchURL('https://www.who.int/es/health-topics/vaccines-and-immunization'),
                  ),
                  
                  SizedBox(height: 12),
                  
                  _buildInfoCard(
                    title: 'CDC - Centros para el Control y Prevención de Enfermedades',
                    subtitle: 'Guías y calendarios de vacunación actualizados',
                    icon: Icons.medical_information,
                    color: Colors.red,
                    onTap: () => _launchURL('https://www.cdc.gov/vaccines/index.html'),
                  ),

                  SizedBox(height: 12),
                  
                  _buildInfoCard(
                    title: 'Ministerio de Salud Pública',
                    subtitle: 'Protocolos nacionales de vacunación',
                    icon: Icons.local_hospital,
                    color: Colors.purple,
                    onTap: () => _launchURL('https://www.salud.gob.ec/'),
                  ),

                  SizedBox(height: 12),
                  
                  _buildInfoCard(
                    title: 'UNICEF - Vacunación',
                    subtitle: 'Programas de inmunización para niños a nivel mundial',
                    icon: Icons.child_care,
                    color: Colors.cyan,
                    onTap: () => _launchURL('https://www.unicef.org/immunization'),
                  ),
                ],
              ),
            ),
            
            SizedBox(height: 16),
            
            // 🔥 MODIFICADO: Botón con padding seguro
            Container(
              margin: EdgeInsets.only(bottom: 16 + bottomPadding), // 🔥 MARGEN DINÁMICO
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(context, '/registro-vacuna');
                  },
                  icon: Icon(Icons.add, size: 20),
                  label: Text('Nuevo Registro de Vacuna'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuButton({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: color),
              SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      margin: EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: Icon(Icons.open_in_new, size: 16, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }
}