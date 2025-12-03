// lib/app_config.dart
class AppConfig {
  static const String appName = 'HealthShield';
  static const String appVersion = 'alfa 1.0.1';
  static const String databaseName = 'healthshield.db';
  
  // Configuración de API
  static const String apiBaseUrl = 'http://localhost:5001/api';
  static const int apiTimeoutSeconds = 30;
  
  // Configuración de sincronización
  static const bool autoSyncEnabled = true;
  static const int syncIntervalMinutes = 30;
}