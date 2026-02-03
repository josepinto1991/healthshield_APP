// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../services/vacuna_service.dart';
// import '../models/vacuna.dart';
// import 'visualizar_registros_screen.dart';

// class RegistroVacunaScreen extends StatefulWidget {
//   @override
//   _RegistroVacunaScreenState createState() => _RegistroVacunaScreenState();
// }

// class _RegistroVacunaScreenState extends State<RegistroVacunaScreen> {
//   final _formKey = GlobalKey<FormState>();
//   final _nombreController = TextEditingController();
//   final _cedulaController = TextEditingController();
//   final _tipoVacunaController = TextEditingController();
//   final _loteController = TextEditingController();
//   final _proximaDosisController = TextEditingController();
  
//   String _tipoPaciente = 'niño';
//   DateTime _fechaVacunacion = DateTime.now();
//   bool _isLoading = false;

//   Future<void> _seleccionarFecha(BuildContext context) async {
//     final DateTime? picked = await showDatePicker(
//       context: context,
//       initialDate: _fechaVacunacion,
//       firstDate: DateTime(2000),
//       lastDate: DateTime(2100),
//     );
//     if (picked != null && picked != _fechaVacunacion) {
//       setState(() {
//         _fechaVacunacion = picked;
//       });
//     }
//   }

//   Future<void> _seleccionarProximaDosis(BuildContext context) async {
//     final DateTime? picked = await showDatePicker(
//       context: context,
//       initialDate: _fechaVacunacion.add(Duration(days: 30)),
//       firstDate: DateTime.now(),
//       lastDate: DateTime(2100),
//     );
//     if (picked != null) {
//       setState(() {
//         _proximaDosisController.text = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
//       });
//     }
//   }

//   Future<void> _guardarRegistro() async {
//     if (_formKey.currentState!.validate()) {
//       setState(() {
//         _isLoading = true;
//       });

//       final vacunaService = Provider.of<VacunaService>(context, listen: false);
      
//       final nuevaVacuna = Vacuna(
//         nombreVacuna: _tipoVacunaController.text, 
//         fechaAplicacion: "${_fechaVacunacion.year}-${_fechaVacunacion.month.toString().padLeft(2, '0')}-${_fechaVacunacion.day.toString().padLeft(2, '0')}",
//         lote: _loteController.text.isEmpty ? null : _loteController.text,
//         proximaDosis: _proximaDosisController.text.isEmpty ? null : _proximaDosisController.text,
//         nombrePaciente: _nombreController.text,
//         cedulaPaciente: _cedulaController.text.isEmpty ? null : _cedulaController.text,
//         createdAt: DateTime.now(),
//       );

//       try {
//         await vacunaService.crearVacuna(nuevaVacuna);
        
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('✅ Registro de vacuna guardado exitosamente'),
//             backgroundColor: Colors.green,
//           ),
//         );
        
//         // Limpiar formulario
//         _formKey.currentState!.reset();
//         setState(() {
//           _tipoPaciente = 'niño';
//           _fechaVacunacion = DateTime.now();
//           _loteController.clear();
//           _proximaDosisController.clear();
//         });
        
//       } catch (e) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('❌ Error al guardar el registro: $e'),
//             backgroundColor: Colors.red,
//           ),
//         );
//       } finally {
//         setState(() {
//           _isLoading = false;
//         });
//       }
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     // 🔥 OBTENER PADDING INFERIOR SEGURO
//     final bottomPadding = MediaQuery.of(context).viewPadding.bottom;
//     final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    
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
//         actions: [
//           IconButton(
//             icon: Icon(Icons.logout),
//             onPressed: () {
//               // TODO: Implementar logout
//             },
//             tooltip: 'Cerrar sesión',
//           ),
//         ],
//       ),
//       body: SingleChildScrollView(
//         // 🔥 PADDING DINÁMICO CON ESPACIO PARA BOTONES DEL DISPOSITIVO
//         padding: EdgeInsets.only(
//           left: 16,
//           right: 16,
//           top: 16,
//           bottom: 16 + bottomPadding + bottomInset,
//         ),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             // Tabs de navegación
//             Row(
//               children: [
//                 Expanded(
//                   child: TextButton(
//                     onPressed: () {
//                       // Ya estamos en realizar registro
//                     },
//                     child: Text(
//                       'Realizar Registro',
//                       style: TextStyle(
//                         fontWeight: FontWeight.bold,
//                         color: Colors.blue,
//                       ),
//                     ),
//                   ),
//                 ),
//                 Expanded(
//                   child: TextButton(
//                     onPressed: () {
//                       Navigator.push(
//                         context,
//                         MaterialPageRoute(builder: (context) => VisualizarRegistrosScreen()),
//                       );
//                     },
//                     child: Text(
//                       'Visualizar Registro',
//                       style: TextStyle(color: Colors.grey),
//                     ),
//                   ),
//                 ),
//               ],
//             ),
            
//             SizedBox(height: 16),
            
//             Text(
//               'Registro de Vacunas',
//               style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
//             ),
            
//             SizedBox(height: 8),
            
//             Text(
//               'En esta vista se realiza el registro de vacunas a pacientes, niños o adulto, en formato de formulario.',
//               style: TextStyle(fontSize: 14, color: Colors.grey[600]),
//             ),
            
//             SizedBox(height: 24),
            
//             Form(
//               key: _formKey,
//               child: Column(
//                 children: [
//                   // Nombre del Paciente
//                   TextFormField(
//                     controller: _nombreController,
//                     decoration: InputDecoration(
//                       labelText: 'Nombre del Paciente',
//                       hintText: 'Ej: Juan Pérez',
//                       border: OutlineInputBorder(),
//                       prefixIcon: Icon(Icons.person),
//                     ),
//                     validator: (value) {
//                       if (value == null || value.isEmpty) {
//                         return 'Por favor ingresa el nombre del paciente';
//                       }
//                       return null;
//                     },
//                   ),
                  
//                   SizedBox(height: 16),
                  
//                   // Cédula 
//                   TextFormField(
//                     controller: _cedulaController,
//                     decoration: InputDecoration(
//                       labelText: 'Cédula de Identidad, En caso de ser un niñ@: colocar la del tutor',
//                       border: OutlineInputBorder(),
//                       prefixIcon: Icon(Icons.badge),
//                     ),
//                     keyboardType: TextInputType.number,
//                   ),
                  
//                   SizedBox(height: 16),
                  
//                   // Tipo de Paciente
//                   DropdownButtonFormField<String>(
//                     value: _tipoPaciente,
//                     decoration: InputDecoration(
//                       labelText: 'Tipo de Paciente',
//                       border: OutlineInputBorder(),
//                       prefixIcon: Icon(Icons.people),
//                     ),
//                     items: [
//                       DropdownMenuItem(value: 'niño', child: Text('Niño')),
//                       DropdownMenuItem(value: 'adulto', child: Text('Adulto')),
//                     ],
//                     onChanged: (value) {
//                       setState(() {
//                         _tipoPaciente = value!;
//                       });
//                     },
//                   ),
                  
//                   SizedBox(height: 16),
                  
//                   // Fecha de Vacunación
//                   InkWell(
//                     onTap: () => _seleccionarFecha(context),
//                     child: InputDecorator(
//                       decoration: InputDecoration(
//                         labelText: 'Fecha de Vacunación',
//                         border: OutlineInputBorder(),
//                         prefixIcon: Icon(Icons.calendar_today),
//                       ),
//                       child: Row(
//                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                         children: [
//                           Text("${_fechaVacunacion.day}/${_fechaVacunacion.month}/${_fechaVacunacion.year}"),
//                           Icon(Icons.arrow_drop_down),
//                         ],
//                       ),
//                     ),
//                   ),
                  
//                   SizedBox(height: 16),
                  
//                   // Tipo de Vacuna
//                   TextFormField(
//                     controller: _tipoVacunaController,
//                     decoration: InputDecoration(
//                       labelText: 'Tipo de Vacuna',
//                       hintText: 'Ej: Triple Viral, BCG, Polio, etc.',
//                       border: OutlineInputBorder(),
//                       prefixIcon: Icon(Icons.medical_services),
//                     ),
//                     validator: (value) {
//                       if (value == null || value.isEmpty) {
//                         return 'Por favor ingresa el tipo de vacuna';
//                       }
//                       return null;
//                     },
//                   ),
                  
//                   SizedBox(height: 16),
                  
//                   // Lote (Opcional)
//                   TextFormField(
//                     controller: _loteController,
//                     decoration: InputDecoration(
//                       labelText: 'Lote (Opcional)',
//                       border: OutlineInputBorder(),
//                       prefixIcon: Icon(Icons.confirmation_number),
//                     ),
//                   ),
                  
//                   SizedBox(height: 16),
                  
//                   // Próxima Dosis (Opcional)
//                   InkWell(
//                     onTap: () => _seleccionarProximaDosis(context),
//                     child: InputDecorator(
//                       decoration: InputDecoration(
//                         labelText: 'Próxima Dosis (Opcional)',
//                         border: OutlineInputBorder(),
//                         prefixIcon: Icon(Icons.calendar_today),
//                       ),
//                       child: Row(
//                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                         children: [
//                           Text(
//                             _proximaDosisController.text.isEmpty 
//                                 ? 'Seleccionar fecha' 
//                                 : _proximaDosisController.text,
//                           ),
//                           Icon(Icons.arrow_drop_down),
//                         ],
//                       ),
//                     ),
//                   ),
                  
//                   SizedBox(height: 32),
                  
//                   // 🔥 BOTÓN CON MARGEN DINÁMICO PARA EVITAR SUPERPOSICIÓN
//                   Container(
//                     margin: EdgeInsets.only(bottom: 24 + bottomPadding),
//                     width: double.infinity,
//                     height: 50,
//                     child: ElevatedButton(
//                       onPressed: _isLoading ? null : _guardarRegistro,
//                       style: ElevatedButton.styleFrom(
//                         backgroundColor: Colors.blue,
//                         foregroundColor: Colors.white,
//                         shape: RoundedRectangleBorder(
//                           borderRadius: BorderRadius.circular(12),
//                         ),
//                       ),
//                       child: _isLoading
//                           ? CircularProgressIndicator(color: Colors.white)
//                           : Text('Guardar Registro', style: TextStyle(fontSize: 16)),
//                     ),
//                   ),
                  
//                   // 🔥 ESPACIO EXTRA ADICIONAL CUANDO EL TECLADO ESTÁ VISIBLE
//                   SizedBox(height: bottomInset > 0 ? 60 : 24),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   @override
//   void dispose() {
//     _nombreController.dispose();
//     _cedulaController.dispose();
//     _tipoVacunaController.dispose();
//     _loteController.dispose();
//     _proximaDosisController.dispose();
//     super.dispose();
//   }
// }

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/vacuna_service.dart';
import '../models/vacuna.dart';
import 'visualizar_registros_screen.dart';

class RegistroVacunaScreen extends StatefulWidget {
  @override
  _RegistroVacunaScreenState createState() => _RegistroVacunaScreenState();
}

class _RegistroVacunaScreenState extends State<RegistroVacunaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _cedulaController = TextEditingController();
  final _cedulaTutorController = TextEditingController();
  final _tipoVacunaController = TextEditingController();
  final _loteController = TextEditingController();
  final _proximaDosisController = TextEditingController();
  
  String _tipoPaciente = 'nino';
  DateTime _fechaVacunacion = DateTime.now();
  bool _isLoading = false;
  bool _esMenor = true;

  Future<void> _seleccionarFecha(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _fechaVacunacion,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != _fechaVacunacion) {
      setState(() {
        _fechaVacunacion = picked;
      });
    }
  }

  Future<void> _seleccionarProximaDosis(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _fechaVacunacion.add(Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _proximaDosisController.text = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }

  void _cambiarTipoPaciente(String tipo) {
    setState(() {
      _tipoPaciente = tipo;
      _esMenor = (tipo == 'nino');
    });
  }

  Future<void> _guardarRegistro() async {
    if (_formKey.currentState!.validate()) {
      // Validaciones
      if (_esMenor && _cedulaTutorController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Para niños se requiere la cédula del tutor')),
        );
        return;
      }
      
      if (!_esMenor && _cedulaController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Para adultos se requiere la cédula')),
        );
        return;
      }

      setState(() {
        _isLoading = true;
      });

      final vacunaService = Provider.of<VacunaService>(context, listen: false);
      
      // Para adultos: usar su nombre y cédula original
      // Para niños: usar nombre del niño y cédula del tutor
      final String cedulaFinal = _esMenor 
          ? _cedulaTutorController.text 
          : _cedulaController.text;
      
      final String nombrePaciente = _nombreController.text.trim();
      
      final nuevaVacuna = Vacuna(
        nombreVacuna: _tipoVacunaController.text.trim(),
        fechaAplicacion: "${_fechaVacunacion.year}-${_fechaVacunacion.month.toString().padLeft(2, '0')}-${_fechaVacunacion.day.toString().padLeft(2, '0')}",
        lote: _loteController.text.trim().isEmpty ? null : _loteController.text.trim(),
        proximaDosis: _proximaDosisController.text.trim().isEmpty ? null : _proximaDosisController.text.trim(),
        nombrePaciente: nombrePaciente,
        cedulaPaciente: cedulaFinal,
        esMenor: _esMenor,
        cedulaTutor: _esMenor ? _cedulaTutorController.text.trim() : null,
        cedulaPropia: !_esMenor ? _cedulaController.text.trim() : null,
        createdAt: DateTime.now(),
      );

      try {
        await vacunaService.crearVacuna(nuevaVacuna);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Registro guardado exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Limpiar formulario (mantener tipo de paciente)
        _formKey.currentState!.reset();
        setState(() {
          _fechaVacunacion = DateTime.now();
          _loteController.clear();
          _proximaDosisController.clear();
          _isLoading = false;
        });
        
        // NO limpiar nombre, cédula o tipo de paciente
        // para facilitar registro múltiple de la misma familia
        
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: 16 + bottomPadding,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tabs de navegación
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () {},
                    child: Text(
                      'Registrar',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => VisualizarRegistrosScreen()),
                      );
                    },
                    child: Text(
                      'Visualizar',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ),
              ],
            ),
            
            SizedBox(height: 16),
            
            Text(
              'Registro de Vacunas',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            
            SizedBox(height: 8),
            
            Text(
              _esMenor 
                  ? 'Registro para niño (usar cédula del tutor)'
                  : 'Registro para adulto (usar cédula propia)',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            
            SizedBox(height: 24),
            
            Form(
              key: _formKey,
              child: Column(
                children: [
                  // Tipo de Paciente
                  Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tipo de Paciente *',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: ChoiceChip(
                                  label: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.child_care, size: 16),
                                      SizedBox(width: 8),
                                      Text('Niño'),
                                    ],
                                  ),
                                  selected: _esMenor,
                                  selectedColor: Colors.blue,
                                  onSelected: (selected) {
                                    if (selected) _cambiarTipoPaciente('nino');
                                  },
                                ),
                              ),
                              SizedBox(width: 16),
                              Expanded(
                                child: ChoiceChip(
                                  label: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.person, size: 16),
                                      SizedBox(width: 8),
                                      Text('Adulto'),
                                    ],
                                  ),
                                  selected: !_esMenor,
                                  selectedColor: Colors.green,
                                  onSelected: (selected) {
                                    if (selected) _cambiarTipoPaciente('adulto');
                                  },
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          Text(
                            _esMenor 
                                ? '👶 Niño - Registrar con cédula del tutor'
                                : '👤 Adulto - Registrar con cédula propia',
                            style: TextStyle(
                              fontSize: 12,
                              color: _esMenor ? Colors.blue : Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  SizedBox(height: 16),
                  
                  // Nombre del Paciente
                  TextFormField(
                    controller: _nombreController,
                    decoration: InputDecoration(
                      labelText: 'Nombre Completo *',
                      hintText: _esMenor ? 'Nombre del niño' : 'Nombre del adulto',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor ingresa el nombre';
                      }
                      if (value.length < 3) {
                        return 'El nombre debe tener al menos 3 caracteres';
                      }
                      return null;
                    },
                  ),
                  
                  SizedBox(height: 16),
                  
                  // Cédula (dependiendo del tipo)
                  if (_esMenor)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: _cedulaTutorController,
                          decoration: InputDecoration(
                            labelText: 'Cédula del Tutor *',
                            hintText: 'Cédula del padre/madre/tutor',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.family_restroom),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Ingresa la cédula del tutor';
                            }
                            return null;
                          },
                        ),
                        Padding(
                          padding: EdgeInsets.only(left: 8, top: 4),
                          child: Text(
                            '💡 Puedes registrar varios niños con la misma cédula de tutor',
                            style: TextStyle(fontSize: 11, color: Colors.blue),
                          ),
                        ),
                      ],
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: _cedulaController,
                          decoration: InputDecoration(
                            labelText: 'Cédula del Adulto *',
                            hintText: 'Cédula de identidad',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.badge),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Ingresa la cédula del adulto';
                            }
                            return null;
                          },
                        ),
                        Padding(
                          padding: EdgeInsets.only(left: 8, top: 4),
                          child: Text(
                            '💡 Este nombre NO será sobreescrito por otros registros',
                            style: TextStyle(fontSize: 11, color: Colors.green),
                          ),
                        ),
                      ],
                    ),
                  
                  SizedBox(height: 16),
                  
                  // Fecha de Vacunación
                  InkWell(
                    onTap: () => _seleccionarFecha(context),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Fecha de Vacunación *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.calendar_today),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("${_fechaVacunacion.day}/${_fechaVacunacion.month}/${_fechaVacunacion.year}"),
                          Icon(Icons.arrow_drop_down),
                        ],
                      ),
                    ),
                  ),
                  
                  SizedBox(height: 16),
                  
                  // Tipo de Vacuna
                  TextFormField(
                    controller: _tipoVacunaController,
                    decoration: InputDecoration(
                      labelText: 'Tipo de Vacuna *',
                      hintText: 'Ej: Triple Viral, BCG, Polio, etc.',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.medical_services),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor ingresa el tipo de vacuna';
                      }
                      return null;
                    },
                  ),
                  
                  SizedBox(height: 16),
                  
                  // Lote (Opcional)
                  TextFormField(
                    controller: _loteController,
                    decoration: InputDecoration(
                      labelText: 'Lote (Opcional)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.confirmation_number),
                    ),
                  ),
                  
                  SizedBox(height: 16),
                  
                  // Próxima Dosis (Opcional)
                  InkWell(
                    onTap: () => _seleccionarProximaDosis(context),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Próxima Dosis (Opcional)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.calendar_today),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _proximaDosisController.text.isEmpty 
                                ? 'Seleccionar fecha' 
                                : _proximaDosisController.text,
                          ),
                          Icon(Icons.arrow_drop_down),
                        ],
                      ),
                    ),
                  ),
                  
                  SizedBox(height: 32),
                  
                  // Botón Guardar
                  Container(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _guardarRegistro,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _esMenor ? Colors.blue : Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? CircularProgressIndicator(color: Colors.white)
                          : Text('Guardar Registro', style: TextStyle(fontSize: 16)),
                    ),
                  ),
                  
                  SizedBox(height: 16),
                  
                  // Botón para registrar otro
                  Container(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton(
                      onPressed: () {
                        // Limpiar solo los campos de vacuna
                        _tipoVacunaController.clear();
                        _loteController.clear();
                        _proximaDosisController.clear();
                        _fechaVacunacion = DateTime.now();
                        
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Listo para registrar otra vacuna para ${_nombreController.text}'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      child: Text('Registrar Otra Vacuna para Este Paciente'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _cedulaController.dispose();
    _cedulaTutorController.dispose();
    _tipoVacunaController.dispose();
    _loteController.dispose();
    _proximaDosisController.dispose();
    super.dispose();
  }
}