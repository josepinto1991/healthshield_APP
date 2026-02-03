// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../models/vacuna.dart';
// import '../services/vacuna_service.dart';

// class PacienteDetalleScreen extends StatefulWidget {
//   final String cedula;
//   final String nombre;

//   PacienteDetalleScreen({required this.cedula, required this.nombre});

//   @override
//   _PacienteDetalleScreenState createState() => _PacienteDetalleScreenState();
// }

// class _PacienteDetalleScreenState extends State<PacienteDetalleScreen> {
//   List<Vacuna> _vacunas = [];
//   bool _isLoading = true;

//   @override
//   void initState() {
//     super.initState();
//     _cargarVacunas();
//   }

//   Future<void> _cargarVacunas() async {
//     try {
//       final vacunaService = Provider.of<VacunaService>(context, listen: false);
//       final vacunas = await vacunaService.buscarPorCedula(widget.cedula);
      
//       setState(() {
//         _vacunas = vacunas;
//         _isLoading = false;
//       });
//     } catch (e) {
//       print('Error cargando vacunas: $e');
//       setState(() {
//         _isLoading = false;
//       });
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text(
//           'HealthShield',
//           style: TextStyle(
//             fontSize: 20,
//             fontWeight: FontWeight.bold,
//             color: Colors.blue,
//           ),
//         ),
//         leading: IconButton(
//           icon: Icon(Icons.arrow_back),
//           onPressed: () => Navigator.pop(context),
//         ),
//       ),
//       body: _isLoading
//           ? Center(child: CircularProgressIndicator())
//           : SingleChildScrollView(
//               padding: EdgeInsets.all(16),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   // Información del paciente
//                   Card(
//                     elevation: 3,
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(12),
//                     ),
//                     child: Padding(
//                       padding: EdgeInsets.all(16),
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           Row(
//                             children: [
//                               CircleAvatar(
//                                 backgroundColor: Colors.blue[50],
//                                 child: Icon(Icons.person, color: Colors.blue),
//                               ),
//                               SizedBox(width: 16),
//                               Expanded(
//                                 child: Column(
//                                   crossAxisAlignment: CrossAxisAlignment.start,
//                                   children: [
//                                     Text(
//                                       widget.nombre,
//                                       style: TextStyle(
//                                         fontSize: 20,
//                                         fontWeight: FontWeight.bold,
//                                       ),
//                                     ),
//                                     SizedBox(height: 4),
//                                     Text(
//                                       'Cédula: ${widget.cedula}',
//                                       style: TextStyle(
//                                         fontSize: 14,
//                                         color: Colors.grey[600],
//                                       ),
//                                     ),
//                                   ],
//                                 ),
//                               ),
//                             ],
//                           ),
//                           Divider(height: 24),
//                           Row(
//                             mainAxisAlignment: MainAxisAlignment.spaceAround,
//                             children: [
//                               _buildStatItem(
//                                 '${_vacunas.length}',
//                                 'Vacunas',
//                                 Icons.medical_services,
//                                 Colors.blue,
//                               ),
//                               _buildStatItem(
//                                 _vacunas.isNotEmpty 
//                                     ? _vacunas.first.fechaAplicacionFormateada 
//                                     : 'N/A',
//                                 'Última',
//                                 Icons.calendar_today,
//                                 Colors.green,
//                               ),
//                               _buildStatItem(
//                                 _vacunas.any((v) => v.proximaDosisPasada) 
//                                     ? 'SI' : 'NO',
//                                 'Pendientes',
//                                 Icons.warning,
//                                 Colors.orange,
//                               ),
//                             ],
//                           ),
//                         ],
//                       ),
//                     ),
//                   ),
                  
//                   SizedBox(height: 24),
                  
//                   // Lista de vacunas
//                   Row(
//                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                     children: [
//                       Text(
//                         'Historial de Vacunación',
//                         style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//                       ),
//                       Chip(
//                         label: Text('${_vacunas.length} registros'),
//                         backgroundColor: Colors.blue[50],
//                       ),
//                     ],
//                   ),
//                   SizedBox(height: 12),
                  
//                   if (_vacunas.isEmpty)
//                     Card(
//                       child: Padding(
//                         padding: EdgeInsets.all(32),
//                         child: Column(
//                           children: [
//                             Icon(Icons.medical_services_outlined, 
//                                  size: 64, color: Colors.grey[300]),
//                             SizedBox(height: 16),
//                             Text(
//                               'No hay vacunas registradas',
//                               style: TextStyle(
//                                 fontSize: 16,
//                                 color: Colors.grey[500],
//                               ),
//                             ),
//                             SizedBox(height: 8),
//                             Text(
//                               'Este paciente no tiene registros de vacunación',
//                               style: TextStyle(
//                                 fontSize: 12,
//                                 color: Colors.grey[400],
//                               ),
//                               textAlign: TextAlign.center,
//                             ),
//                           ],
//                         ),
//                       ),
//                     )
//                   else
//                     ListView.builder(
//                       shrinkWrap: true,
//                       physics: NeverScrollableScrollPhysics(),
//                       itemCount: _vacunas.length,
//                       itemBuilder: (context, index) {
//                         final vacuna = _vacunas[index];
//                         final bool isOverdue = vacuna.proximaDosisPasada;
                        
//                         return Card(
//                           margin: EdgeInsets.only(bottom: 8),
//                           color: isOverdue ? Colors.red[50] : null,
//                           child: ExpansionTile(
//                             leading: CircleAvatar(
//                               backgroundColor: isOverdue 
//                                   ? Colors.red[100] 
//                                   : Colors.blue[50],
//                               child: Icon(
//                                 Icons.vaccines,
//                                 color: isOverdue ? Colors.red : Colors.blue,
//                               ),
//                             ),
//                             title: Text(
//                               vacuna.nombreVacuna,
//                               style: TextStyle(
//                                 fontWeight: FontWeight.bold,
//                                 color: isOverdue ? Colors.red[700] : null,
//                               ),
//                             ),
//                             subtitle: Text(
//                               'Aplicada: ${vacuna.fechaAplicacionFormateada}',
//                               style: TextStyle(
//                                 color: isOverdue ? Colors.red[600] : null,
//                               ),
//                             ),
//                             trailing: isOverdue
//                                 ? Chip(
//                                     label: Text(
//                                       'ATRASADA',
//                                       style: TextStyle(
//                                         color: Colors.white,
//                                         fontSize: 10,
//                                         fontWeight: FontWeight.bold,
//                                       ),
//                                     ),
//                                     backgroundColor: Colors.red,
//                                   )
//                                 : Chip(
//                                     label: Text(
//                                       vacuna.proximaDosis != null 
//                                           ? 'PROGRAMADA' 
//                                           : 'COMPLETA',
//                                       style: TextStyle(
//                                         color: Colors.white,
//                                         fontSize: 10,
//                                         fontWeight: FontWeight.bold,
//                                       ),
//                                     ),
//                                     backgroundColor: vacuna.proximaDosis != null 
//                                         ? Colors.orange 
//                                         : Colors.green,
//                                   ),
//                             children: [
//                               Padding(
//                                 padding: EdgeInsets.symmetric(
//                                   horizontal: 16,
//                                   vertical: 8,
//                                 ),
//                                 child: Column(
//                                   crossAxisAlignment: CrossAxisAlignment.start,
//                                   children: [
//                                     if (vacuna.lote != null && vacuna.lote!.isNotEmpty)
//                                       _buildDetailRow('Lote:', vacuna.lote!),
//                                     if (vacuna.proximaDosis != null)
//                                       _buildDetailRow(
//                                         'Próxima dosis:', 
//                                         vacuna.proximaDosisFormateada!,
//                                         isImportant: isOverdue,
//                                       ),
//                                     _buildDetailRow(
//                                       'Registrado:', 
//                                       vacuna.createdAt != null
//                                           ? '${vacuna.createdAt!.day}/${vacuna.createdAt!.month}/${vacuna.createdAt!.year}'
//                                           : 'N/A'
//                                     ),
//                                     Divider(height: 16),
//                                     if (isOverdue)
//                                       Container(
//                                         padding: EdgeInsets.all(8),
//                                         decoration: BoxDecoration(
//                                           color: Colors.red[100],
//                                           borderRadius: BorderRadius.circular(8),
//                                         ),
//                                         child: Row(
//                                           children: [
//                                             Icon(Icons.warning, 
//                                                  size: 16, color: Colors.red),
//                                             SizedBox(width: 8),
//                                             Expanded(
//                                               child: Text(
//                                                 'Esta vacuna está atrasada. Por favor programe la próxima dosis.',
//                                                 style: TextStyle(
//                                                   fontSize: 12,
//                                                   color: Colors.red[700],
//                                                 ),
//                                               ),
//                                             ),
//                                           ],
//                                         ),
//                                       ),
//                                   ],
//                                 ),
//                               ),
//                             ],
//                           ),
//                         );
//                       },
//                     ),
                  
//                   SizedBox(height: 24),
                  
//                   // Resumen
//                   if (_vacunas.isNotEmpty)
//                     Card(
//                       color: Colors.grey[50],
//                       child: Padding(
//                         padding: EdgeInsets.all(16),
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Text(
//                               'Resumen del Paciente',
//                               style: TextStyle(
//                                 fontWeight: FontWeight.bold,
//                                 color: Colors.blue,
//                               ),
//                             ),
//                             SizedBox(height: 8),
//                             ListTile(
//                               dense: true,
//                               leading: Icon(Icons.medical_services, size: 20),
//                               title: Text('Total de vacunas registradas'),
//                               trailing: Text('${_vacunas.length}'),
//                             ),
//                             ListTile(
//                               dense: true,
//                               leading: Icon(Icons.calendar_today, size: 20),
//                               title: Text('Última vacuna aplicada'),
//                               trailing: Text(
//                                 _vacunas.isNotEmpty 
//                                     ? _vacunas.first.fechaAplicacionFormateada 
//                                     : 'N/A'
//                               ),
//                             ),
//                             ListTile(
//                               dense: true,
//                               leading: Icon(Icons.warning, size: 20),
//                               title: Text('Vacunas atrasadas'),
//                               trailing: Text(
//                                 '${_vacunas.where((v) => v.proximaDosisPasada).length}'
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                     ),
//                 ],
//               ),
//             ),
//     );
//   }

//   Widget _buildStatItem(String value, String title, IconData icon, Color color) {
//     return Column(
//       children: [
//         Container(
//           padding: EdgeInsets.all(8),
//           decoration: BoxDecoration(
//             color: color.withOpacity(0.1),
//             shape: BoxShape.circle,
//           ),
//           child: Icon(icon, color: color, size: 24),
//         ),
//         SizedBox(height: 8),
//         Text(
//           value,
//           style: TextStyle(
//             fontSize: 16,
//             fontWeight: FontWeight.bold,
//             color: color,
//           ),
//         ),
//         SizedBox(height: 4),
//         Text(
//           title,
//           style: TextStyle(
//             fontSize: 12,
//             color: Colors.grey[600],
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _buildDetailRow(String label, String value, {bool isImportant = false}) {
//     return Padding(
//       padding: EdgeInsets.symmetric(vertical: 4),
//       child: Row(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           SizedBox(
//             width: 100,
//             child: Text(
//               label,
//               style: TextStyle(
//                 fontWeight: FontWeight.bold,
//                 color: isImportant ? Colors.red[700] : Colors.grey[700],
//               ),
//             ),
//           ),
//           SizedBox(width: 8),
//           Expanded(
//             child: Text(
//               value,
//               style: TextStyle(
//                 color: isImportant ? Colors.red[600] : Colors.grey[600],
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/vacuna.dart';
import '../services/vacuna_service.dart';

class PacienteDetalleScreen extends StatefulWidget {
  final String cedula;
  final String nombre;

  PacienteDetalleScreen({required this.cedula, required this.nombre});

  @override
  _PacienteDetalleScreenState createState() => _PacienteDetalleScreenState();
}

class _PacienteDetalleScreenState extends State<PacienteDetalleScreen> {
  List<Vacuna> _vacunas = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarVacunas();
  }

  Future<void> _cargarVacunas() async {
    try {
      final vacunaService = Provider.of<VacunaService>(context, listen: false);
      final vacunas = await vacunaService.buscarPorCedula(widget.cedula);
      
      setState(() {
        _vacunas = vacunas;
        _isLoading = false;
      });
    } catch (e) {
      print('Error cargando vacunas: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Información del paciente
                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: Colors.blue[50],
                                child: Icon(Icons.person, color: Colors.blue),
                              ),
                              SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.nombre,
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Cédula: ${widget.cedula}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          Divider(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildStatItem(
                                '${_vacunas.length}',
                                'Vacunas',
                                Icons.medical_services,
                                Colors.blue,
                              ),
                              _buildStatItem(
                                _vacunas.isNotEmpty 
                                    ? _vacunas.first.fechaAplicacionFormateada 
                                    : 'N/A',
                                'Última',
                                Icons.calendar_today,
                                Colors.green,
                              ),
                              _buildStatItem(
                                _vacunas.any((v) => v.proximaDosisPasada) 
                                    ? 'SI' : 'NO',
                                'Pendientes',
                                Icons.warning,
                                Colors.orange,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  SizedBox(height: 24),
                  
                  // Lista de vacunas
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Historial de Vacunación',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Chip(
                        label: Text('${_vacunas.length} registros'),
                        backgroundColor: Colors.blue[50],
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  
                  if (_vacunas.isEmpty)
                    Card(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Icon(Icons.medical_services_outlined, 
                                 size: 64, color: Colors.grey[300]),
                            SizedBox(height: 16),
                            Text(
                              'No hay vacunas registradas',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[500],
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Este paciente no tiene registros de vacunación',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[400],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      itemCount: _vacunas.length,
                      itemBuilder: (context, index) {
                        final vacuna = _vacunas[index];
                        final bool isOverdue = vacuna.proximaDosisPasada;
                        
                        return Card(
                          margin: EdgeInsets.only(bottom: 8),
                          color: isOverdue ? Colors.red[50] : null,
                          child: ExpansionTile(
                            leading: CircleAvatar(
                              backgroundColor: isOverdue 
                                  ? Colors.red[100] 
                                  : Colors.blue[50],
                              child: Icon(
                                Icons.vaccines,
                                color: isOverdue ? Colors.red : Colors.blue,
                              ),
                            ),
                            title: Text(
                              vacuna.nombreVacuna,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isOverdue ? Colors.red[700] : null,
                              ),
                            ),
                            subtitle: Text(
                              'Aplicada: ${vacuna.fechaAplicacionFormateada}',
                              style: TextStyle(
                                color: isOverdue ? Colors.red[600] : null,
                              ),
                            ),
                            trailing: isOverdue
                                ? Chip(
                                    label: Text(
                                      'ATRASADA',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    backgroundColor: Colors.red,
                                  )
                                : Chip(
                                    label: Text(
                                      vacuna.proximaDosis != null 
                                          ? 'PROGRAMADA' 
                                          : 'COMPLETA',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    backgroundColor: vacuna.proximaDosis != null 
                                        ? Colors.orange 
                                        : Colors.green,
                                  ),
                            children: [
                              Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (vacuna.lote != null && vacuna.lote!.isNotEmpty)
                                      _buildDetailRow('Lote:', vacuna.lote!),
                                    if (vacuna.proximaDosis != null)
                                      _buildDetailRow(
                                        'Próxima dosis:', 
                                        vacuna.proximaDosisFormateada!,
                                        isImportant: isOverdue,
                                      ),
                                    _buildDetailRow(
                                      'Registrado:', 
                                      vacuna.createdAt != null
                                          ? '${vacuna.createdAt!.day}/${vacuna.createdAt!.month}/${vacuna.createdAt!.year}'
                                          : 'N/A'
                                    ),
                                    Divider(height: 16),
                                    if (isOverdue)
                                      Container(
                                        padding: EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.red[100],
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(Icons.warning, 
                                                 size: 16, color: Colors.red),
                                            SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                'Esta vacuna está atrasada. Por favor programe la próxima dosis.',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.red[700],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  
                  SizedBox(height: 24),
                  
                  // Resumen
                  if (_vacunas.isNotEmpty)
                    Card(
                      color: Colors.grey[50],
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Resumen del Paciente',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                            SizedBox(height: 8),
                            ListTile(
                              dense: true,
                              leading: Icon(Icons.medical_services, size: 20),
                              title: Text('Total de vacunas registradas'),
                              trailing: Text('${_vacunas.length}'),
                            ),
                            ListTile(
                              dense: true,
                              leading: Icon(Icons.calendar_today, size: 20),
                              title: Text('Última vacuna aplicada'),
                              trailing: Text(
                                _vacunas.isNotEmpty 
                                    ? _vacunas.first.fechaAplicacionFormateada 
                                    : 'N/A'
                              ),
                            ),
                            ListTile(
                              dense: true,
                              leading: Icon(Icons.warning, size: 20),
                              title: Text('Vacunas atrasadas'),
                              trailing: Text(
                                '${_vacunas.where((v) => v.proximaDosisPasada).length}'
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

  Widget _buildStatItem(String value, String title, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isImportant = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isImportant ? Colors.red[700] : Colors.grey[700],
              ),
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: isImportant ? Colors.red[600] : Colors.grey[600],
              ),
            ),
          ),
        ],
      ),
    );
  }
}