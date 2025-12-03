import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/vacuna_service.dart';
import '../models/vacuna.dart';

class VisualizarRegistrosScreen extends StatefulWidget {
  @override
  _VisualizarRegistrosScreenState createState() => _VisualizarRegistrosScreenState();
}

class _VisualizarRegistrosScreenState extends State<VisualizarRegistrosScreen> {
  final _cedulaController = TextEditingController();
  final _nombreController = TextEditingController();
  List<Vacuna> _vacunas = [];
  List<Vacuna> _vacunasFiltradas = [];
  bool _isLoading = false;
  String _tipoBusqueda = 'cedula';

  @override
  void initState() {
    super.initState();
    _cargarVacunas();
  }

  Future<void> _cargarVacunas() async {
    setState(() {
      _isLoading = true;
    });

    final vacunaService = Provider.of<VacunaService>(context, listen: false);
    final vacunas = await vacunaService.getVacunas();
    
    setState(() {
      _vacunas = vacunas;
      _vacunasFiltradas = vacunas;
      _isLoading = false;
    });
  }

  void _buscar() {
    final query = _tipoBusqueda == 'cedula' 
        ? _cedulaController.text.trim()
        : _nombreController.text.trim();

    if (query.isEmpty) {
      setState(() {
        _vacunasFiltradas = _vacunas;
      });
      return;
    }

    setState(() {
      _vacunasFiltradas = _vacunas.where((vacuna) {
        if (_tipoBusqueda == 'cedula') {
          return vacuna.cedulaPaciente.toLowerCase().contains(query.toLowerCase());
        } else {
          return vacuna.nombrePaciente.toLowerCase().contains(query.toLowerCase());
        }
      }).toList();
    });
  }

  void _limpiarBusqueda() {
    _cedulaController.clear();
    _nombreController.clear();
    setState(() {
      _vacunasFiltradas = _vacunas;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:  Text(
                    'HealthShield',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
              ),
          ),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () {
              // TODO: Implementar logout
            },
            tooltip: 'Cerrar sesión',
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tabs de navegación
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      Navigator.pushReplacementNamed(context, '/registro');
                    },
                    child: Text(
                      'Realizar Registro',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ),
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      // Ya estamos en visualizar registro
                    },
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
            
            SizedBox(height: 16),
            
            Text(
              'Visualización de Vacunas',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            
            SizedBox(height: 8),
            
            Text(
              'En esta vista se realiza la visualización de vacunas a pacientes, niños o adulto, tanto búsqueda por cédula de identidad de cada paciente.',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            
            SizedBox(height: 24),
            
            // Selector de tipo de búsqueda
            Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tipo de Búsqueda',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ListTile(
                            title: Text('Por Cédula'),
                            leading: Radio<String>(
                              value: 'cedula',
                              groupValue: _tipoBusqueda,
                              onChanged: (value) {
                                setState(() {
                                  _tipoBusqueda = value!;
                                  _cedulaController.clear();
                                  _nombreController.clear();
                                  _vacunasFiltradas = _vacunas;
                                });
                              },
                            ),
                          ),
                        ),
                        Expanded(
                          child: ListTile(
                            title: Text('Por Nombre'),
                            leading: Radio<String>(
                              value: 'nombre',
                              groupValue: _tipoBusqueda,
                              onChanged: (value) {
                                setState(() {
                                  _tipoBusqueda = value!;
                                  _cedulaController.clear();
                                  _nombreController.clear();
                                  _vacunasFiltradas = _vacunas;
                                });
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            SizedBox(height: 16),
            
            // Campo de búsqueda
            Text(
              _tipoBusqueda == 'cedula' ? 'Cédula de Identidad' : 'Nombre del Paciente',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _tipoBusqueda == 'cedula' ? _cedulaController : _nombreController,
                    decoration: InputDecoration(
                      hintText: _tipoBusqueda == 'cedula' 
                          ? 'Buscar por cédula' 
                          : 'Buscar por nombre',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) => _buscar(),
                  ),
                ),
                SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.clear),
                  onPressed: _limpiarBusqueda,
                  tooltip: 'Limpiar búsqueda',
                ),
              ],
            ),
            
            SizedBox(height: 16),
            
            Text(
              'Resultados de Búsqueda:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            
            SizedBox(height: 8),
            
            _isLoading
                ? Center(child: CircularProgressIndicator())
                : _vacunasFiltradas.isEmpty
                    ? Expanded(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.search_off, size: 64, color: Colors.grey),
                              SizedBox(height: 16),
                              Text(
                                _vacunas.isEmpty
                                    ? 'No hay registros de vacunas'
                                    : 'No se encontraron resultados',
                                style: TextStyle(fontSize: 16, color: Colors.grey),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: 8),
                              if (_vacunas.isEmpty)
                                Text(
                                  'Pulsa "Realizar Registro" para agregar el primer registro',
                                  style: TextStyle(fontSize: 14, color: Colors.grey),
                                  textAlign: TextAlign.center,
                                ),
                            ],
                          ),
                        ),
                      )
                    : Expanded(
                        child: ListView.builder(
                          itemCount: _vacunasFiltradas.length,
                          itemBuilder: (context, index) {
                            final vacuna = _vacunasFiltradas[index];
                            return Card(
                              margin: EdgeInsets.symmetric(vertical: 4),
                              child: ListTile(
                                leading: Icon(
                                  vacuna.tipoPaciente == 'niño' 
                                      ? Icons.child_care 
                                      : Icons.person,
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
                                    if (vacuna.lote != null)
                                      Text('Lote: ${vacuna.lote}'),
                                    if (vacuna.proximaDosis != null)
                                      Text('Próxima dosis: ${vacuna.proximaDosis}'),
                                  ],
                                ),
                                trailing: Chip(
                                  label: Text(
                                    vacuna.tipoPaciente,
                                    style: TextStyle(color: Colors.white, fontSize: 12),
                                  ),
                                  backgroundColor: vacuna.tipoPaciente == 'niño' 
                                      ? Colors.orange 
                                      : Colors.green,
                                ),
                              ),
                            );
                          },
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
    _nombreController.dispose();
    super.dispose();
  }
}