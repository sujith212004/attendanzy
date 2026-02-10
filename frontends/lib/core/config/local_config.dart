/// Local Configuration - DO NOT COMMIT TO GIT
/// 
/// This file contains sensitive credentials and should remain local only.

class LocalConfig {
  // MongoDB Connection String
  static const String mongoUri = 
      "mongodb+srv://digioptimized:digi123@cluster0.iuajg.mongodb.net/attendance_DB?retryWrites=true&w=majority";
  
  // API Base URL  
  static const String apiBaseUrl = "http://10.0.2.2:5000/api";
}
