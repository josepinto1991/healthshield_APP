import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:healthshield/services/auth_service.dart';
import 'package:healthshield/services/vacuna_service.dart';
import 'package:healthshield/services/paciente_service.dart';
import 'package:healthshield/services/sync_service.dart';
import 'package:healthshield/db_sqlite/database_helper.dart';
import 'package:healthshield/db_sqlite/cache_service.dart';
import 'package:healthshield/screens/welcome_screen.dart';
import 'package:healthshield/screens/login_screen.dart';
import 'package:healthshield/screens/professional_register_screen.dart';
import 'package:healthshield/screens/main_menu_screen.dart';
import 'package:healthshield/screens/registro_vacuna_screen.dart';
import 'package:healthshield/screens/visualizar_registros_screen.dart';
import 'package:healthshield/screens/sync_screen.dart';
import 'package:healthshield/screens/change_password_screen.dart';
import 'package:healthshield/screens/admin_dashboard_screen.dart';
import 'package:healthshield/screens/admin_usuarios_screen.dart';
import 'package:healthshield/screens/gestion_pacientes_screen.dart';
import 'package:healthshield/utils/route_guard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    print('🚀 Inicializando aplicación HealthShield...');
    
    // Inicializar DatabaseHelper primero
    await DatabaseHelper.instance.database;
    print('✅ Base de datos inicializada');
    
    // Inicializar servicios
    final cacheService = CacheService();
    
    final authService = AuthService(cacheService: cacheService);
    await authService.init();
    print('✅ AuthService inicializado');
    
    final pacienteService = PacienteService();
    print('✅ PacienteService inicializado');
    
    final vacunaService = VacunaService();
    await vacunaService.init();
    print('✅ VacunaService inicializado');
    
    runApp(
      MyApp(
        authService: authService,
        pacienteService: pacienteService,
        vacunaService: vacunaService,
        cacheService: cacheService,
      ),
    );
  } catch (e) {
    print('❌ Error crítico inicializando app: $e');
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error, size: 64, color: Colors.red),
                SizedBox(height: 20),
                Text(
                  'Error inicializando aplicación',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 10),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    e.toString(),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  final AuthService authService;
  final PacienteService pacienteService;
  final VacunaService vacunaService;
  final CacheService cacheService;

  MyApp({
    required this.authService,
    required this.pacienteService,
    required this.vacunaService,
    required this.cacheService,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthService>.value(value: authService),
        Provider<PacienteService>.value(value: pacienteService),
        Provider<VacunaService>.value(value: vacunaService),
        Provider<CacheService>.value(value: cacheService),
      ],
      child: MaterialApp(
        title: 'HealthShield',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
          fontFamily: 'Roboto',
          appBarTheme: AppBarTheme(
            elevation: 2,
            backgroundColor: Colors.white,
            foregroundColor: Colors.blue,
            centerTitle: true,
          ),
        ),
        initialRoute: '/welcome',
        debugShowCheckedModeBanner: false,
        routes: {
          '/welcome': (context) => WelcomeScreen(),
          '/login': (context) => LoginScreen(),
          '/register': (context) => ProfessionalRegisterScreen(),
          '/main-menu': (context) => RouteGuard.authenticatedOnly(MainMenuScreen()),
          '/registro-vacuna': (context) => RouteGuard.authenticatedOnly(RegistroVacunaScreen()),
          '/visualizar-registros': (context) => RouteGuard.authenticatedOnly(VisualizarRegistrosScreen()),
          '/sync': (context) => RouteGuard.authenticatedOnly(SyncScreen()),
          '/change-password': (context) => RouteGuard.authenticatedOnly(ChangePasswordScreen()),
          '/admin-dashboard': (context) => RouteGuard.adminOnly(AdminDashboardScreen()),
          '/admin-usuarios': (context) => RouteGuard.adminOnly(AdminUsuariosScreen()),
          '/gestion-pacientes': (context) => RouteGuard.authenticatedOnly(GestionPacientesScreen()),
        },
      ),
    );
  }
}