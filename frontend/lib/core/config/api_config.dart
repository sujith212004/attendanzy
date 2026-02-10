/// API Configuration for Attendanzy
///
/// Switch between development and production by changing isProduction flag
/// or update the productionUrl with your deployed backend URL

class ApiConfig {
  // Set to true when using deployed backend
  static const bool isProduction = true;

  // Development URLs
  static const String androidEmulatorUrl = 'http://10.0.2.2:5000/api';
  static const String iosSimulatorUrl = 'http://localhost:5000/api';

  // Production URL - Render deployment
  static const String productionUrl =
      'https://attendanzy-backend.onrender.com/api';

  // Get the current base URL
  static String get baseUrl {
    if (isProduction) {
      return productionUrl;
    }
    // Default to Android emulator URL for development
    return androidEmulatorUrl;
  }
}
