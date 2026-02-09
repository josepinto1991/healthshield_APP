import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../services/vacuna_service.dart';
import '../services/paciente_service.dart';
import '../models/vacuna.dart';
import '../models/paciente.dart';
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
  bool _exporting = false;

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
    setState(() {
      _exporting = true;
    });

    try {
      // Mostrar opciones de exportación
      final exportOption = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Exportar Datos'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.medical_services, color: Colors.blue),
                title: Text('Vacunas'),
                subtitle: Text('Exportar todos los registros de vacunación'),
                onTap: () => Navigator.pop(context, 'vacunas'),
              ),
              ListTile(
                leading: Icon(Icons.people, color: Colors.green),
                title: Text('Pacientes'),
                subtitle: Text('Exportar lista de pacientes'),
                onTap: () => Navigator.pop(context, 'pacientes'),
              ),
              ListTile(
                leading: Icon(Icons.person, color: Colors.orange),
                title: Text('Usuarios'),
                subtitle: Text('Exportar lista de usuarios'),
                onTap: () => Navigator.pop(context, 'usuarios'),
              ),
              ListTile(
                leading: Icon(Icons.all_inclusive, color: Colors.purple),
                title: Text('Todos los datos'),
                subtitle: Text('Exportar todos los datos del sistema'),
                onTap: () => Navigator.pop(context, 'todos'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancelar'),
            ),
          ],
        ),
      );

      if (exportOption == null) {
        setState(() { _exporting = false; });
        return;
      }

      // Obtener el directorio de descargas
      final directory = await getDownloadsDirectory();
      if (directory == null) {
        throw Exception('No se pudo acceder al directorio de descargas');
      }

      String filePath = '';
      String fileName = '';

      switch (exportOption) {
        case 'vacunas':
          filePath = await _exportarVacunasCSV(directory.path);
          fileName = 'vacunas.csv';
          break;
        case 'pacientes':
          filePath = await _exportarPacientesCSV(directory.path);
          fileName = 'pacientes.csv';
          break;
        case 'usuarios':
          filePath = await _exportarUsuariosCSV(directory.path);
          fileName = 'usuarios.csv';
          break;
        case 'todos':
          filePath = await _exportarTodosCSV(directory.path);
          fileName = 'healthshield_datos_completos.zip';
          break;
      }

      if (filePath.isNotEmpty) {
        await _mostrarExitoExportacion(filePath, fileName);
      }

    } catch (e) {
      print('Error exportando datos: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    } finally {
      setState(() {
        _exporting = false;
      });
    }
  }

  Future<String> _exportarVacunasCSV(String directoryPath) async {
    final vacunaService = Provider.of<VacunaService>(context, listen: false);
    final vacunas = await vacunaService.getVacunas();
    
    if (vacunas.isEmpty) {
      throw Exception('No hay vacunas para exportar');
    }

    final csvBuffer = StringBuffer();
    
    // Encabezados
    csvBuffer.writeln('ID,Nombre Paciente,Cédula Paciente,Tipo de Vacuna,Fecha Aplicación,Lote,Próxima Dosis,Es Menor,Cédula Tutor,Cédula Propia,Creado En,Sincronizado');
    
    // Datos
    for (final vacuna in vacunas) {
      final line = [
        vacuna.id?.toString() ?? '',
        _escapeCsv(vacuna.nombrePaciente ?? ''),
        _escapeCsv(vacuna.cedulaPaciente ?? ''),
        _escapeCsv(vacuna.nombreVacuna),
        _escapeCsv(vacuna.fechaAplicacion),
        _escapeCsv(vacuna.lote ?? ''),
        _escapeCsv(vacuna.proximaDosis ?? ''),
        vacuna.esMenor ? 'Sí' : 'No',
        _escapeCsv(vacuna.cedulaTutor ?? ''),
        _escapeCsv(vacuna.cedulaPropia ?? ''),
        vacuna.createdAt?.toIso8601String() ?? '',
        vacuna.isSynced ? 'Sí' : 'No',
      ].join(',');
      
      csvBuffer.writeln(line);
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'vacunas_$timestamp.csv';
    final filePath = '$directoryPath/$fileName';
    
    final file = File(filePath);
    await file.writeAsString(csvBuffer.toString(), flush: true);
    
    return filePath;
  }

  Future<String> _exportarPacientesCSV(String directoryPath) async {
    final pacienteService = Provider.of<PacienteService>(context, listen: false);
    final pacientes = await pacienteService.getPacientes();
    
    if (pacientes.isEmpty) {
      throw Exception('No hay pacientes para exportar');
    }

    final csvBuffer = StringBuffer();
    
    // Encabezados
    csvBuffer.writeln('ID,Cédula,Nombre,Fecha Nacimiento,Teléfono,Dirección,Creado En,Sincronizado');
    
    // Datos
    for (final paciente in pacientes) {
      final line = [
        paciente.id?.toString() ?? '',
        _escapeCsv(paciente.cedula),
        _escapeCsv(paciente.nombre),
        _escapeCsv(paciente.fechaNacimiento),
        _escapeCsv(paciente.telefono ?? ''),
        _escapeCsv(paciente.direccion ?? ''),
        paciente.createdAt?.toIso8601String() ?? '',
        paciente.isSynced ? 'Sí' : 'No',
      ].join(',');
      
      csvBuffer.writeln(line);
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'pacientes_$timestamp.csv';
    final filePath = '$directoryPath/$fileName';
    
    final file = File(filePath);
    await file.writeAsString(csvBuffer.toString(), flush: true);
    
    return filePath;
  }

  Future<String> _exportarUsuariosCSV(String directoryPath) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final usuarios = await authService.getUsuarios();
    
    if (usuarios.isEmpty) {
      throw Exception('No hay usuarios para exportar');
    }

    final csvBuffer = StringBuffer();
    
    // Encabezados
    csvBuffer.writeln('ID,Usuario,Email,Teléfono,Rol,Profesional,Matrícula,Verificado,Creado En,Sincronizado');
    
    // Datos
    for (final usuario in usuarios) {
      final line = [
        usuario.id?.toString() ?? '',
        _escapeCsv(usuario.username),
        _escapeCsv(usuario.email),
        _escapeCsv(usuario.telefono ?? ''),
        _escapeCsv(usuario.role),
        usuario.isProfessional ? 'Sí' : 'No',
        _escapeCsv(usuario.professionalLicense ?? ''),
        usuario.isVerified ? 'Sí' : 'No',
        usuario.createdAt.toIso8601String(),
        usuario.isSynced ? 'Sí' : 'No',
      ].join(',');
      
      csvBuffer.writeln(line);
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'usuarios_$timestamp.csv';
    final filePath = '$directoryPath/$fileName';
    
    final file = File(filePath);
    await file.writeAsString(csvBuffer.toString(), flush: true);
    
    return filePath;
  }

  Future<String> _exportarTodosCSV(String directoryPath) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final folderName = 'HealthShield_Export_$timestamp';
    final exportDir = Directory('$directoryPath/$folderName');
    
    if (!await exportDir.exists()) {
      await exportDir.create(recursive: true);
    }
    
    // Exportar todos los tipos de datos
    await _exportarVacunasCSV(exportDir.path);
    await _exportarPacientesCSV(exportDir.path);
    await _exportarUsuariosCSV(exportDir.path);
    
    // Crear archivo README
    final readmeContent = '''
HealthShield - Exportación Completa
Fecha: ${DateTime.now().toLocal()}

Archivos incluidos:
1. vacunas_$timestamp.csv - Todos los registros de vacunación
2. pacientes_$timestamp.csv - Lista de pacientes
3. usuarios_$timestamp.csv - Usuarios del sistema

Total registros exportados:
- Vacunas: $_totalVacunas
- Pacientes: $_totalPacientes
- Usuarios: $_totalUsuarios

Este archivo fue generado automáticamente por HealthShield.
    ''';
    
    final readmeFile = File('${exportDir.path}/README.txt');
    await readmeFile.writeAsString(readmeContent, flush: true);
    
    return exportDir.path;
  }

  Future<void> _mostrarExitoExportacion(String filePath, String fileName) async {
    final file = File(filePath);
    final fileSize = await file.length();
    final sizeInKB = (fileSize / 1024).toStringAsFixed(2);
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('✅ Exportación Exitosa'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Archivo exportado correctamente:'),
            SizedBox(height: 8),
            Text('📁 $fileName', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 4),
            Text('📍 ${file.parent.path}'),
            SizedBox(height: 4),
            Text('📏 Tamaño: ${sizeInKB} KB'),
            SizedBox(height: 16),
            Text(
              'Los archivos se guardaron en la carpeta de descargas.',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cerrar'),
          ),
        ],
      ),
    );
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ Datos exportados exitosamente'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  String _escapeCsv(String field) {
    if (field.contains(',') || field.contains('"') || field.contains('\n')) {
      return '"${field.replaceAll('"', '""')}"';
    }
    return field;
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
    bool disabled = false,
  }) {
    return Card(
      elevation: 2,
      color: disabled ? Colors.grey[100] : null,
      child: ListTile(
        leading: Icon(icon, color: disabled ? Colors.grey : color),
        title: Text(title, style: TextStyle(
          fontWeight: FontWeight.bold,
          color: disabled ? Colors.grey : null,
        )),
        subtitle: Text(subtitle, style: TextStyle(
          color: disabled ? Colors.grey : null,
        )),
        trailing: disabled ? null : Icon(Icons.arrow_forward_ios, size: 16),
        onTap: disabled ? null : onTap,
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
            icon: Icon(Icons.person_add),
            onPressed: () {
              Navigator.pushNamed(context, '/professional-register');
            },
            tooltip: 'Crear Nuevo Usuario',
          ),
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
                          IconButton(
                            icon: Icon(Icons.settings, color: Colors.blue),
                            onPressed: () {
                              Navigator.pushNamed(context, '/change-password');
                            },
                            tooltip: 'Configuración',
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
                    subtitle: 'Ver, editar y eliminar usuarios del sistema',
                    icon: Icons.manage_accounts,
                    color: Colors.purple,
                    onTap: () {
                      Navigator.pushNamed(context, '/admin-usuarios');
                    },
                  ),

                  _buildActionButton(
                    title: 'Crear Nuevo Usuario',
                    subtitle: 'Registrar nuevo profesional o administrador',
                    icon: Icons.person_add,
                    color: Colors.blue,
                    onTap: () {
                      Navigator.pushNamed(context, '/professional-register');
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
                    subtitle: 'Exportar datos a CSV (se guarda en Descargas)',
                    icon: _exporting ? Icons.downloading : Icons.download,
                    color: Colors.teal,
                    onTap: _exporting ? () {} : () => _exportarDatos(),
                    disabled: _exporting,
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
                            leading: Icon(Icons.folder, size: 20),
                            title: Text('Descargas de Exportación'),
                            subtitle: Text('Los archivos CSV se guardan automáticamente en la carpeta de Descargas.'),
                          ),
                          if (_exporting)
                            ListTile(
                              leading: Icon(Icons.downloading, size: 20, color: Colors.blue),
                              title: Text('Exportando datos...'),
                              subtitle: Text('Por favor espera'),
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