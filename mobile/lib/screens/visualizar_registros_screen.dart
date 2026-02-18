// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../services/vacuna_service.dart';
// import '../services/api_service.dart';
// import '../services/auth_service.dart';
// import '../models/vacuna.dart';
// import 'paciente_detalle_screen.dart';

// class VisualizarRegistrosScreen extends StatefulWidget {
//   @override
//   _VisualizarRegistrosScreenState createState() => _VisualizarRegistrosScreenState();
// }

// class _VisualizarRegistrosScreenState extends State<VisualizarRegistrosScreen> {
//   final _cedulaController = TextEditingController();
//   List<Vacuna> _vacunasBackend = [];
//   List<Vacuna> _vacunasFiltradas = [];
//   bool _isLoading = false;
//   bool _mostrarResultados = false;
//   String _modoBusqueda = 'todos';
//   String? _errorMessage;
//   bool _conexionExitosa = true;
//   bool _usandoBackend = false;
//   bool _mostrarSoloBackend = false;

//   @override
//   void initState() {
//     super.initState();
//     _cargarDatos();
//   }

//   Future<void> _cargarDatos() async {
//     setState(() {
//       _isLoading = true;
//       _errorMessage = null;
//     });

//     try {
//       // Cargar vacunas locales primero
//       final vacunaService = Provider.of<VacunaService>(context, listen: false);
//       final vacunasLocales = await vacunaService.getVacunas();
      
//       // Intentar cargar del backend
//       final apiService = Provider.of<ApiService>(context, listen: false);
//       final authService = Provider.of<AuthService>(context, listen: false);
      
//       bool backendDisponible = false;
      
//       if (authService.currentUser != null) {
//         try {
//           // Verificar conexión al backend
//           backendDisponible = await apiService.checkServerStatus();
          
//           if (backendDisponible) {
//             // Intentar autenticar
//             final loginResult = await apiService.login(
//               authService.currentUser!.username,
//               authService.currentUser!.password
//             );
            
//             if (!loginResult['success']) {
//               await apiService.login('admin', 'admin123');
//             }
            
//             // Obtener vacunas del backend
//             print('📡 Obteniendo vacunas del backend...');
//             final result = await apiService.getVacunasFromServer();
            
//             if (result['success'] && result['data'] != null) {
//               List<Vacuna> vacunasBackend = [];
//               final data = result['data'];
              
//               if (data is List) {
//                 for (var item in data) {
//                   try {
//                     // Asegurar que el item tenga el formato correcto
//                     Map<String, dynamic> vacunaData = {};
                    
//                     if (item is Map<String, dynamic>) {
//                       vacunaData = item;
//                     } else if (item is Map) {
//                       vacunaData = Map<String, dynamic>.from(item);
//                     }
                    
//                     // Asegurar campos requeridos
//                     if (!vacunaData.containsKey('nombre_vacuna') && vacunaData.containsKey('nombreVacuna')) {
//                       vacunaData['nombre_vacuna'] = vacunaData['nombreVacuna'];
//                     }
                    
//                     if (!vacunaData.containsKey('fecha_aplicacion') && vacunaData.containsKey('fechaAplicacion')) {
//                       vacunaData['fecha_aplicacion'] = vacunaData['fechaAplicacion'];
//                     }
                    
//                     if (!vacunaData.containsKey('nombre_paciente') && vacunaData.containsKey('nombrePaciente')) {
//                       vacunaData['nombre_paciente'] = vacunaData['nombrePaciente'];
//                     }
                    
//                     if (!vacunaData.containsKey('cedula_paciente') && vacunaData.containsKey('cedulaPaciente')) {
//                       vacunaData['cedula_paciente'] = vacunaData['cedulaPaciente'];
//                     }
                    
//                     // Asegurar campo es_menor
//                     if (!vacunaData.containsKey('es_menor')) {
//                       vacunaData['es_menor'] = vacunaData['esMenor'] ?? false;
//                     }
                    
//                     final vacuna = Vacuna.fromJson(vacunaData);
//                     vacunasBackend.add(vacuna);
//                   } catch (e) {
//                     print('⚠️ Error parseando vacuna: $e - Item: $item');
//                   }
//                 }
//               } else if (data is Map && data.containsKey('vacunas')) {
//                 final vacunasData = data['vacunas'];
//                 if (vacunasData is List) {
//                   for (var item in vacunasData) {
//                     try {
//                       final vacuna = Vacuna.fromJson(item);
//                       vacunasBackend.add(vacuna);
//                     } catch (e) {
//                       print('⚠️ Error parseando vacuna: $e');
//                     }
//                   }
//                 }
//               } else if (data is Map && data.containsKey('data')) {
//                 final nestedData = data['data'];
//                 if (nestedData is List) {
//                   for (var item in nestedData) {
//                     try {
//                       final vacuna = Vacuna.fromJson(item);
//                       vacunasBackend.add(vacuna);
//                     } catch (e) {
//                       print('⚠️ Error parseando vacuna: $e');
//                     }
//                   }
//                 }
//               }
              
//               setState(() {
//                 _vacunasBackend = vacunasBackend;
//                 _vacunasFiltradas = vacunasBackend;
//                 _usandoBackend = true;
//                 _conexionExitosa = true;
//               });
              
//               print('✅ Cargadas ${vacunasBackend.length} vacunas del backend');
              
//               // Guardar vacunas localmente para referencia
//               for (var vacuna in vacunasBackend) {
//                 try {
//                   await vacunaService.saveVacunaFromServer(vacuna);
//                 } catch (e) {
//                   print('⚠️ Error guardando vacuna localmente: $e');
//                 }
//               }
              
//               setState(() {
//                 _isLoading = false;
//               });
//               return;
              
//             } else {
//               print('⚠️ No se pudieron obtener vacunas del backend: ${result['error']}');
//             }
//           }
//         } catch (e) {
//           print('⚠️ Error conectando al backend: $e');
//         }
//       }
      
//       // Si no se puede conectar al backend, usar datos locales
//       setState(() {
//         _vacunasBackend = [];
//         _vacunasFiltradas = vacunasLocales;
//         _usandoBackend = false;
//         _isLoading = false;
//       });
      
//       print('✅ Cargadas ${vacunasLocales.length} vacunas locales');
      
//     } catch (e) {
//       print('❌ Error cargando datos: $e');
//       setState(() {
//         _isLoading = false;
//         _errorMessage = 'Error cargando datos: $e';
//         _conexionExitosa = false;
//       });
//     }
//   }

//   Future<void> _buscarPorCedula() async {
//     final query = _cedulaController.text.trim();

//     if (query.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Por favor ingresa una cédula para buscar'),
//           duration: Duration(seconds: 2),
//         ),
//       );
//       return;
//     }

//     setState(() {
//       _isLoading = true;
//       _mostrarResultados = false;
//       _modoBusqueda = 'cedula';
//     });

//     try {
//       List<Vacuna> resultados = [];
      
//       if (_usandoBackend && _conexionExitosa) {
//         // Buscar en datos del backend
//         resultados = _vacunasBackend.where((vacuna) {
//           return vacuna.cedulaPaciente != null && 
//                  vacuna.cedulaPaciente!.toLowerCase().contains(query.toLowerCase());
//         }).toList();
//       } else {
//         // Buscar en datos locales
//         final vacunaService = Provider.of<VacunaService>(context, listen: false);
//         resultados = await vacunaService.buscarPorCedula(query);
//       }
      
//       setState(() {
//         _vacunasFiltradas = resultados;
//         _isLoading = false;
//         _mostrarResultados = true;
//       });
      
//       if (resultados.isEmpty) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('No se encontraron registros para la cédula: $query'),
//             duration: Duration(seconds: 3),
//           ),
//         );
//       }
//     } catch (e) {
//       setState(() {
//         _isLoading = false;
//       });
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Error en la búsqueda: $e'),
//           backgroundColor: Colors.red,
//           duration: Duration(seconds: 3),
//         ),
//       );
//     }
//   }

//   void _limpiarBusqueda() {
//     _cedulaController.clear();
//     setState(() {
//       _vacunasFiltradas = _usandoBackend ? _vacunasBackend : _vacunasFiltradas;
//       _mostrarResultados = false;
//       _modoBusqueda = 'todos';
//     });
//   }

//   void _alternarFuenteDatos() {
//     setState(() {
//       _usandoBackend = !_usandoBackend;
//       if (_usandoBackend) {
//         _vacunasFiltradas = _vacunasBackend;
//       } else {
//         // Cargar vacunas locales
//         _cargarVacunasLocales();
//       }
//     });
//   }

//   Future<void> _cargarVacunasLocales() async {
//     try {
//       final vacunaService = Provider.of<VacunaService>(context, listen: false);
//       final vacunasLocales = await vacunaService.getVacunas();
      
//       setState(() {
//         _vacunasFiltradas = vacunasLocales;
//       });
//     } catch (e) {
//       print('❌ Error cargando vacunas locales: $e');
//     }
//   }

//   // ... [resto de métodos como _agruparPorPaciente, _buildPacienteCard, etc.] ...
//   // Mantener todos los métodos iguales hasta el final del build

//   List<Map<String, dynamic>> _agruparPorPaciente() {
//     final Map<String, Map<String, dynamic>> pacientes = {};
    
//     for (final vacuna in _vacunasFiltradas) {
//       if (vacuna.nombrePaciente == null || vacuna.cedulaPaciente == null) {
//         continue;
//       }
      
//       final key = vacuna.pacienteIdUnico;
      
//       if (!pacientes.containsKey(key)) {
//         pacientes[key] = {
//           'nombre': vacuna.nombrePaciente!,
//           'cedula': vacuna.cedulaPaciente!,
//           'esMenor': vacuna.esMenor,
//           'cedulaTutor': vacuna.cedulaTutor,
//           'cedulaPropia': vacuna.cedulaPropia,
//           'vacunas': <Vacuna>[],
//           'totalVacunas': 0,
//           'ultimaFecha': '',
//           'tieneAtrasadas': false,
//           'tipo': vacuna.esMenor ? 'niño 👶' : 'adulto 👤',
//         };
//       }
      
//       pacientes[key]!['vacunas'].add(vacuna);
//       pacientes[key]!['totalVacunas']++;
      
//       final fechaActual = vacuna.fechaAplicacion;
//       final ultimaFecha = pacientes[key]!['ultimaFecha'] as String;
//       if (ultimaFecha.isEmpty || fechaActual.compareTo(ultimaFecha) > 0) {
//         pacientes[key]!['ultimaFecha'] = fechaActual;
//       }
      
//       if (vacuna.proximaDosisPasada) {
//         pacientes[key]!['tieneAtrasadas'] = true;
//       }
//     }
    
//     final listaPacientes = pacientes.values.toList();
//     listaPacientes.sort((a, b) {
//       return (a['nombre'] as String).compareTo(b['nombre'] as String);
//     });
    
//     return listaPacientes;
//   }

//   Widget _buildPacienteCard(Map<String, dynamic> paciente) {
//     final nombre = paciente['nombre'] as String;
//     final cedula = paciente['cedula'] as String;
//     final esMenor = paciente['esMenor'] as bool;
//     final totalVacunas = paciente['totalVacunas'] as int;
//     final tieneAtrasadas = paciente['tieneAtrasadas'] as bool;
//     final tipo = paciente['tipo'] as String;
//     final vacunas = paciente['vacunas'] as List<Vacuna>;
    
//     final String nombreMostrar = nombre.length > 20 
//         ? '${nombre.substring(0, 20)}...' 
//         : nombre;
    
//     return Card(
//       margin: EdgeInsets.only(bottom: 8),
//       child: ListTile(
//         leading: CircleAvatar(
//           backgroundColor: esMenor ? Colors.blue : Colors.green,
//           child: Icon(
//             esMenor ? Icons.child_care : Icons.person,
//             color: Colors.white,
//             size: 20,
//           ),
//         ),
//         title: Text(
//           nombreMostrar,
//           style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
//         ),
//         subtitle: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text('Cédula: $cedula', style: TextStyle(fontSize: 13)),
//             SizedBox(height: 6),
//             Wrap(
//               spacing: 6,
//               runSpacing: 4,
//               children: [
//                 Chip(
//                   label: Text(
//                     tipo,
//                     style: TextStyle(color: Colors.white, fontSize: 9),
//                   ),
//                   backgroundColor: esMenor ? Colors.blue : Colors.green,
//                   padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
//                 ),
//                 Chip(
//                   label: Text(
//                     '$totalVacunas ${totalVacunas > 1 ? 'vacunas' : 'vacuna'}',
//                     style: TextStyle(fontSize: 9),
//                   ),
//                   backgroundColor: Colors.grey[200],
//                   padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
//                 ),
//                 if (tieneAtrasadas)
//                   Chip(
//                     label: Text(
//                       'ATRASADA',
//                       style: TextStyle(color: Colors.white, fontSize: 8),
//                     ),
//                     backgroundColor: Colors.red,
//                     padding: EdgeInsets.symmetric(horizontal: 4, vertical: 1),
//                   ),
//                 if (_usandoBackend)
//                   Chip(
//                     label: Text(
//                       'SERVIDOR',
//                       style: TextStyle(color: Colors.white, fontSize: 8),
//                     ),
//                     backgroundColor: Colors.purple,
//                     padding: EdgeInsets.symmetric(horizontal: 4, vertical: 1),
//                   ),
//               ],
//             ),
//             if (esMenor && paciente['cedulaTutor'] != null)
//               Padding(
//                 padding: EdgeInsets.only(top: 4),
//                 child: Text(
//                   'Tutor: ${paciente['cedulaTutor']}',
//                   style: TextStyle(fontSize: 11, color: Colors.blue[700]),
//                 ),
//               ),
//           ],
//         ),
//         trailing: Icon(Icons.arrow_forward_ios, size: 14),
//         onTap: () {
//           Navigator.push(
//             context,
//             MaterialPageRoute(
//               builder: (context) => PacienteDetalleScreen(
//                 cedula: cedula,
//                 nombre: nombre,
//                 esGrupoFamiliar: false,
//                 vacunas: vacunas,
//               ),
//             ),
//           );
//         },
//       ),
//     );
//   }

//   Widget _buildEstadoConexion() {
//     if (!_conexionExitosa) {
//       return Container(
//         padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//         color: Colors.red[50],
//         child: Row(
//           children: [
//             Icon(Icons.wifi_off, color: Colors.red, size: 20),
//             SizedBox(width: 8),
//             Expanded(
//               child: Text(
//                 _errorMessage ?? 'No se puede conectar al servidor',
//                 style: TextStyle(color: Colors.red, fontSize: 13),
//               ),
//             ),
//             TextButton(
//               onPressed: _cargarDatos,
//               child: Text('Reintentar', style: TextStyle(fontSize: 13)),
//             ),
//           ],
//         ),
//       );
//     }
    
//     if (_usandoBackend) {
//       return Container(
//         padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//         color: Colors.green[50],
//         child: Row(
//           children: [
//             Icon(Icons.cloud_done, color: Colors.green, size: 20),
//             SizedBox(width: 8),
//             Expanded(
//               child: Text(
//                 'Mostrando datos del servidor (${_vacunasBackend.length} vacunas)',
//                 style: TextStyle(color: Colors.green[800], fontSize: 13),
//               ),
//             ),
//             TextButton(
//               onPressed: _alternarFuenteDatos,
//               child: Text('Ver locales', style: TextStyle(fontSize: 13)),
//             ),
//           ],
//         ),
//       );
//     }
    
//     return Container();
//   }

//   @override
//   Widget build(BuildContext context) {
//     final pacientes = _agruparPorPaciente();
//     final tieneResultados = pacientes.isNotEmpty;

//     return Scaffold(
//       appBar: AppBar(
//         title: Text(
//           'HealthShield',
//           style: TextStyle(
//             fontSize: 18,
//             fontWeight: FontWeight.bold,
//             color: Colors.blue,
//           ),
//         ),
//         actions: [
//           IconButton(
//             icon: Icon(Icons.cloud_download, size: 20),
//             onPressed: () async {
//               setState(() {
//                 _usandoBackend = true;
//               });
//               await _cargarDatos();
//             },
//             tooltip: 'Cargar del servidor',
//           ),
//           IconButton(
//             icon: Icon(Icons.refresh, size: 20),
//             onPressed: _cargarDatos,
//             tooltip: 'Actualizar datos',
//           ),
//         ],
//       ),
//       body: Column(
//         children: [
//           _buildEstadoConexion(),
          
//           // ... [resto del build igual] ...
//           Card(
//             margin: EdgeInsets.all(12),
//             child: Padding(
//               padding: EdgeInsets.all(8),
//               child: Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceAround,
//                 children: [
//                   Expanded(
//                     child: ChoiceChip(
//                       label: Row(
//                         mainAxisAlignment: MainAxisAlignment.center,
//                         children: [
//                           Icon(Icons.list, size: 16),
//                           SizedBox(width: 6),
//                           Flexible(
//                             child: Text(
//                               'Todos',
//                               style: TextStyle(fontSize: 12),
//                               overflow: TextOverflow.ellipsis,
//                             ),
//                           ),
//                         ],
//                       ),
//                       selected: _modoBusqueda == 'todos',
//                       selectedColor: Colors.blue,
//                       onSelected: (selected) {
//                         if (selected) {
//                           setState(() {
//                             _modoBusqueda = 'todos';
//                             _vacunasFiltradas = _usandoBackend ? _vacunasBackend : _vacunasFiltradas;
//                             _mostrarResultados = false;
//                           });
//                         }
//                       },
//                       padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
//                     ),
//                   ),
//                   SizedBox(width: 6),
//                   Expanded(
//                     child: ChoiceChip(
//                       label: Row(
//                         mainAxisAlignment: MainAxisAlignment.center,
//                         children: [
//                           Icon(Icons.search, size: 16),
//                           SizedBox(width: 6),
//                           Flexible(
//                             child: Text(
//                               'Por Cédula',
//                               style: TextStyle(fontSize: 12),
//                               overflow: TextOverflow.ellipsis,
//                             ),
//                           ),
//                         ],
//                       ),
//                       selected: _modoBusqueda == 'cedula',
//                       selectedColor: Colors.green,
//                       onSelected: (selected) {
//                         if (selected) {
//                           setState(() {
//                             _modoBusqueda = 'cedula';
//                           });
//                         }
//                       },
//                       padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
          
//           if (_modoBusqueda == 'cedula')
//             Card(
//               margin: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//               child: Padding(
//                 padding: EdgeInsets.all(12),
//                 child: Row(
//                   children: [
//                     Expanded(
//                       child: TextField(
//                         controller: _cedulaController,
//                         decoration: InputDecoration(
//                           hintText: 'Ingresa cédula',
//                           border: OutlineInputBorder(),
//                           prefixIcon: Icon(Icons.search, size: 20),
//                           labelText: 'Buscar',
//                           contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
//                         ),
//                         keyboardType: TextInputType.number,
//                         onSubmitted: (_) => _buscarPorCedula(),
//                         style: TextStyle(fontSize: 14),
//                       ),
//                     ),
//                     SizedBox(width: 8),
//                     SizedBox(
//                       height: 48,
//                       child: ElevatedButton(
//                         onPressed: _buscarPorCedula,
//                         child: Text('Buscar', style: TextStyle(fontSize: 14)),
//                       ),
//                     ),
//                     if (_mostrarResultados)
//                       SizedBox(width: 8),
//                     if (_mostrarResultados)
//                       SizedBox(
//                         height: 48,
//                         child: IconButton(
//                           icon: Icon(Icons.clear, size: 20),
//                           onPressed: _limpiarBusqueda,
//                           tooltip: 'Limpiar búsqueda',
//                         ),
//                       ),
//                   ],
//                 ),
//               ),
//             ),
          
//           Padding(
//             padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       _modoBusqueda == 'todos' 
//                           ? (_usandoBackend ? 'Registros del Servidor' : 'Todos los Registros')
//                           : 'Resultados',
//                       style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
//                     ),
//                     if (_usandoBackend)
//                       Text(
//                         'Datos en tiempo real',
//                         style: TextStyle(fontSize: 11, color: Colors.green[700]),
//                       ),
//                   ],
//                 ),
//                 if (tieneResultados)
//                   Chip(
//                     label: Text(
//                       '${pacientes.length}',
//                       style: TextStyle(color: Colors.white, fontSize: 11),
//                     ),
//                     backgroundColor: Colors.blue,
//                     padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
//                   ),
//               ],
//             ),
//           ),
          
//           if (_isLoading)
//             Expanded(
//               child: Center(
//                 child: Column(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     CircularProgressIndicator(),
//                     SizedBox(height: 12),
//                     Text(
//                       _usandoBackend ? 'Conectando con el servidor...' : 'Cargando registros...',
//                       style: TextStyle(fontSize: 14),
//                     ),
//                   ],
//                 ),
//               ),
//             )
//           else if (tieneResultados)
//             Expanded(
//               child: ListView(
//                 padding: EdgeInsets.symmetric(horizontal: 12),
//                 children: [
//                   ...pacientes.map((paciente) => _buildPacienteCard(paciente)).toList(),
//                   SizedBox(height: 16),
//                 ],
//               ),
//             )
//           else if (_modoBusqueda == 'cedula' && _mostrarResultados)
//             Expanded(
//               child: Center(
//                 child: Column(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     Icon(Icons.search_off, size: 56, color: Colors.grey[300]),
//                     SizedBox(height: 12),
//                     Text(
//                       'No se encontraron registros',
//                       style: TextStyle(fontSize: 15, color: Colors.grey[500]),
//                     ),
//                     SizedBox(height: 6),
//                     Text(
//                       'Intenta con otra cédula',
//                       style: TextStyle(fontSize: 13, color: Colors.grey[400]),
//                     ),
//                   ],
//                 ),
//               ),
//             )
//           else if (_modoBusqueda == 'todos' && _vacunasFiltradas.isEmpty && _conexionExitosa)
//             Expanded(
//               child: Center(
//                 child: Column(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     Icon(Icons.medical_services_outlined, size: 56, color: Colors.grey[300]),
//                     SizedBox(height: 12),
//                     Text(
//                       _usandoBackend 
//                           ? 'No hay registros de vacunas en el servidor'
//                           : 'No hay registros de vacunas',
//                       style: TextStyle(fontSize: 15, color: Colors.grey[500]),
//                     ),
//                     SizedBox(height: 6),
//                     Text(
//                       'Registra tu primera vacuna',
//                       style: TextStyle(fontSize: 13, color: Colors.grey[400]),
//                     ),
//                   ],
//                 ),
//               ),
//             )
//           else if (!_conexionExitosa && _usandoBackend)
//             Expanded(
//               child: Center(
//                 child: Column(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     Icon(Icons.wifi_off, size: 64, color: Colors.grey[400]),
//                     SizedBox(height: 16),
//                     Text(
//                       'Error de conexión',
//                       style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[600]),
//                     ),
//                     SizedBox(height: 8),
//                     Padding(
//                       padding: EdgeInsets.symmetric(horizontal: 32),
//                       child: Text(
//                         _errorMessage ?? 'No se puede conectar al servidor. Verifica tu conexión a internet.',
//                         textAlign: TextAlign.center,
//                         style: TextStyle(fontSize: 14, color: Colors.grey[500]),
//                       ),
//                     ),
//                     SizedBox(height: 24),
//                     ElevatedButton.icon(
//                       onPressed: _cargarDatos,
//                       icon: Icon(Icons.refresh),
//                       label: Text('Reintentar conexión'),
//                     ),
//                   ],
//                 ),
//               ),
//             )
//           else
//             Expanded(
//               child: Center(
//                 child: Column(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     Icon(
//                       _usandoBackend ? Icons.cloud_download : Icons.search,
//                       size: 56,
//                       color: Colors.grey[300],
//                     ),
//                     SizedBox(height: 12),
//                     Text(
//                       _modoBusqueda == 'todos' 
//                           ? (_usandoBackend ? 'Registros del Servidor' : 'Todos los Registros')
//                           : 'Buscar por Cédula',
//                       style: TextStyle(
//                         fontSize: 16,
//                         fontWeight: FontWeight.bold,
//                         color: Colors.grey[500],
//                       ),
//                     ),
//                     SizedBox(height: 8),
//                     Padding(
//                       padding: EdgeInsets.symmetric(horizontal: 24),
//                       child: Text(
//                         _modoBusqueda == 'todos'
//                             ? (_usandoBackend
//                                 ? 'Se mostrarán todos los pacientes registrados en el servidor.'
//                                 : 'Se mostrarán todos los pacientes registrados localmente.')
//                             : 'Ingresa una cédula para buscar pacientes.',
//                         textAlign: TextAlign.center,
//                         style: TextStyle(
//                           fontSize: 13,
//                           color: Colors.grey[400],
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//         ],
//       ),
//     );
//   }

//   @override
//   void dispose() {
//     _cedulaController.dispose();
//     super.dispose();
//   }
// }

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
  List<Vacuna> _todasVacunas = [];
  List<Vacuna> _vacunasFiltradas = [];
  bool _isLoading = false;
  bool _mostrarResultados = false;
  bool _modoTodosRegistros = false;
  String _modoBusqueda = 'todos';

  @override
  void initState() {
    super.initState();
    _cargarTodosRegistros();
  }

  Future<void> _cargarTodosRegistros() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final vacunaService = Provider.of<VacunaService>(context, listen: false);
      final todas = await vacunaService.getVacunas();
      
      setState(() {
        _todasVacunas = todas;
        _vacunasFiltradas = todas;
        _isLoading = false;
        _modoTodosRegistros = true;
        _modoBusqueda = 'todos';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('Error cargando todos los registros: $e');
    }
  }

  Future<void> _buscarPorCedula() async {
    final query = _cedulaController.text.trim();

    if (query.isEmpty) {
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
      _modoTodosRegistros = false;
      _modoBusqueda = 'cedula';
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
      _vacunasFiltradas = _todasVacunas;
      _mostrarResultados = false;
      _modoTodosRegistros = true;
      _modoBusqueda = 'todos';
    });
  }

  List<Map<String, dynamic>> _agruparPorPaciente() {
    final Map<String, Map<String, dynamic>> pacientes = {};
    
    for (final vacuna in _vacunasFiltradas) {
      // ✅ VERIFICACIÓN DE SEGURIDAD - EVITAR CRASH POR DATOS NULL
      if (vacuna.nombrePaciente == null || vacuna.cedulaPaciente == null) {
        print('⚠️ Vacuna con datos nulos omitida: ${vacuna.id}');
        continue;
      }
      
      final key = vacuna.pacienteIdUnico;
      
      if (!pacientes.containsKey(key)) {
        pacientes[key] = {
          'nombre': vacuna.nombrePaciente!,
          'cedula': vacuna.cedulaPaciente!,
          'esMenor': vacuna.esMenor,
          'cedulaTutor': vacuna.cedulaTutor,
          'cedulaPropia': vacuna.cedulaPropia,
          'vacunas': <Vacuna>[],
          'totalVacunas': 0,
          'ultimaFecha': '',
          'tieneAtrasadas': false,
          'tipo': vacuna.esMenor ? 'niño 👶' : 'adulto 👤',
        };
      }
      
      pacientes[key]!['vacunas'].add(vacuna);
      pacientes[key]!['totalVacunas']++;
      
      final fechaActual = vacuna.fechaAplicacion;
      final ultimaFecha = pacientes[key]!['ultimaFecha'] as String;
      if (ultimaFecha.isEmpty || fechaActual.compareTo(ultimaFecha) > 0) {
        pacientes[key]!['ultimaFecha'] = fechaActual;
      }
      
      if (vacuna.proximaDosisPasada) {
        pacientes[key]!['tieneAtrasadas'] = true;
      }
    }
    
    final listaPacientes = pacientes.values.toList();
    listaPacientes.sort((a, b) {
      return (a['nombre'] as String).compareTo(b['nombre'] as String);
    });
    
    return listaPacientes;
  }

  Widget _buildPacienteCard(Map<String, dynamic> paciente) {
    final nombre = paciente['nombre'] as String;
    final cedula = paciente['cedula'] as String;
    final esMenor = paciente['esMenor'] as bool;
    final totalVacunas = paciente['totalVacunas'] as int;
    final tieneAtrasadas = paciente['tieneAtrasadas'] as bool;
    final tipo = paciente['tipo'] as String;
    final vacunas = paciente['vacunas'] as List<Vacuna>;
    
    // ✅ ACORTAR TEXTO PARA EVITAR OVERFLOW
    final String nombreMostrar = nombre.length > 20 
        ? '${nombre.substring(0, 20)}...' 
        : nombre;
    
    return Card(
      margin: EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: esMenor ? Colors.blue : Colors.green,
          child: Icon(
            esMenor ? Icons.child_care : Icons.person,
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          nombreMostrar,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cédula: $cedula', style: TextStyle(fontSize: 13)),
            SizedBox(height: 6),
            // ✅ USAR Wrap EN LUGAR DE Row PARA EVITAR OVERFLOW
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                Chip(
                  label: Text(
                    tipo,
                    style: TextStyle(color: Colors.white, fontSize: 9),
                  ),
                  backgroundColor: esMenor ? Colors.blue : Colors.green,
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                ),
                Chip(
                  label: Text(
                    '$totalVacunas ${totalVacunas > 1 ? 'vacunas' : 'vacuna'}',
                    style: TextStyle(fontSize: 9),
                  ),
                  backgroundColor: Colors.grey[200],
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                ),
                if (tieneAtrasadas)
                  Chip(
                    label: Text(
                      'ATRASADA',
                      style: TextStyle(color: Colors.white, fontSize: 8),
                    ),
                    backgroundColor: Colors.red,
                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  ),
              ],
            ),
            if (esMenor && paciente['cedulaTutor'] != null)
              Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'Tutor: ${paciente['cedulaTutor']}',
                  style: TextStyle(fontSize: 11, color: Colors.blue[700]),
                ),
              ),
          ],
        ),
        trailing: Icon(Icons.arrow_forward_ios, size: 14),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PacienteDetalleScreen(
                cedula: cedula,
                nombre: nombre,
                esGrupoFamiliar: false,
                vacunas: vacunas,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGrupoFamiliar(String cedula, List<Map<String, dynamic>> pacientesDeEstaCedula) {
    final adultos = pacientesDeEstaCedula.where((p) => !p['esMenor']).toList();
    final ninos = pacientesDeEstaCedula.where((p) => p['esMenor']).toList();
    final esGrupoFamiliar = adultos.isNotEmpty && ninos.isNotEmpty;
    
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      color: esGrupoFamiliar ? Colors.orange[50] : Colors.grey[50],
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: esGrupoFamiliar ? Colors.orange : Colors.blue,
          child: Icon(
            esGrupoFamiliar ? Icons.family_restroom : Icons.people,
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          esGrupoFamiliar ? 'Grupo Familiar' : 'Pacientes',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Text(
          'Cédula: $cedula • ${pacientesDeEstaCedula.length} paciente${pacientesDeEstaCedula.length > 1 ? 's' : ''}',
          style: TextStyle(fontSize: 12),
        ),
        children: [
          if (adultos.isNotEmpty)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.person, size: 16, color: Colors.green),
                      SizedBox(width: 8),
                      Text(
                        'Adulto${adultos.length > 1 ? 's' : ''}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  ...adultos.map((paciente) => _buildPacienteCard(paciente)).toList(),
                ],
              ),
            ),
          
          if (ninos.isNotEmpty)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.child_care, size: 16, color: Colors.blue),
                      SizedBox(width: 8),
                      Text(
                        'Niño${ninos.length > 1 ? 's' : ''}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[700],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  ...ninos.map((paciente) => _buildPacienteCard(paciente)).toList(),
                ],
              ),
            ),
          
          Padding(
            padding: EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final todasVacunas = <Vacuna>[];
                  for (final paciente in pacientesDeEstaCedula) {
                    todasVacunas.addAll(paciente['vacunas'] as List<Vacuna>);
                  }
                  
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PacienteDetalleScreen(
                        cedula: cedula,
                        nombre: esGrupoFamiliar ? 'Grupo Familiar' : 'Pacientes',
                        esGrupoFamiliar: esGrupoFamiliar,
                        vacunas: todasVacunas,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: esGrupoFamiliar ? Colors.orange : Colors.blue,
                  padding: EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text(
                  'Ver Todos los Registros de Esta Cédula',
                  style: TextStyle(fontSize: 14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pacientes = _agruparPorPaciente();
    
    final Map<String, List<Map<String, dynamic>>> gruposPorCedula = {};
    for (final paciente in pacientes) {
      final cedula = paciente['cedula'] as String;
      if (!gruposPorCedula.containsKey(cedula)) {
        gruposPorCedula[cedula] = [];
      }
      gruposPorCedula[cedula]!.add(paciente);
    }
    
    final tieneResultados = pacientes.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'HealthShield',
          style: TextStyle(
            fontSize: 18, // ✅ Tamaño reducido
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, size: 20), // ✅ Tamaño reducido
            onPressed: _cargarTodosRegistros,
            tooltip: 'Actualizar lista',
          ),
        ],
      ),
      body: Column(
        children: [
          Card(
            margin: EdgeInsets.all(12), // ✅ Margen reducido
            child: Padding(
              padding: EdgeInsets.all(8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.list, size: 16), // ✅ Tamaño reducido
                          SizedBox(width: 6), // ✅ Espacio reducido
                          Flexible(
                            child: Text(
                              'Todos',
                              style: TextStyle(fontSize: 12), // ✅ Tamaño reducido
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      selected: _modoBusqueda == 'todos',
                      selectedColor: Colors.blue,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _modoBusqueda = 'todos';
                            _vacunasFiltradas = _todasVacunas;
                            _modoTodosRegistros = true;
                            _mostrarResultados = false;
                          });
                        }
                      },
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6), // ✅ Padding reducido
                    ),
                  ),
                  SizedBox(width: 6), // ✅ Espacio reducido
                  Expanded(
                    child: ChoiceChip(
                      label: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search, size: 16), // ✅ Tamaño reducido
                          SizedBox(width: 6), // ✅ Espacio reducido
                          Flexible(
                            child: Text(
                              'Por Cédula',
                              style: TextStyle(fontSize: 12), // ✅ Tamaño reducido
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      selected: _modoBusqueda == 'cedula',
                      selectedColor: Colors.green,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _modoBusqueda = 'cedula';
                            _modoTodosRegistros = false;
                          });
                        }
                      },
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6), // ✅ Padding reducido
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          if (_modoBusqueda == 'cedula')
            Card(
              margin: EdgeInsets.symmetric(horizontal: 12, vertical: 8), // ✅ Margen reducido
              child: Padding(
                padding: EdgeInsets.all(12), // ✅ Padding reducido
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _cedulaController,
                        decoration: InputDecoration(
                          hintText: 'Ingresa cédula',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.search, size: 20), // ✅ Tamaño reducido
                          labelText: 'Buscar',
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12), // ✅ Padding reducido
                        ),
                        keyboardType: TextInputType.number,
                        onSubmitted: (_) => _buscarPorCedula(),
                        style: TextStyle(fontSize: 14), // ✅ Tamaño reducido
                      ),
                    ),
                    SizedBox(width: 8),
                    SizedBox(
                      height: 48, // ✅ Altura fija
                      child: ElevatedButton(
                        onPressed: _buscarPorCedula,
                        child: Text('Buscar', style: TextStyle(fontSize: 14)), // ✅ Tamaño reducido
                      ),
                    ),
                    if (_mostrarResultados)
                      SizedBox(width: 8),
                    if (_mostrarResultados)
                      SizedBox(
                        height: 48,
                        child: IconButton(
                          icon: Icon(Icons.clear, size: 20), // ✅ Tamaño reducido
                          onPressed: _limpiarBusqueda,
                          tooltip: 'Limpiar búsqueda',
                        ),
                      ),
                  ],
                ),
              ),
            ),
          
          Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 8), // ✅ Padding reducido
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _modoBusqueda == 'todos' 
                      ? 'Todos los Registros' 
                      : 'Resultados',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold), // ✅ Tamaño reducido
                ),
                if (tieneResultados)
                  Chip(
                    label: Text(
                      '${pacientes.length}',
                      style: TextStyle(color: Colors.white, fontSize: 11), // ✅ Tamaño reducido
                    ),
                    backgroundColor: Colors.blue,
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2), // ✅ Padding reducido
                  ),
              ],
            ),
          ),
          
          if (_isLoading)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 12), // ✅ Espacio reducido
                    Text('Cargando registros...', style: TextStyle(fontSize: 14)), // ✅ Tamaño reducido
                  ],
                ),
              ),
            )
          else if (tieneResultados)
            Expanded(
              child: ListView(
                padding: EdgeInsets.symmetric(horizontal: 12), // ✅ Padding reducido
                children: [
                  if (_modoBusqueda == 'cedula')
                    ...gruposPorCedula.entries.map((entry) {
                      return _buildGrupoFamiliar(entry.key, entry.value);
                    }).toList()
                  else
                    ...pacientes.map((paciente) => _buildPacienteCard(paciente)).toList(),
                  
                  SizedBox(height: 16),
                ],
              ),
            )
          else if (_modoBusqueda == 'cedula' && _mostrarResultados)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.search_off, size: 56, color: Colors.grey[300]), // ✅ Tamaño reducido
                    SizedBox(height: 12), // ✅ Espacio reducido
                    Text(
                      'No se encontraron registros',
                      style: TextStyle(fontSize: 15, color: Colors.grey[500]), // ✅ Tamaño reducido
                    ),
                    SizedBox(height: 6), // ✅ Espacio reducido
                    Text(
                      'Intenta con otra cédula',
                      style: TextStyle(fontSize: 13, color: Colors.grey[400]), // ✅ Tamaño reducido
                    ),
                  ],
                ),
              ),
            )
          else if (_modoBusqueda == 'todos' && _todasVacunas.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.medical_services_outlined, size: 56, color: Colors.grey[300]), // ✅ Tamaño reducido
                    SizedBox(height: 12), // ✅ Espacio reducido
                    Text(
                      'No hay registros de vacunas',
                      style: TextStyle(fontSize: 15, color: Colors.grey[500]), // ✅ Tamaño reducido
                    ),
                    SizedBox(height: 6), // ✅ Espacio reducido
                    Text(
                      'Registra tu primera vacuna',
                      style: TextStyle(fontSize: 13, color: Colors.grey[400]), // ✅ Tamaño reducido
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.search, size: 56, color: Colors.grey[300]), // ✅ Tamaño reducido
                    SizedBox(height: 12), // ✅ Espacio reducido
                    Text(
                      _modoBusqueda == 'todos' 
                          ? 'Todos los Registros' 
                          : 'Buscar por Cédula',
                      style: TextStyle(
                        fontSize: 16, // ✅ Tamaño reducido
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[500],
                      ),
                    ),
                    SizedBox(height: 8), // ✅ Espacio reducido
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24), // ✅ Padding reducido
                      child: Text(
                        _modoBusqueda == 'todos'
                            ? 'Se mostrarán todos los pacientes registrados.'
                            : 'Ingresa una cédula para buscar pacientes.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13, // ✅ Tamaño reducido
                          color: Colors.grey[400],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _cedulaController.dispose();
    super.dispose();
  }
}