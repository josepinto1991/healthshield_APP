import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import '../services/auth_service.dart';
import '../utils/app_config.dart';

class VerificarProfesionalScreen extends StatefulWidget {
  @override
  _VerificarProfesionalScreenState createState() => _VerificarProfesionalScreenState();
}

class _VerificarProfesionalScreenState extends State<VerificarProfesionalScreen> {
  final TextEditingController _cedulaController = TextEditingController();
  bool _isLoading = false;
  Map<String, dynamic>? _resultadoValidacion;
  Map<String, dynamic>? _detallesProfesional;
  String _error = '';
  
  // Formato de cédula válido: V-12345678 o E-12345678
  final RegExp _cedulaRegex = RegExp(r'^[VE]-\d{7,8}$');
  
  @override
  void dispose() {
    _cedulaController.dispose();
    super.dispose();
  }
  
  Future<void> _validarCedula() async {
    final cedula = _cedulaController.text.trim().toUpperCase();
    
    if (cedula.isEmpty) {
      setState(() {
        _error = 'Por favor ingresa una cédula';
        _resultadoValidacion = null;
        _detallesProfesional = null;
      });
      return;
    }
    
    if (!_cedulaRegex.hasMatch(cedula)) {
      setState(() {
        _error = 'Formato inválido. Use: V-12345678 o E-12345678';
        _resultadoValidacion = null;
        _detallesProfesional = null;
      });
      return;
    }
    
    setState(() {
      _isLoading = true;
      _error = '';
      _resultadoValidacion = null;
      _detallesProfesional = null;
    });
    
    try {
      // Primero validar la cédula
      final validacionResult = await _validarCedulaEnServidor(cedula);
      
      if (validacionResult['success'] == true) {
        setState(() {
          _resultadoValidacion = validacionResult;
        });
        
        // Si es válida, obtener detalles
        if (validacionResult['has_details'] == true && 
            validacionResult['is_valid'] == true) {
          final detallesResult = await _obtenerDetallesProfesional(cedula, validacionResult['validation_id']);
          
          if (detallesResult['success'] == true) {
            setState(() {
              _detallesProfesional = detallesResult;
            });
          } else {
            setState(() {
              _error = detallesResult['error'] ?? 'Error obteniendo detalles';
            });
          }
        }
      } else {
        setState(() {
          _error = validacionResult['error'] ?? 'Cédula no válida';
          _resultadoValidacion = validacionResult;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error de conexión: $e';
        _resultadoValidacion = null;
        _detallesProfesional = null;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<Map<String, dynamic>> _validarCedulaEnServidor(String cedula) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUser = authService.currentUser;
    
    final url = Uri.parse('${AppConfig.apiBaseUrl}/api/profesionales/validar');
    
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${currentUser?.serverId ?? ''}',
        },
        body: json.encode({'cedula': cedula}),
      );
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {
          'success': false,
          'error': 'Error del servidor: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Error de conexión: $e',
      };
    }
  }
  
  Future<Map<String, dynamic>> _obtenerDetallesProfesional(String cedula, String validationId) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUser = authService.currentUser;
    
    final url = Uri.parse('${AppConfig.apiBaseUrl}/api/profesionales/detalles?cedula=${Uri.encodeComponent(cedula)}&validation_id=$validationId');
    
    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer ${currentUser?.serverId ?? ''}',
        },
      );
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {
          'success': false,
          'error': 'Error del servidor: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Error de conexión: $e',
      };
    }
  }
  
  void _limpiarResultados() {
    setState(() {
      _cedulaController.clear();
      _resultadoValidacion = null;
      _detallesProfesional = null;
      _error = '';
    });
  }
  
  Widget _buildResultadoValidacion() {
    if (_resultadoValidacion == null) return SizedBox();
    
    final bool esValido = _resultadoValidacion!['is_valid'] ?? false;
    final String mensaje = _resultadoValidacion!['validation_message'] ?? '';
    final String timestamp = _resultadoValidacion!['timestamp'] ?? '';
    
    return Card(
      elevation: 3,
      color: esValido ? Colors.green[50] : Colors.orange[50],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  esValido ? Icons.verified : Icons.warning,
                  color: esValido ? Colors.green : Colors.orange,
                  size: 24,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    esValido ? 'CÉDULA VÁLIDA' : 'CÉDULA NO VÁLIDA',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: esValido ? Colors.green[800] : Colors.orange[800],
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Text(
              mensaje,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[700],
              ),
            ),
            SizedBox(height: 8),
            if (timestamp.isNotEmpty)
              Text(
                'Validado: ${_formatearFecha(timestamp)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildDetallesProfesional() {
    if (_detallesProfesional == null) return SizedBox();
    
    final data = _detallesProfesional!['data'] ?? {};
    final userData = data['nombre'] != null ? {
      'nombre': data['nombre'],
      'cedula': data['cedula'],
      'tipo_cedula': data['tipo_cedula'],
      'estatus': data['estatus'],
    } : {};
    
    final registros = data['registros'] ?? [];
    
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '📋 INFORMACIÓN DEL PROFESIONAL',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.blue[800],
              ),
            ),
            SizedBox(height: 16),
            
            if (userData.isNotEmpty) ...[
              _buildInfoItem('Nombre', userData['nombre']),
              _buildInfoItem('Cédula', userData['cedula']),
              _buildInfoItem('Tipo', userData['tipo_cedula']),
              _buildInfoItem('Estatus', userData['estatus']),
              Divider(height: 24),
            ],
            
            Text(
              '📜 REGISTROS PROFESIONALES',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.green[800],
              ),
            ),
            SizedBox(height: 12),
            
            if (registros.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Text(
                  'No se encontraron registros profesionales',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: registros.length,
                separatorBuilder: (context, index) => Divider(height: 16),
                itemBuilder: (context, index) {
                  final registro = registros[index];
                  return _buildRegistroProfesional(registro, index + 1);
                },
              ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildInfoItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[900],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildRegistroProfesional(Map<String, dynamic> registro, int numero) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Registro #$numero',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.blue[700],
          ),
        ),
        SizedBox(height: 8),
        _buildInfoItem('Profesión', registro['profesion'] ?? 'No especificado'),
        _buildInfoItem('Licencia', registro['licencia'] ?? 'No especificada'),
        _buildInfoItem('Fecha de registro', registro['fecha_registro'] ?? 'No especificada'),
        _buildInfoItem('Tomo', registro['tomo_registro'] ?? 'No especificado'),
        _buildInfoItem('Folio', registro['folio_registro'] ?? 'No especificado'),
        _buildInfoItem('Número de registro', registro['numero_registro'] ?? 'No especificado'),
      ],
    );
  }
  
  String _formatearFecha(String fechaISO) {
    try {
      final fecha = DateTime.parse(fechaISO);
      return '${fecha.day}/${fecha.month}/${fecha.year} ${fecha.hour}:${fecha.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return fechaISO;
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final currentUser = authService.currentUser;
    
    // Verificar que sea admin
    if (currentUser == null || !currentUser.isAdmin) {
      return Scaffold(
        appBar: AppBar(title: Text('Acceso Denegado')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.block, size: 64, color: Colors.red),
              SizedBox(height: 16),
              Text(
                'Acceso Restringido',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'Solo los administradores pueden acceder a esta sección',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Volver al Menú Principal'),
              ),
            ],
          ),
        ),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Verificar Profesional'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Título y descripción
            Text(
              'Verificación de Profesionales de la Salud',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.blue[800],
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Consulta el registro oficial de profesionales usando el sistema SACS del Ministerio de Salud',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            
            SizedBox(height: 24),
            
            // Input de cédula
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cédula Profesional',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Formato: V-12345678 o E-12345678',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    SizedBox(height: 12),
                    TextField(
                      controller: _cedulaController,
                      decoration: InputDecoration(
                        prefixIcon: Icon(Icons.badge),
                        hintText: 'Ej: V-12345678',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 16,
                        ),
                      ),
                      style: TextStyle(fontSize: 16),
                      textCapitalization: TextCapitalization.characters,
                      onSubmitted: (_) => _validarCedula(),
                    ),
                    SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isLoading ? null : _validarCedula,
                            icon: _isLoading 
                                ? SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : Icon(Icons.search, size: 20),
                            label: Text(_isLoading ? 'VERIFICANDO...' : 'VERIFICAR CÉDULA'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        if (_resultadoValidacion != null || _detallesProfesional != null)
                          TextButton.icon(
                            onPressed: _limpiarResultados,
                            icon: Icon(Icons.clear, size: 20),
                            label: Text('LIMPIAR'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            SizedBox(height: 16),
            
            // Mensaje de error
            if (_error.isNotEmpty)
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _error,
                        style: TextStyle(color: Colors.red[800]),
                      ),
                    ),
                  ],
                ),
              ),
            
            SizedBox(height: 16),
            
            // Resultado de validación
            if (_resultadoValidacion != null) 
              _buildResultadoValidacion(),
            
            SizedBox(height: 16),
            
            // Detalles del profesional
            if (_detallesProfesional != null)
              _buildDetallesProfesional(),
            
            SizedBox(height: 16),
            
            // Información adicional
            Card(
              elevation: 1,
              color: Colors.grey[50],
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Información del Sistema',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[800],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      '• Este sistema consulta el registro oficial SACS del Ministerio de Salud',
                      style: TextStyle(fontSize: 12),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '• Los datos mostrados son proporcionados por el sistema nacional',
                      style: TextStyle(fontSize: 12),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '• Para dudas o reclamos, contactar al Ministerio de Salud',
                      style: TextStyle(fontSize: 12),
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
}