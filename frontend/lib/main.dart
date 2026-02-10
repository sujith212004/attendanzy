import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_attendence_app/attendancedetails.dart';
import 'package:flutter_attendence_app/firebase_api.dart';
import 'package:flutter_attendence_app/firebase_options.dart';
import 'package:flutter_attendence_app/gpa_calculator.dart';
import 'package:flutter_attendence_app/homepage.dart';
import 'package:flutter_attendence_app/attendance.dart';
import 'package:flutter_attendence_app/loginpage.dart';
import 'package:flutter_attendence_app/odrequestpage.dart';
import 'package:flutter_attendence_app/profile_page.dart';
import 'package:flutter_attendence_app/timetable_page.dart';
import 'package:flutter_attendence_app/attendancemark.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_attendence_app/widgets/minimal_splash.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<_MyAppState> myAppKey = GlobalKey<_MyAppState>();

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // Only initialize Firebase if not already initialized
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e) {
    print('Firebase initialization error: $e');
  }

  // Initialize notifications BEFORE running the app to ensure handlers are registered
  try {
    await FirebaseApi().initNotifications();
    print('✅ Notifications initialized successfully');
  } catch (e) {
    print('❌ Error initializing notifications: $e');
  }

  final userExists = await _checkUserSession();
  final isStaff = await _getUserRole();

  runApp(MyApp(key: myAppKey, isStaff: isStaff, userExists: userExists));
}

/// Check if user session exists in SharedPreferences
Future<bool> _checkUserSession() async {
  final prefs = await SharedPreferences.getInstance();
  final email = prefs.getString('email');
  return email != null && email.isNotEmpty;
}

Future<bool> _getUserRole() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool('isStaff') ?? false;
}

class MyApp extends StatefulWidget {
  final bool isStaff;
  final bool userExists;

  const MyApp({super.key, required this.isStaff, required this.userExists});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _showPostSplash = true;
  late Future<Map<String, dynamic>?> _userDataFuture;
  bool _updateAvailable = false;
  bool _dialogShown = false;
  String _downloadUrl = '';

  @override
  void initState() {
    super.initState();
    initialization();
    _userDataFuture = _loadUserData();
    _checkForUpdate();
  }

  /// Load user data from SharedPreferences
  Future<Map<String, dynamic>?> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('email');
    if (email == null) return null;

    return {
      'email': email,
      'name': prefs.getString('name') ?? 'User',
      'profile': {'key': 'Default'},
      'isStaff': prefs.getBool('isStaff') ?? false,
      'role': prefs.getString('role') ?? 'user',
    };
  }

  void initialization() async {
    await Future.delayed(const Duration(milliseconds: 100));
    FlutterNativeSplash.remove();
  }

  void _onPostSplashComplete() {
    setState(() {
      _showPostSplash = false;
    });
  }

  Future<void> _checkForUpdate() async {
    try {
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      String currentVersion =
          '${packageInfo.version}+${packageInfo.buildNumber}';

      // Replace with your actual server URL that returns JSON like {"version": "2.0.2+5", "downloadUrl": "https://example.com/app.apk"}
      const String versionUrl = 'https://your-server.com/version.json';

      final response = await http.get(Uri.parse(versionUrl));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        String latestVersion = data['version'];
        String downloadUrl = data['downloadUrl'];

        if (_isNewerVersion(latestVersion, currentVersion)) {
          setState(() {
            _updateAvailable = true;
            _downloadUrl = downloadUrl;
          });
        }
      }
    } catch (e) {
      // Ignore errors, perhaps no internet or server down
    }
  }

  bool _isNewerVersion(String latest, String current) {
    List<String> latestParts = latest.split('+');
    List<String> currentParts = current.split('+');

    List<int> latestVer = latestParts[0].split('.').map(int.parse).toList();
    List<int> currentVer = currentParts[0].split('.').map(int.parse).toList();

    for (int i = 0; i < latestVer.length && i < currentVer.length; i++) {
      if (latestVer[i] > currentVer[i]) return true;
      if (latestVer[i] < currentVer[i]) return false;
    }

    if (latestVer.length > currentVer.length) return true;
    if (latestVer.length < currentVer.length) return false;

    // Compare build number
    int latestBuild = int.parse(latestParts[1]);
    int currentBuild = int.parse(currentParts[1]);
    return latestBuild > currentBuild;
  }

  void _showUpdateDialog() {
    showDialog(
      context: navigatorKey.currentContext!,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: const Text('Update Available'),
            content: const Text(
              'A new version of the app is available. Please update to continue using the latest features.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Later'),
              ),
              ElevatedButton(
                onPressed: () {
                  launchUrl(Uri.parse(_downloadUrl));
                  Navigator.of(context).pop();
                },
                child: const Text('Update Now'),
              ),
            ],
          ),
    );
  }

  void restartApp(bool newIsStaff) {
    Navigator.of(
      navigatorKey.currentContext!,
    ).pushReplacementNamed('/loginpage');
  }

  @override
  Widget build(BuildContext context) {
    if (_updateAvailable && !_dialogShown) {
      _dialogShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showUpdateDialog();
      });
    }

    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Attendance App',
      theme: ThemeData(primarySwatch: Colors.blue),
      home:
          _showPostSplash
              ? MinimalSplashAnimation(
                onComplete: _onPostSplashComplete,
                duration: const Duration(milliseconds: 3800),
              )
              : (widget.userExists
                  ? FutureBuilder<Map<String, dynamic>?>(
                    future: _userDataFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Scaffold(
                          body: Center(child: CircularProgressIndicator()),
                        );
                      }
                      if (!snapshot.hasData || snapshot.data == null) {
                        return const LoginPage();
                      }
                      final userData = snapshot.data!;
                      return HomePage(
                        name: userData['name'] ?? 'User',
                        email: userData['email'] ?? '',
                        profile: userData['profile'] ?? {},
                        isStaff: userData['isStaff'] ?? false,
                        role: userData['role'] ?? 'user',
                      );
                    },
                  )
                  : const LoginPage()),
      initialRoute: null,
      routes: {
        '/loginpage': (context) => const LoginPage(),
        '/homepage':
            (context) => FutureBuilder<Map<String, dynamic>?>(
              future: _userDataFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }
                if (!snapshot.hasData || snapshot.data == null) {
                  return const LoginPage();
                }
                final userData = snapshot.data!;
                return HomePage(
                  name: userData['name'] ?? 'User',
                  email: userData['email'] ?? '',
                  profile: userData['profile'] ?? {},
                  isStaff: userData['isStaff'] ?? false,
                  role: userData['role'] ?? 'user',
                );
              },
            ),
        '/attendancepage': (context) => const AttendanceSelectionPage(),
        '/attendancemark': (context) => const AttendanceScreen(),
        '/attendancedetails':
            (context) => AttendanceDetailsScreen(
              department: 'Default Department',
              year: 'Default Year',
              section: 'Default Section',
              presentStudents: [],
              absentStudents: [],
              onDutyStudents: [],
              onEdit: (Map<String, bool> updatedAttendance) {
                print(updatedAttendance);
              },
            ),
        '/profilepage':
            (context) => const ProfilePage(
              name: 'Default Name',
              email: 'default@example.com',
              department: 'Default Department',
              year: 'Default Year',
              section: 'Default Section',
            ),
        '/ ': (context) => const GPACalculatorPage(),
        '/timetablepage': (context) => TimetablePage(),
        '/odrequestpage': (context) => const ODRequestPage(),
      },
    );
  }
}
