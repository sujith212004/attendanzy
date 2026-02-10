import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// Handles notification events when user taps on system notification
class NotificationHandler {
  static GlobalKey<NavigatorState>? navigatorKey;

  /// Process incoming notification tap and navigate if needed
  static Future<void> handleNotification(RemoteMessage message) async {
    final data = message.data;
    final notificationType = data['type'] ?? '';

    print('🔔 Notification tapped: $notificationType');

    // Navigate based on notification type
    switch (notificationType) {
      case 'new_request':
        // Staff should see pending requests
        _navigateTo('/staff-requests');
        break;
      case 'forwarded_request':
        // HOD should see forwarded requests
        _navigateTo('/hod-requests');
        break;
      case 'status_update':
      case 'hod_decision':
        // Student should see their request status
        _navigateTo('/request-status');
        break;
      default:
        print('Unknown notification type: $notificationType');
    }
  }

  /// Navigate to a specific route
  static void _navigateTo(String route) {
    if (navigatorKey?.currentState != null) {
      navigatorKey!.currentState!.pushNamed(route);
    } else {
      print('⚠️ Cannot navigate to $route - Navigator not available');
    }
  }
}
