import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/api_config.dart';

// Handle background messages
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('Handling background message: ${message.messageId}');
}

class FirebaseApi {
  final _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  // API base URL from centralized config
  static String get _apiBaseUrl => ApiConfig.baseUrl;

  Future<void> initNotifications() async {
    try {
      // Request notification permissions
      NotificationSettings settings = await _firebaseMessaging
          .requestPermission(
            alert: true,
            announcement: false,
            badge: true,
            carPlay: false,
            criticalAlert: false,
            provisional: false,
            sound: true,
          );

      print('Notification permission status: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        // Initialize local notifications for foreground
        await _initLocalNotifications();

        // Get the device token
        try {
          final token = await _firebaseMessaging.getToken();
          print("Firebase Messaging Token: $token");

          // Save token to shared preferences
          if (token != null) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('fcm_token', token);

            // Send token to backend if user is logged in (non-blocking)
            _sendTokenToBackend(token).catchError((e) {
              print('Error sending token to backend: $e');
            });
          }
        } catch (e) {
          print('Error getting FCM token: $e');
        }

        // Listen for token refresh
        _firebaseMessaging.onTokenRefresh.listen((newToken) async {
          print('FCM Token refreshed: $newToken');
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('fcm_token', newToken);
          _sendTokenToBackend(newToken).catchError((e) {
            print('Error sending refreshed token: $e');
          });
        });

        // Handle foreground notifications
        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

        // Handle notification taps when app is in background
        FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

        // Handle background messages
        FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler,
        );

        // Check if app was opened from a notification
        try {
          RemoteMessage? initialMessage =
              await _firebaseMessaging.getInitialMessage();
          if (initialMessage != null) {
            _handleNotificationTap(initialMessage);
          }
        } catch (e) {
          print('Error getting initial message: $e');
        }
      }
    } catch (e) {
      print('Error initializing notifications: $e');
    }
  }

  Future<void> _initLocalNotifications() async {
    try {
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const DarwinInitializationSettings iosSettings =
          DarwinInitializationSettings(
            requestAlertPermission: true,
            requestBadgePermission: true,
            requestSoundPermission: true,
          );

      const InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          print('Local notification tapped: ${response.payload}');
          // Handle notification tap
        },
      );

      // Create notification channel for Android
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'attendanzy_notifications',
        'Attendanzy Notifications',
        description: 'Notifications for leave and OD request updates',
        importance: Importance.high,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(channel);
    } catch (e) {
      print('Error initializing local notifications: $e');
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    print('Received foreground notification: ${message.notification?.title}');

    // Show local notification when app is in foreground
    if (message.notification != null) {
      _showLocalNotification(
        title: message.notification!.title ?? 'Attendanzy',
        body: message.notification!.body ?? '',
        payload: json.encode(message.data),
      );
    }
  }

  void _handleNotificationTap(RemoteMessage message) {
    print('Notification tapped: ${message.data}');
    // Navigate to appropriate screen based on notification data
    // You can use a navigation service or callback here
  }

  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'attendanzy_notifications',
          'Attendanzy Notifications',
          channelDescription: 'Notifications for leave and OD request updates',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }

  Future<void> _sendTokenToBackend(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userEmail = prefs.getString('email');

      if (userEmail == null || userEmail.isEmpty) {
        print('No user email found, skipping token update');
        return;
      }

      final response = await http.post(
        Uri.parse('$_apiBaseUrl/notifications/update-token'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': userEmail, 'fcmToken': token}),
      );

      if (response.statusCode == 200) {
        print('FCM token updated on backend successfully');
      } else {
        print('Failed to update FCM token: ${response.body}');
      }
    } catch (e) {
      print('Error sending FCM token to backend: $e');
    }
  }

  // Call this after user logs in to update their FCM token
  Future<void> updateTokenForUser(String email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // ALWAYS get fresh token from Firebase (don't use cached)
      // This ensures the correct device token is used
      print('Fetching fresh FCM token from Firebase for device...');
      String? token = await _firebaseMessaging.getToken();
      
      if (token != null && token.isNotEmpty) {
        // Save to prefs
        await prefs.setString('fcm_token', token);
        
        print('Updating FCM token for: $email');
        print('Token (first 50 chars): ${token.substring(0, 50)}...');
        print('API URL: $_apiBaseUrl/notifications/update-token');
        
        final response = await http.post(
          Uri.parse('$_apiBaseUrl/notifications/update-token'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'email': email, 'fcmToken': token}),
        );

        print('FCM update response: ${response.statusCode} - ${response.body}');
        
        if (response.statusCode == 200) {
          print('✅ FCM token updated successfully for: $email');
        } else {
          print('❌ Failed to update FCM token: ${response.body}');
        }
      } else {
        print('❌ No FCM token available from Firebase');
      }
    } catch (e) {
      print('❌ Error updating FCM token for user: $e');
    }
  }
}
