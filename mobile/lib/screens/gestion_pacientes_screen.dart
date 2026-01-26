import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/paciente.dart';
import '../services/paciente_service.dart';
import '../services/api_service.dart';

class GestionPacientesScreen extends StatefulWidget {
  @override
  _GestionPacientesScreenState createState() => _GestionPacientesScreenState();
}

class _GestionPacientesScreenState extends State<GestionPacientesScreen> {
  final TextEditingController _cedulaController = TextEditingController();
  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _fechaNacimientoController = TextEditingController();
  final TextEditingController _telefonoController = TextEditingController();
  final TextEditingController _direccionController = TextEditingController();
  final TextEditingController _buscarController = TextEditingController();
  
  List<Paciente> _pacientes = [];
  List<Paciente> _pacientesFiltrados = [];
  bool _isLoading = false;
  bool _showForm = false;

  @override
  void initState() {
    super.initState();
    _cargarPacientes();
  }

  Future<void> _cargarPacientes() async {
    setState(() {
      _isLoading = true;
    });

    final pacienteService = Provider.of<PacienteService>(context, listen: false);
    final pacientes = await pacienteService.getPacientes();
    
    setState(() {
      _pacientes = pacientes;
      _pacientesFiltrados = pacientes;
      _isLoading = false;
    });
  }

  Future<void> _buscarPacientes() async {
    final query = _buscarController.text.trim();
    
    if (query.isEmpty) {
      setState(() {
        _pacientesFiltrados = _pacientes;
      });
      return;
    }

    final pacienteService = Provider.of<PacienteService>(context, listen: false);
    final resultados = await pacienteService.buscarPacientes(query);
    
    setState(() {
      _pacientesFiltrados = resultados;
    });
  }

  Future<void> _guardarPaciente() async {
    if (_cedulaController.text.isEmpty || _nombreController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cédula y nombre son obligatorios')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final pacienteService = Provider.of<PacienteService>(context, listen: false);
    final apiService = Provider.of<ApiService>(context, listen: false);
    
    final nuevoPaciente = Paciente(
      cedula: _cedulaController.text,
      nombre: _nombreController.text,
      fechaNacimiento: _fechaNacimientoController.text,
      telefono: _telefonoController.text.isNotEmpty ? _telefonoController.text : null,
      direccion: _direccionController.text.isNotEmpty ? _direccionController.text : null,
      createdAt: DateTime.now(),
    );

    try {
      await pacienteService.crearPaciente(nuevoPaciente);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Paciente guardado exitosamente'),
          backgroundColor: Colors.green,
        ),
      );
      
      _cedulaController.clear();
      _nombreController.clear();
      _fechaNacimientoController.clear();
      _telefonoController.clear();
      _direccionController.clear();
      
      setState(() {
        _showForm = false;
      });
      
      await _cargarPacientes();
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error al guardar paciente: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🔥 OBTENER PADDING INFERIOR SEGURO
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'HealthShield',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue),
        ),
        actions: [
          IconButton(
            icon: Icon(_showForm ? Icons.close : Icons.add),
            onPressed: () {
              setState(() {
                _showForm = !_showForm;
              });
            },
          ),
        ],
      ),
      body: Container(
        // 🔥 PADDING INFERIOR DINÁMICO
        padding: EdgeInsets.only(bottom: bottomPadding),
        child: Column(
          children: [
            // Barra de búsqueda
            Padding(
              padding: EdgeInsets.all(16.0),
              child: TextField(
                controller: _buscarController,
                decoration: InputDecoration(
                  labelText: 'Buscar pacientes',
                  hintText: 'Por cédula o nombre',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(Icons.clear),
                    onPressed: () {
                      _buscarController.clear();
                      _buscarPacientes();
                    },
                  ),
                ),
                onChanged: (value) => _buscarPacientes(),
              ),
            ),
            
            // Formulario para nuevo paciente
            if (_showForm)
              Card(
                margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text('Nuevo Paciente', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      SizedBox(height: 16),
                      TextField(
                        controller: _cedulaController,
                        decoration: InputDecoration(
                          labelText: 'Cédula *',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      SizedBox(height: 8),
                      TextField(
                        controller: _nombreController,
                        decoration: InputDecoration(
                          labelText: 'Nombre Completo *',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      SizedBox(height: 8),
                      TextField(
                        controller: _fechaNacimientoController,
                        decoration: InputDecoration(
                          labelText: 'Fecha de Nacimiento (DD/MM/AAAA)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      SizedBox(height: 8),
                      TextField(
                        controller: _telefonoController,
                        decoration: InputDecoration(
                          labelText: 'Teléfono',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.phone,
                      ),
                      SizedBox(height: 8),
                      TextField(
                        controller: _direccionController,
                        decoration: InputDecoration(
                          labelText: 'Dirección',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 2,
                      ),
                      SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _guardarPaciente,
                              child: Text('Guardar'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            
            // Lista de pacientes
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator())
                  : _pacientesFiltrados.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.people_outline, size: 64, color: Colors.grey),
                              SizedBox(height: 16),
                              Text(
                                'No hay pacientes registrados',
                                style: TextStyle(fontSize: 16, color: Colors.grey),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Haz clic en + para agregar un paciente',
                                style: TextStyle(fontSize: 14, color: Colors.grey),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _pacientesFiltrados.length,
                          itemBuilder: (context, index) {
                            final paciente = _pacientesFiltrados[index];
                            return Card(
                              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              child: ListTile(
                                leading: Icon(Icons.person, color: Colors.blue),
                                title: Text(paciente.nombre),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Cédula: ${paciente.cedula}'),
                                    if (paciente.fechaNacimiento.isNotEmpty)
                                      Text('Nacimiento: ${paciente.fechaNacimiento}'),
                                    if (paciente.telefono != null)
                                      Text('Tel: ${paciente.telefono}'),
                                  ],
                                ),
                                trailing: paciente.isSynced
                                    ? Icon(Icons.cloud_done, color: Colors.green)
                                    : Icon(Icons.cloud_off, color: Colors.orange),
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
}