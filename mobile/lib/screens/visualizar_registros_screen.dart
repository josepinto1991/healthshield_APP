import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/vacuna_service.dart';
import '../models/vacuna.dart';
import 'paciente_detalle_screen.dart';

class VisualizarRegistrosScreen extends StatefulWidget {
  @override
  _VisualizarRegistrosScreenState createState() => _VisualizarRegistrosScreenState();
}

class _VisualizarRegistrosScreenState extends State<VisualizarRegistrosScreen> {
  final _cedulaController = TextEditingController();
  List<Vacuna> _vacunasFiltradas = [];
  bool _isLoading = false;
  bool _mostrarResultados = false;

  Future<void> _buscarPorCedula() async {
    final query = _cedulaController.text.trim();

    if (query.isEmpty) {
      setState(() {
        _vacunasFiltradas = [];
        _mostrarResultados = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Por favor ingresa una cédula para buscar'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _mostrarResultados = false;
    });

    try {
      final vacunaService = Provider.of<VacunaService>(context, listen: false);
      final resultados = await vacunaService.buscarPorCedula(query);
      
      setState(() {
        _vacunasFiltradas = resultados;
        _isLoading = false;
        _mostrarResultados = true;
      });
      
      if (resultados.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se encontraron registros para la cédula: $query'),
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        // Agrupar por paciente
        final pacientesUnicos = resultados
            .where((v) => v.cedulaPaciente != null)
            .map((v) => v.cedulaPaciente!)
            .toSet();
            
        if (pacientesUnicos.length == 1) {
          final cedula = pacientesUnicos.first;
          final primeraVacuna = resultados.firstWhere(
            (v) => v.cedulaPaciente == cedula,
            orElse: () => resultados.first
          );
          
          // Solo un paciente encontrado, ir directamente a detalles
          _verDetallesPaciente(
            cedula,
            primeraVacuna.nombrePaciente ?? 'Paciente',
          );
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error en la búsqueda: $e'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  void _limpiarBusqueda() {
    _cedulaController.clear();
    setState(() {
      _vacunasFiltradas = [];
      _mostrarResultados = false;
    });
  }

  void _verDetallesPaciente(String cedula, String nombre) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PacienteDetalleScreen(
          cedula: cedula,
          nombre: nombre,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Agrupar pacientes únicos con conversión de tipos explícita
    final pacientesUnicos = <Map<String, String>>[];
    final cedulasUnicas = <String>{};
    
    for (final vacuna in _vacunasFiltradas) {
      if (vacuna.cedulaPaciente != null && !cedulasUnicas.contains(vacuna.cedulaPaciente)) {
        cedulasUnicas.add(vacuna.cedulaPaciente!);
        
        // CORRECCIÓN: Conversión explícita a String
        pacientesUnicos.add({
          'cedula': vacuna.cedulaPaciente!,
          'nombre': vacuna.nombrePaciente ?? 'Paciente',
        });
      }
    }

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
      ),
      body: Container(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewPadding.bottom + 20,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tabs de navegación
            Container(
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        Navigator.pushReplacementNamed(context, '/registro-vacuna');
                      },
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(
                        'Realizar Registro',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 30,
                    color: Colors.grey[300],
                  ),
                  Expanded(
                    child: TextButton(
                      onPressed: () {},
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(
                        'Visualizar Registro',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            SizedBox(height: 24),
            
            Text(
              'Buscar Paciente por Cédula',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            
            SizedBox(height: 8),
            
            Text(
              'Ingresa la cédula de identidad del paciente para ver su historial de vacunación.',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            
            SizedBox(height: 24),
            
            // Campo de búsqueda por cédula
            Card(
              elevation: 2,
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cédula de Identidad',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _cedulaController,
                            decoration: InputDecoration(
                              hintText: 'Ej: 1234567890',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.badge),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 16,
                              ),
                            ),
                            keyboardType: TextInputType.number,
                            onSubmitted: (_) => _buscarPorCedula(),
                          ),
                        ),
                        SizedBox(width: 8),
                        Column(
                          children: [
                            IconButton(
                              icon: Icon(Icons.search),
                              onPressed: _buscarPorCedula,
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                              ),
                              tooltip: 'Buscar paciente',
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Buscar',
                              style: TextStyle(fontSize: 10),
                            ),
                          ],
                        ),
                        if (_mostrarResultados) ...[
                          SizedBox(width: 8),
                          Column(
                            children: [
                              IconButton(
                                icon: Icon(Icons.clear),
                                onPressed: _limpiarBusqueda,
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.grey[300],
                                  foregroundColor: Colors.grey[700],
                                ),
                                tooltip: 'Limpiar búsqueda',
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Limpiar',
                                style: TextStyle(fontSize: 10),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            SizedBox(height: 16),
            
            // Resultados de búsqueda
            if (_isLoading)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Buscando registros...'),
                    ],
                  ),
                ),
              )
            else if (_mostrarResultados)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Resultados de la Búsqueda',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Chip(
                          label: Text(
                            '${pacientesUnicos.length} paciente(s)',
                            style: TextStyle(color: Colors.white),
                          ),
                          backgroundColor: Colors.blue,
                        ),
                      ],
                    ),
                    
                    SizedBox(height: 8),
                    
                    if (pacientesUnicos.isEmpty)
                      Expanded(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.search_off, size: 64, color: Colors.grey[300]),
                              SizedBox(height: 16),
                              Text(
                                'No se encontraron pacientes',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[500],
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Verifica la cédula e intenta nuevamente',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[400],
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: ListView.builder(
                          itemCount: pacientesUnicos.length,
                          itemBuilder: (context, index) {
                            final paciente = pacientesUnicos[index];
                            
                            // CORRECCIÓN: Acceso explícito con conversión
                            final cedula = paciente['cedula'] as String;
                            final nombre = paciente['nombre'] as String;
                            
                            return Card(
                              margin: EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.blue[50],
                                  child: Icon(Icons.person, color: Colors.blue),
                                ),
                                title: Text(
                                  nombre,
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Cédula: $cedula'),
                                  ],
                                ),
                                trailing: Chip(
                                  label: Text(
                                    'VER DETALLES',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  backgroundColor: Colors.blue,
                                ),
                                onTap: () => _verDetallesPaciente(cedula, nombre),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              )
            else
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search, size: 64, color: Colors.grey[300]),
                      SizedBox(height: 16),
                      Text(
                        'Buscar Paciente',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[500],
                        ),
                      ),
                      SizedBox(height: 8),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          'Ingresa una cédula en el campo superior para buscar el historial de vacunación.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[400],
                          ),
                        ),
                      ),
                      SizedBox(height: 24),
                      Container(
                        padding: EdgeInsets.all(16),
                        margin: EdgeInsets.symmetric(horizontal: 32),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.info_outline, size: 16, color: Colors.blue),
                                SizedBox(width: 8),
                                Text(
                                  'Información',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Solo se puede buscar por cédula de identidad. Para pacientes menores, usar la cédula del tutor.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
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

  @override
  void dispose() {
    _cedulaController.dispose();
    super.dispose();
  }
}