/// App Configuration
///
/// IMPORTANT: This file contains configuration that should be managed
/// through environment variables in production.
///
/// For local development, you can modify these values.
/// For production, use --dart-define to pass values at build time.

import 'local_config.dart';

class AppConfig {
  // Private constructor to prevent instantiation
  AppConfig._();

  /// MongoDB connection string
  ///
  /// Uses LocalConfig for credentials (gitignored for security)
  /// In production, pass this via:
  /// flutter build apk --dart-define=MONGO_URI=your_connection_string
  static String mongoUri = const String.fromEnvironment(
    'MONGO_URI',
    defaultValue: '',
  ).isEmpty ? LocalConfig.mongoUri : const String.fromEnvironment('MONGO_URI');

  /// API Base URL
  ///
  /// In production, pass this via:
  /// flutter build apk --dart-define=API_BASE_URL=https://your-api.com
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:5000/api',
  );

  /// Database name
  static const String databaseName = 'attendance_DB';

  /// Check if running in production mode
  static const bool isProduction = bool.fromEnvironment('dart.vm.product');
}
