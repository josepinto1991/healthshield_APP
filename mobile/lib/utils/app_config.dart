// lib/app_config.dart
class AppConfig {
  static const String appName = 'HealthShield';
  static const String appVersion = 'Release 1.0.1';
  
  static const String apiBaseUrl = 'https://healthshield-app.vercel.app/api';
  
  static const int apiTimeoutSeconds = 30;
  static const bool autoSyncEnabled = true;
  static const int syncIntervalMinutes = 30;
  
  // Modo de desarrollo (permite funcionar sin API)
  static const bool developmentMode = true;
  
  // Verificar conexión a internet
  static const String connectivityCheckUrl = 'https://www.google.com';
  
  // Mensajes de error personalizados
  static const String noInternetMessage = 'No hay conexión a internet. Verifica tu conexión e intenta de nuevo.';
  static const String serverUnavailableMessage = 'El servidor no está disponible en este momento. Los datos se guardarán localmente.';
  static const String syncSuccessMessage = 'Sincronización completada exitosamente.';
}
