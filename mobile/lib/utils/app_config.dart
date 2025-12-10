// // lib/app_config.dart
// class AppConfig {
//   static const String appName = 'HealthShield';
//   static const String appVersion = 'alfa 1.0.1';
//   static const String databaseName = 'healthshield.db';
  
//   // Configuración de API
//   static const String apiBaseUrl = 'http://localhost:5001/api';

//   static const int apiTimeoutSeconds = 30;
  
//   // Configuración de sincronización
//   static const bool autoSyncEnabled = true;
//   static const int syncIntervalMinutes = 30;
// }

class AppConfig {
  static const String appName = 'HealthShield';
  static const String appVersion = 'alfa 1.0.1';
  
  // Configuración de API - Para desarrollo con emulador Android
  // NOTA: En Android Emulator, localhost se refiere al dispositivo, no al host
  // Usa 10.0.2.2 para acceder al host local desde el emulador Android
  static const String apiBaseUrl = 'http://10.0.2.2:8000/api'; // Para emulador Android
  
  // Para dispositivo físico en la misma red:
  // static const String apiBaseUrl = 'http://192.168.1.100:8000/api';
  
  // Para producción:
  // static const String apiBaseUrl = 'https://tu-api.com/api';
  
  static const int apiTimeoutSeconds = 30;
  static const bool autoSyncEnabled = true;
  static const int syncIntervalMinutes = 30;
  
  // Modo de desarrollo (permite funcionar sin API)
  static const bool developmentMode = true;
}