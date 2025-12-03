import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; 
import 'package:healthshield/services/auth_service.dart';
import 'package:healthshield/services/vacuna_service.dart';
import 'package:healthshield/services/api_service.dart';
import 'package:healthshield/services/sync_service.dart';
import 'package:healthshield/services/bidirectional_sync_service.dart';
import 'package:healthshield/db_sqlite/cache_service.dart';
import 'package:healthshield/screens/welcome_screen.dart';
import 'package:healthshield/screens/login_screen.dart';
import 'package:healthshield/screens/professional_register_screen.dart';
import 'package:healthshield/screens/main_menu_screen.dart';
import 'package:healthshield/screens/registro_vacuna_screen.dart';
import 'package:healthshield/screens/visualizar_registros_screen.dart';
import 'package:healthshield/screens/sync_screen.dart';
import 'package:healthshield/screens/change_password_screen.dart';
import 'package:healthshield/screens/dashboard_screen.dart'; // AGREGAR ESTA LÍNEA

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // Inicializar servicios de base de datos SQLite
    final cacheService = CacheService();
    
    // Servicios de aplicación
    final authService = AuthService(cacheService: cacheService);
    await authService.init();
    
    final vacunaService = VacunaService();
    await vacunaService.init();

    // Servicios de API y sincronización
    final apiService = ApiService();
    final syncService = SyncService(
      vacunaService: vacunaService,
      apiService: apiService,
    );

    final bidirectionalSyncService = BidirectionalSyncService(
      cacheService: cacheService,
      apiService: apiService,
    );

    runApp(
      MyApp(
        authService: authService,
        vacunaService: vacunaService,
        apiService: apiService,
        syncService: syncService,
        bidirectionalSyncService: bidirectionalSyncService,
        cacheService: cacheService,
      ),
    );
  } catch (e) {
    print('❌ Error inicializando app: $e');
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('Error inicializando aplicación: $e'),
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  final AuthService authService;
  final VacunaService vacunaService;
  final ApiService apiService;
  final SyncService syncService;
  final BidirectionalSyncService bidirectionalSyncService;
  final CacheService cacheService;

  MyApp({
    required this.authService,
    required this.vacunaService,
    required this.apiService,
    required this.syncService,
    required this.bidirectionalSyncService,
    required this.cacheService,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthService>.value(value: authService),
        Provider<VacunaService>.value(value: vacunaService),
        Provider<ApiService>.value(value: apiService),
        Provider<SyncService>.value(value: syncService),
        Provider<BidirectionalSyncService>.value(value: bidirectionalSyncService),
        Provider<CacheService>.value(value: cacheService),
      ],
      child: MaterialApp(
        title: 'HealthShield',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
          fontFamily: 'Roboto',
        ),
        home: WelcomeScreen(),
        debugShowCheckedModeBanner: false,
        routes: {
          '/welcome': (context) => WelcomeScreen(),
          '/login': (context) => LoginScreen(),
          '/register': (context) => ProfessionalRegisterScreen(), // Mantener este nombre
          '/register-professional': (context) => ProfessionalRegisterScreen(),
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