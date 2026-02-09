import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Database and Services
import 'package:healthshield/db_sqlite/database_helper.dart';
import 'package:healthshield/db_sqlite/cache_service.dart';
import 'package:healthshield/services/auth_service.dart';
import 'package:healthshield/services/vacuna_service.dart';
import 'package:healthshield/services/paciente_service.dart';
import 'package:healthshield/services/api_service.dart';
import 'package:healthshield/services/bidirectional_sync_service.dart';
import 'package:healthshield/services/sync_service.dart';
import 'package:healthshield/services/user_sync_service.dart';

// Screens
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
import 'package:healthshield/screens/paciente_detalle_screen.dart';
import 'package:healthshield/screens/detalle_usuario_screen.dart';

// Models
import 'package:healthshield/models/usuario.dart'; 

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 🔥 DESHABILITAR ANIMACIONES LENTAS
  WidgetsBinding.instance.addPostFrameCallback((_) {
    // Optimizar para reducir lag
  });
  
  print('🚀 Inicializando HealthShield...');
  
  try {
    // Inicializar base de datos
    final databaseHelper = DatabaseHelper.instance;
    await databaseHelper.database;
    print('✅ Base de datos inicializada');
    
    runApp(MyApp());
  } catch (e) {
    print('❌ Error crítico: $e');
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('Error inicializando app: $e'),
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider(create: (_) => DatabaseHelper.instance),
        Provider(create: (_) => CacheService()),
        Provider(create: (_) => ApiService()),
        Provider(
          create: (context) {
            final cacheService = context.read<CacheService>();
            return AuthService(cacheService: cacheService);
          },
        ),
        Provider(
          create: (context) => VacunaService(),
        ),
        Provider(
          create: (context) => PacienteService(),
        ),
        // ✅ AGREGAR BIDIRECTIONALSYNCSERVICE
        Provider(
          create: (context) {
            final cacheService = context.read<CacheService>();
            final apiService = context.read<ApiService>();
            return BidirectionalSyncService(
              cacheService: cacheService,
              apiService: apiService,
            );
          },
        ),
        // ✅ AGREGAR SYNC SERVICE Y USER SYNC SERVICE
        Provider(
          create: (context) {
            final vacunaService = context.read<VacunaService>();
            final apiService = context.read<ApiService>();
            return SyncService(
              vacunaService: vacunaService,
              apiService: apiService,
            );
          },
        ),
        Provider(
          create: (context) {
            final cacheService = context.read<CacheService>();
            final apiService = context.read<ApiService>();
            return UserSyncService(
              cacheService: cacheService,
              apiService: apiService,
            );
          },
        ),
      ],
      child: Builder(
        builder: (context) {
          // Inicializar AuthService después de que los providers estén listos
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final authService = context.read<AuthService>();
            authService.init();
          });
          
          return MaterialApp(
            title: 'HealthShield',
            debugShowCheckedModeBanner: false,
            
            // 🔥 OPTIMIZACIONES DE RENDIMIENTO
            scrollBehavior: const MaterialScrollBehavior().copyWith(
              physics: const BouncingScrollPhysics(),
              scrollbars: false,
            ),
            
            theme: ThemeData(
              primarySwatch: Colors.blue,
              visualDensity: VisualDensity.adaptivePlatformDensity,
              appBarTheme: AppBarTheme(
                backgroundColor: Colors.white,
                foregroundColor: Colors.blue,
                elevation: 1,
                centerTitle: true,
              ),
              // 🔥 TRANSICIONES MÁS RÁPIDAS
              pageTransitionsTheme: PageTransitionsTheme(
                builders: {
                  TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
                  TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
                },
              ),
            ),
            
            // Ruta inicial
            initialRoute: '/welcome',

            routes: {
              // Pantallas de autenticación (acceso público)
              '/welcome': (context) => WelcomeScreen(),
              '/login': (context) => LoginScreen(),
              
              // Pantallas principales
              '/main-menu': (context) => _buildProtectedScreen(MainMenuScreen(), context),
              '/dashboard': (context) => _buildProtectedScreen(MainMenuScreen(), context),
              
              // Pantallas de funcionalidad
              '/registro-vacuna': (context) => _buildProtectedScreen(RegistroVacunaScreen(), context),
              '/visualizar-registros': (context) => _buildProtectedScreen(VisualizarRegistrosScreen(), context),
              '/sync': (context) => _buildProtectedScreen(SyncScreen(), context),
              '/change-password': (context) => _buildProtectedScreen(ChangePasswordScreen(), context),
              '/gestion-pacientes': (context) => _buildProtectedScreen(GestionPacientesScreen(), context),
              
              // Nueva pantalla de detalles del paciente
              '/paciente-detalle': (context) {
                // Manejo seguro de argumentos
                final args = ModalRoute.of(context)?.settings.arguments;
                
                if (args != null && args is Map<String, dynamic>) {
                  return _buildProtectedScreen(
                    PacienteDetalleScreen(
                      cedula: args['cedula']?.toString() ?? '',
                      nombre: args['nombre']?.toString() ?? 'Paciente',
                    ), 
                    context
                  );
                }
                
                // Si no hay argumentos válidos, mostrar pantalla vacía
                return _buildProtectedScreen(
                  PacienteDetalleScreen(
                    cedula: '',
                    nombre: 'Paciente no especificado',
                  ), 
                  context
                );
              },
              
              // Pantallas de admin (solo para administradores)
              '/admin-dashboard': (context) => _buildAdminProtectedScreen(AdminDashboardScreen(), context),
              '/admin-usuarios': (context) => _buildAdminProtectedScreen(AdminUsuariosScreen(), context),
              
              // Registro de profesionales (solo admin)
              '/professional-register': (context) => _buildAdminProtectedScreen(ProfessionalRegisterScreen(), context),
              
              // Detalle de usuario (solo admin)
              '/detalle-usuario': (context) {
                final args = ModalRoute.of(context)?.settings.arguments;
                if (args != null && args is Usuario) {
                  return _buildAdminProtectedScreen(
                    DetalleUsuarioScreen(usuario: args), 
                    context
                  );
                }
                return _buildAdminProtectedScreen(
                  Scaffold(
                    body: Center(child: Text('Usuario no especificado')),
                  ), 
                  context
                );
              },
            },
            
            // Manejo de rutas no definidas
            onUnknownRoute: (settings) {
              return MaterialPageRoute(
                builder: (context) => WelcomeScreen(),
              );
            },
          );
        },
      ),
    );
  }
  
  // Función para proteger pantallas que requieren autenticación
  Widget _buildProtectedScreen(Widget screen, BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final currentUser = authService.currentUser;
    
    if (currentUser == null) {
      // Si no hay usuario autenticado, redirigir al login
      Future.microtask(() {
        Navigator.pushReplacementNamed(context, '/login');
      });
      return _buildLoadingScreen();
    }
    
    return screen;
  }
  
  // Función para proteger pantallas que requieren ser admin
  Widget _buildAdminProtectedScreen(Widget screen, BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final currentUser = authService.currentUser;
    
    if (currentUser == null) {
      // Si no hay usuario autenticado, redirigir al login
      Future.microtask(() {
        Navigator.pushReplacementNamed(context, '/login');
      });
      return _buildLoadingScreen();
    }
    
    if (!currentUser.isAdmin) {
      // Si no es admin, mostrar pantalla de acceso denegado
      return _buildAccessDeniedScreen(context);
    }
    
    return screen;
  }
  
  Widget _buildLoadingScreen() {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Verificando acceso...'),
          ],
        ),
      ),
    );
  }
  
  Widget _buildAccessDeniedScreen(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('HealthShield'),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.admin_panel_settings, size: 64, color: Colors.red),
              SizedBox(height: 24),
              Text(
                'Acceso Restringido',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Esta sección es solo para administradores del sistema.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Si necesitas acceso de administrador, contacta al soporte técnico.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[500],
                ),
              ),
              SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushReplacementNamed(context, '/main-menu');
                },
                child: Text('Volver al Menú Principal'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}