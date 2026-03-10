import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// Handles notification events when user taps on system notification
class NotificationHandler {
  static GlobalKey<NavigatorState>? navigatorKey;

  /// Process incoming notification tap and navigate if needed
  static Future<void> handleNotification(RemoteMessage message) async {
    final data = message.data;
    final notificationType = data['type'] ?? '';
    final requestType =
        data['requestType'] ?? 'OD'; // Default to OD if not specified

    print('🔔 Notification tapped: $notificationType');
    print('📋 Request Type: $requestType');

    // Navigate based on notification type and request type
    switch (notificationType) {
      case 'new_request':
        // Staff should see pending requests
        if (requestType.toUpperCase() == 'LEAVE') {
          _navigateTo('/staff-leave-requests');
        } else {
          _navigateTo('/staff-od-requests');
        }
        break;
      case 'forwarded_request':
        // HOD should see forwarded requests
        if (requestType.toUpperCase() == 'LEAVE') {
          _navigateTo('/hod-leave-requests');
        } else {
          _navigateTo('/hod-od-requests');
        }
        break;
      case 'status_update':
      case 'hod_decision':
        // Student should see their request status
        if (requestType.toUpperCase() == 'LEAVE') {
          _navigateTo('/student-leave-status');
        } else {
          _navigateTo('/student-od-status');
        }
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
