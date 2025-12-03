import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/api_service.dart';
import 'services/paciente_service.dart';
import 'services/vacuna_service.dart';
import 'services/sync_service.dart';
import 'screens/welcome_screen.dart';
import 'screens/login_screen.dart';
import 'screens/professional_register_screen.dart';
import 'screens/main_menu_screen.dart';
import 'screens/registro_vacuna_screen.dart';
import 'screens/visualizar_registros_screen.dart';
import 'screens/sync_screen.dart';
import 'screens/change_password_screen.dart';
import 'screens/dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // Inicializar servicios
    final pacienteService = PacienteService();
    final vacunaService = VacunaService();
    final apiService = ApiService();
    
    await pacienteService.init();
    await vacunaService.init();
    
    final syncService = SyncService(
      pacienteService: pacienteService,
      vacunaService: vacunaService,
      apiService: apiService,
    );
    
    // Sincronización automática al iniciar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      syncService.autoSync();
    });

    runApp(
      MyApp(
        pacienteService: pacienteService,
        vacunaService: vacunaService,
        apiService: apiService,
        syncService: syncService,
      ),
    );
  } catch (e) {
    print('❌ Error inicializando app: $e');
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('Error inicializando aplicación'),
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  final PacienteService pacienteService;
  final VacunaService vacunaService;
  final ApiService apiService;
  final SyncService syncService;

  MyApp({
    required this.pacienteService,
    required this.vacunaService,
    required this.apiService,
    required this.syncService,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<PacienteService>.value(value: pacienteService),
        Provider<VacunaService>.value(value: vacunaService),
        Provider<ApiService>.value(value: apiService),
        Provider<SyncService>.value(value: syncService),
      ],
      child: MaterialApp(
        title: 'HealthShield',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        home: WelcomeScreen(),
        debugShowCheckedModeBanner: false,
        routes: {
          '/welcome': (context) => WelcomeScreen(),
          '/login': (context) => LoginScreen(),
          '/register': (context) => ProfessionalRegisterScreen(),
          '/main-menu': (context) => MainMenuScreen(),
          '/registro-vacuna': (context) => RegistroVacunaScreen(),
          '/visualizar-registros': (context) => VisualizarRegistrosScreen(),
          '/sync': (context) => SyncScreen(),
          '/change-password': (context) => ChangePasswordScreen(),
          '/dashboard': (context) => DashboardScreen(),
        },
      ),
    );
  }
}