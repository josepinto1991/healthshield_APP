
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
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

  // 🔧 MÉTODO ROBUSTO PARA OBTENER LA RUTA DE DOCUMENTS
  Future<Directory> _getDocumentsDirectory() async {
    try {
      print('🔍 Buscando directorio Documents...');
      
      // Intentar diferentes métodos según la plataforma
      
      // Método 1: Usar getExternalStorageDirectory (Android)
      if (Platform.isAndroid) {
        try {
          // En Android, intentar obtener la ruta del almacenamiento externo
          final externalDir = await getExternalStorageDirectory();
          if (externalDir != null) {
            print('📁 Directorio externo encontrado: ${externalDir.path}');
            
            // Intentar encontrar o crear la carpeta Documents
            // Primero, subir hasta la raíz del almacenamiento
            String storageRoot = externalDir.path;
            
            // Si estamos en la carpeta de la app, subir niveles
            if (storageRoot.contains('/Android/data/')) {
              final parts = storageRoot.split('/');
              final androidIndex = parts.indexOf('Android');
              if (androidIndex > 0) {
                storageRoot = parts.sublist(0, androidIndex).join('/');
                print('📁 Raíz de almacenamiento: $storageRoot');
              }
            }
            
            // Crear o usar la carpeta Documents
            final documentsDir = Directory('$storageRoot/Documents');
            if (!await documentsDir.exists()) {
              await documentsDir.create(recursive: true);
              print('✅ Carpeta Documents creada: ${documentsDir.path}');
            }
            
            return documentsDir;
          }
        } catch (e) {
          print('⚠️ Error con getExternalStorageDirectory: $e');
        }
      }
      
      // Método 2: Usar getApplicationDocumentsDirectory (funciona en ambos)
      final appDocsDir = await getApplicationDocumentsDirectory();
      print('📁 Directorio de documentos de la app: ${appDocsDir.path}');
      
      // Para iOS, este es el Documents de la app
      // Para Android, podría estar en almacenamiento interno privado
      return appDocsDir;
      
    } catch (e) {
      print('❌ Error crítico obteniendo directorio: $e');
      
      // Último recurso: intentar crear en una ubicación temporal
      final tempDir = Directory('/storage/emulated/0/Documents');
      if (!await tempDir.exists()) {
        await tempDir.create(recursive: true);
      }
      return tempDir;
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

      // 🔧 OBTENER DIRECTORIO DOCUMENTS
      Directory baseDir = await _getDocumentsDirectory();
      
      // Crear subcarpeta HealthShield dentro de Documents
      Directory appDir = Directory('${baseDir.path}/HealthShield');
      
      // Si no existe la carpeta, crearla
      if (!await appDir.exists()) {
        await appDir.create(recursive: true);
        print('✅ Carpeta HealthShield creada: ${appDir.path}');
      } else {
        print('📁 Carpeta HealthShield ya existe: ${appDir.path}');
      }
      
      // Crear archivo .nomedia para evitar indexación
      final nomediaFile = File('${appDir.path}/.nomedia');
      if (!await nomediaFile.exists()) {
        await nomediaFile.writeAsString('', flush: true);
        print('✅ Archivo .nomedia creado');
      }
      
      // 🔧 DIAGNÓSTICO
      print('=' * 50);
      print('📊 INFORMACIÓN DE ALMACENAMIENTO:');
      print('📁 Ruta base: ${baseDir.path}');
      print('📁 Carpeta app: ${appDir.path}');
      print('📁 Existe: ${await appDir.exists()}');
      print('=' * 50);

      String filePath = '';
      String fileName = '';

      switch (exportOption) {
        case 'vacunas':
          filePath = await _exportarVacunasCSV(appDir.path);
          fileName = 'vacunas.csv';
          break;
        case 'pacientes':
          filePath = await _exportarPacientesCSV(appDir.path);
          fileName = 'pacientes.csv';
          break;
        case 'usuarios':
          filePath = await _exportarUsuariosCSV(appDir.path);
          fileName = 'usuarios.csv';
          break;
        case 'todos':
          filePath = await _exportarTodosCSV(appDir.path);
          fileName = 'healthshield_datos_completos';
          break;
      }

      if (filePath.isNotEmpty) {
        await _mostrarExitoExportacion(filePath, fileName, appDir.path);
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
    
    // Encabezados con codificación UTF-8 para caracteres especiales
    csvBuffer.writeln('\uFEFFID,Nombre Paciente,Cédula Paciente,Tipo de Vacuna,Fecha Aplicación,Lote,Próxima Dosis,Es Menor,Cédula Tutor,Cédula Propia,Creado En,Sincronizado');
    
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

    final dateStr = DateTime.now().toLocal().toString().split(' ')[0].replaceAll('-', '');
    final fileName = 'vacunas_$dateStr.csv';
    final filePath = '$directoryPath/$fileName';
    
    final file = File(filePath);
    
    // Guardar con codificación UTF-8 explícita
    final bytes = utf8.encode(csvBuffer.toString());
    await file.writeAsBytes(bytes, flush: true);
    
    print('✅ CSV guardado: $filePath (${bytes.length} bytes)');
    
    return filePath;
  }

  Future<String> _exportarPacientesCSV(String directoryPath) async {
    final pacienteService = Provider.of<PacienteService>(context, listen: false);
    final pacientes = await pacienteService.getPacientes();
    
    if (pacientes.isEmpty) {
      throw Exception('No hay pacientes para exportar');
    }

    final csvBuffer = StringBuffer();
    
    // Encabezados con BOM para Excel
    csvBuffer.writeln('\uFEFFID,Cédula,Nombre,Fecha Nacimiento,Teléfono,Dirección,Creado En,Sincronizado');
    
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

    final dateStr = DateTime.now().toLocal().toString().split(' ')[0].replaceAll('-', '');
    final fileName = 'pacientes_$dateStr.csv';
    final filePath = '$directoryPath/$fileName';
    
    final file = File(filePath);
    
    // Guardar con codificación UTF-8
    final bytes = utf8.encode(csvBuffer.toString());
    await file.writeAsBytes(bytes, flush: true);
    
    print('✅ CSV pacientes guardado: $filePath');
    
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
    csvBuffer.writeln('\uFEFFID,Usuario,Email,Teléfono,Rol,Profesional,Matrícula,Verificado,Creado En,Sincronizado');
    
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

    final dateStr = DateTime.now().toLocal().toString().split(' ')[0].replaceAll('-', '');
    final fileName = 'usuarios_$dateStr.csv';
    final filePath = '$directoryPath/$fileName';
    
    final file = File(filePath);
    final bytes = utf8.encode(csvBuffer.toString());
    await file.writeAsBytes(bytes, flush: true);
    
    print('✅ CSV usuarios guardado: $filePath');
    
    return filePath;
  }

  Future<String> _exportarTodosCSV(String directoryPath) async {
    final dateStr = DateTime.now().toLocal().toString().split(' ')[0].replaceAll('-', '');
    final folderName = 'HealthShield_Export_$dateStr';
    final exportDir = Directory('$directoryPath/$folderName');
    
    if (!await exportDir.exists()) {
      await exportDir.create(recursive: true);
      print('✅ Carpeta de exportación creada: ${exportDir.path}');
    }
    
    // Crear archivo .nomedia en la carpeta
    final nomediaFile = File('${exportDir.path}/.nomedia');
    if (!await nomediaFile.exists()) {
      await nomediaFile.writeAsString('', flush: true);
      print('✅ Archivo .nomedia creado');
    }
    
    // Exportar todos los tipos de datos
    await _exportarVacunasCSV(exportDir.path);
    await _exportarPacientesCSV(exportDir.path);
    await _exportarUsuariosCSV(exportDir.path);
    
    // Crear archivo README con instrucciones
    final readmeContent = '''
HealthShield - Exportación Completa
Fecha: ${DateTime.now().toLocal()}

Archivos CSV incluidos:
1. vacunas_$dateStr.csv - Todos los registros de vacunación
2. pacientes_$dateStr.csv - Lista de pacientes
3. usuarios_$dateStr.csv - Usuarios del sistema

Total registros exportados:
- Vacunas: $_totalVacunas
- Pacientes: $_totalPacientes
- Usuarios: $_totalUsuarios

Este archivo fue generado automáticamente por HealthShield.
    
Para abrir los archivos CSV:
1. Puedes abrirlos con:
   - Microsoft Excel
   - Google Sheets
   - LibreOffice Calc
   - Cualquier editor de texto

2. Si usas Excel y ves caracteres extraños:
   - Abre Excel
   - Ve a "Datos" > "Desde archivo de texto"
   - Selecciona el archivo CSV
   - En el asistente, selecciona "Delimitado"
   - Marca "Coma" como separador
   - En "Origen del archivo", selecciona "65001: Unicode (UTF-8)"
   - Finaliza el asistente

Ubicación de los archivos:
${exportDir.path}

Para compartir los archivos:
1. Conecta el dispositivo a una computadora
2. Activa "Transferencia de archivos" (File Transfer)
3. Navega a la ubicación de exportación
    ''';
    
    final readmeFile = File('${exportDir.path}/INSTRUCCIONES.txt');
    await readmeFile.writeAsString(readmeContent, flush: true);
    
    print('✅ Exportación completa guardada en: ${exportDir.path}');
    
    return exportDir.path;
  }

  Future<void> _mostrarExitoExportacion(String filePath, String fileName, String appDirPath) async {
    final file = File(filePath);
    bool fileExists = false;
    int fileSize = 0;
    DateTime? modifiedTime;
    
    try {
      fileExists = await file.exists();
      if (fileExists) {
        final fileStat = await file.stat();
        fileSize = fileStat.size;
        modifiedTime = fileStat.modified.toLocal();
      }
    } catch (e) {
      print('Error obteniendo información del archivo: $e');
    }
    
    final sizeInKB = fileSize > 0 ? (fileSize / 1024).toStringAsFixed(2) : '0';
    
    // Verificar extensión del archivo
    final fileExtension = fileName.toLowerCase().split('.').last;
    final isCsvFile = fileExtension == 'csv' || fileName.toLowerCase().endsWith('.csv');
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(isCsvFile ? Icons.insert_chart : Icons.folder, color: Colors.green),
            SizedBox(width: 8),
            Text('✅ Exportación Exitosa'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Archivo exportado correctamente:', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              
              // Información del archivo
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(isCsvFile ? Icons.table_chart : Icons.folder_open, size: 20, color: Colors.blue),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            fileName,
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    
                    Divider(height: 1),
                    SizedBox(height: 8),
                    
                    Row(
                      children: [
                        Icon(Icons.storage, size: 16, color: Colors.grey),
                        SizedBox(width: 8),
                        Text('Tamaño: ${sizeInKB} KB', style: TextStyle(fontSize: 14)),
                      ],
                    ),
                    SizedBox(height: 4),
                    
                    if (modifiedTime != null) ...[
                      Row(
                        children: [
                          Icon(Icons.schedule, size: 16, color: Colors.grey),
                          SizedBox(width: 8),
                          Text('Creado: ${modifiedTime.hour}:${modifiedTime.minute.toString().padLeft(2, '0')}', style: TextStyle(fontSize: 14)),
                        ],
                      ),
                      SizedBox(height: 4),
                    ],
                    
                    Row(
                      children: [
                        Icon(Icons.extension, size: 16, color: Colors.grey),
                        SizedBox(width: 8),
                        Text('Formato: ${isCsvFile ? 'CSV (Excel)' : 'Carpeta'}', style: TextStyle(fontSize: 14)),
                      ],
                    ),
                    SizedBox(height: 4),
                    
                    Row(
                      children: [
                        Icon(Icons.folder, size: 16, color: Colors.grey),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Ubicación: Documents/HealthShield',
                            style: TextStyle(fontSize: 14),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              SizedBox(height: 16),
              
              // Instrucciones
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '📋 Instrucciones para acceder:',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue[800]),
                    ),
                    SizedBox(height: 8),
                    
                    Text('1. Desde el dispositivo:'),
                    SizedBox(height: 4),
                    Text('   • Abre la app "Archivos" o "Files"'),
                    Text('   • Busca "Documents" en el almacenamiento interno'),
                    Text('   • Dentro de Documents, busca la carpeta "HealthShield"'),
                    SizedBox(height: 8),
                    
                    Text('2. Desde una computadora:'),
                    SizedBox(height: 4),
                    Text('   • Conecta el dispositivo por USB'),
                    Text('   • Activa "Transferencia de archivos"'),
                    Text('   • Abre la unidad del dispositivo'),
                    Text('   • Navega a: Internal storage/Documents/HealthShield'),
                  ],
                ),
              ),
              
              SizedBox(height: 8),
              
              // Botón para ver detalles
              if (fileExists)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // Mostrar snackbar con detalles
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('📁 Archivo guardado en:'),
                              SizedBox(height: 4),
                              Text(
                                'Documents/HealthShield',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          duration: Duration(seconds: 4),
                          action: SnackBarAction(
                            label: 'OK',
                            onPressed: () {},
                          ),
                        ),
                      );
                    },
                    icon: Icon(Icons.info, size: 20),
                    label: Text('Ver ubicación'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[50],
                      foregroundColor: Colors.blue[700],
                    ),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cerrar', style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
    );
    
    // Mostrar snackbar con información
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isCsvFile 
                      ? '✅ Archivo CSV guardado: $fileName'
                      : '✅ Carpeta con datos exportados',
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Ubicación: Documents/HealthShield',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _escapeCsv(String field) {
    if (field.isEmpty) return '';
    
    final cleanedField = field.trim();
    
    if (cleanedField.contains(',') || cleanedField.contains('"') || cleanedField.contains('\n') || cleanedField.contains('\r')) {
      return '"${cleanedField.replaceAll('"', '""')}"';
    }
    return cleanedField;
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
                    title: 'Verificar Profesional',
                    subtitle: 'Consultar cédula profesional en registro SACS',
                    icon: Icons.verified_user,
                    color: Colors.blue,
                    onTap: () {
                      Navigator.pushNamed(context, '/verificar-profesional');
                    },
                  ),

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
                    subtitle: 'Exportar datos a CSV (se guarda en Documents/HealthShield)',
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
                            leading: Icon(Icons.file_present, size: 20),
                            title: Text('Exportación de Datos'),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Los archivos CSV se guardan en:'),
                                SizedBox(height: 4),
                                Container(
                                  padding: EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.blue[50],
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Documents/HealthShield/',
                                        style: TextStyle(
                                          fontFamily: 'Monospace',
                                          fontSize: 12,
                                          color: Colors.blue[800],
                                        ),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        'Formato: CSV compatible con Excel',
                                        style: TextStyle(fontSize: 10, color: Colors.green[700]),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        'Ubicación: Almacenamiento interno principal',
                                        style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
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
                  SizedBox(height: 30),
                ],
              ),
            ),
    );
  }
}