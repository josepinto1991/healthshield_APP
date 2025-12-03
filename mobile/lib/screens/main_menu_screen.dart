import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_service.dart';
import '../models/usuario.dart'; // AGREGAR ESTA LÍNEA
import 'registro_vacuna_screen.dart';
import 'visualizar_registros_screen.dart';
import 'sync_screen.dart';
import 'change_password_screen.dart';
import 'dashboard_screen.dart';

class MainMenuScreen extends StatelessWidget {
  Future<void> _logout(BuildContext context) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    await authService.logout();
    Navigator.pushNamedAndRemoveUntil(context, '/welcome', (route) => false);
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
    return FutureBuilder<Usuario?>(
      future: Provider.of<AuthService>(context, listen: false).getUsuarioActual(),
      builder: (context, snapshot) {
        final usuario = snapshot.data;
        final isAdmin = usuario?.username == 'admin';
        
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
              // Botón de dashboard solo para admin
              if (isAdmin)
                IconButton(
                  icon: Icon(Icons.dashboard),
                  onPressed: () {
                    Navigator.pushNamed(context, '/dashboard');
                  },
                  tooltip: 'Dashboard Admin',
                ),
              // Botón de sincronización
              IconButton(
                icon: Icon(Icons.sync),
                onPressed: () {
                  Navigator.pushNamed(context, '/sync');
                },
                tooltip: 'Sincronizar datos',
              ),
              // Botón de cambio de contraseña
              IconButton(
                icon: Icon(Icons.lock),
                onPressed: () {
                  Navigator.pushNamed(context, '/change-password');
                },
                tooltip: 'Cambiar contraseña',
              ),
              // Botón de logout
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
                if (usuario != null)
                  Card(
                    child: Padding(
                      padding: EdgeInsets.all(12.0),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: usuario.isProfessional ? Colors.blue : Colors.grey,
                            child: Icon(
                              usuario.isProfessional ? Icons.verified_user : Icons.person,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Hola, ${usuario.username}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  usuario.isProfessional ? 'Profesional de Salud' : 'Usuario',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 14,
                                  ),
                                ),
                                if (isAdmin)
                                  Chip(
                                    label: Text(
                                      'ADMINISTRADOR',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    backgroundColor: Colors.red,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                
                SizedBox(height: 16),
                
                // Botones principales
                Row(
                  children: [
                    Expanded(
                      child: _buildMenuButton(
                        icon: Icons.add_circle,
                        title: 'Realizar Registro',
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
                        title: 'Visualizar Registro',
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
                
                SizedBox(height: 32),
                
                // Información General
                Text(
                  'Información General',
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
                
                // Botones de acción rápida
                Row(
                  children: [
                    Expanded(
                      child: _buildQuickActionButton(
                        icon: Icons.person,
                        title: 'Mi Perfil',
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Vista de perfil - Próximamente')),
                          );
                        },
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: _buildQuickActionButton(
                        icon: Icons.settings,
                        title: 'Configuración',
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Configuración - Próximamente')),
                          );
                        },
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: _buildQuickActionButton(
                        icon: Icons.help,
                        title: 'Ayuda',
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Centro de ayuda - Próximamente')),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                
                SizedBox(height: 16),
                
                // Botón proceder
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pushNamed(context, '/registro-vacuna');
                    },
                    icon: Icon(Icons.arrow_forward),
                    label: Text('Proceder a Registro de Vacunas'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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

  Widget _buildQuickActionButton({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 24, color: Colors.blue),
              SizedBox(height: 4),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
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
        subtitle: Text(subtitle),
        trailing: Icon(Icons.open_in_new, size: 16),
        onTap: onTap,
      ),
    );
  }
}