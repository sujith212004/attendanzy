import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// Handles notification events and displays appropriate UI responses
class NotificationHandler {
  static GlobalKey<NavigatorState>? navigatorKey;

  /// Process incoming notification and show appropriate response
  static Future<void> handleNotification(RemoteMessage message) async {
    final data = message.data;
    final notification = message.notification;

    print('🔔 Processing notification: ${notification?.title}');
    print('📊 Notification data: $data');

    final notificationType = data['type'] ?? '';
    final requestType = data['requestType'] ?? '';

    switch (notificationType) {
      case 'new_request':
        _handleNewRequest(notification, data);
        break;
      case 'forwarded_request':
        _handleForwardedRequest(notification, data);
        break;
      case 'status_update':
        _handleStatusUpdate(notification, data, requestType);
        break;
      case 'hod_decision':
        _handleHODDecision(notification, data, requestType);
        break;
      default:
        _handleGenericNotification(notification);
    }
  }

  /// Handle new request notification (sent to staff)
  static void _handleNewRequest(
    RemoteNotification? notification,
    Map<String, dynamic> data,
  ) {
    final title = notification?.title ?? 'New Request';
    final body = notification?.body ?? 'You have a new request to review';

    _showNotificationDialog(
      title: title,
      body: body,
      icon: Icons.assignment_outlined,
      iconColor: Colors.blue,
      actions: [
        TextButton(
          onPressed: () => _navigateTo('/staff-requests'),
          child: const Text('Review'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(navigatorKey!.currentContext!),
          child: const Text('Later'),
        ),
      ],
    );
  }

  /// Handle forwarded request notification (sent to HOD)
  static void _handleForwardedRequest(
    RemoteNotification? notification,
    Map<String, dynamic> data,
  ) {
    final title = notification?.title ?? 'Request Awaiting Approval';
    final body =
        notification?.body ?? 'A request has been forwarded for your approval';

    _showNotificationDialog(
      title: title,
      body: body,
      icon: Icons.check_circle_outline,
      iconColor: Colors.orange,
      actions: [
        TextButton(
          onPressed: () => _navigateTo('/hod-requests'),
          child: const Text('View'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(navigatorKey!.currentContext!),
          child: const Text('Dismiss'),
        ),
      ],
    );
  }

  /// Handle status update notification (sent to student)
  static void _handleStatusUpdate(
    RemoteNotification? notification,
    Map<String, dynamic> data,
    String requestType,
  ) {
    final title = notification?.title ?? 'Request Updated';
    final body = notification?.body ?? 'Your request has been updated';
    final status = data['status'] ?? '';
    final approverRole = data['approverRole'] ?? '';

    Color statusColor;
    IconData statusIcon;

    if (status.toLowerCase() == 'forwarded') {
      statusColor = Colors.orange;
      statusIcon = Icons.send;
    } else if (status.toLowerCase() == 'approved' ||
        status.toLowerCase() == 'accepted') {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
    } else if (status.toLowerCase() == 'rejected') {
      statusColor = Colors.red;
      statusIcon = Icons.cancel;
    } else {
      statusColor = Colors.blue;
      statusIcon = Icons.info;
    }

    _showNotificationDialog(
      title: title,
      body: body,
      icon: statusIcon,
      iconColor: statusColor,
      actions: [
        TextButton(
          onPressed: () {
            _navigateTo('/request-status');
            Navigator.pop(navigatorKey!.currentContext!);
          },
          child: const Text('View Details'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(navigatorKey!.currentContext!),
          child: const Text('Dismiss'),
        ),
      ],
    );
  }

  /// Handle HOD decision notification (sent to student)
  static void _handleHODDecision(
    RemoteNotification? notification,
    Map<String, dynamic> data,
    String requestType,
  ) {
    final title = notification?.title ?? 'Request Status';
    final body =
        notification?.body ?? 'HOD has made a decision on your request';
    final status = data['status'] ?? '';

    final isApproved = status.toLowerCase() == 'approved';
    final statusColor = isApproved ? Colors.green : Colors.red;
    final statusIcon = isApproved ? Icons.thumb_up : Icons.thumb_down;

    _showNotificationDialog(
      title: title,
      body: body,
      icon: statusIcon,
      iconColor: statusColor,
      actions: [
        TextButton(
          onPressed: () {
            _navigateTo('/request-status');
            Navigator.pop(navigatorKey!.currentContext!);
          },
          child: const Text('View'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(navigatorKey!.currentContext!),
          child: const Text('Close'),
        ),
      ],
    );
  }

  /// Handle generic notification
  static void _handleGenericNotification(RemoteNotification? notification) {
    _showNotificationDialog(
      title: notification?.title ?? 'Notification',
      body: notification?.body ?? 'You have a new notification',
      icon: Icons.notifications,
      iconColor: Colors.blue,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(navigatorKey!.currentContext!),
          child: const Text('Dismiss'),
        ),
      ],
    );
  }

  /// Show notification dialog
  static void _showNotificationDialog({
    required String title,
    required String body,
    required IconData icon,
    required Color iconColor,
    required List<TextButton> actions,
  }) {
    if (navigatorKey?.currentContext == null) {
      print('⚠️ Navigator context not available for showing dialog');
      return;
    }

    showDialog(
      context: navigatorKey!.currentContext!,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          icon: Icon(icon, color: iconColor, size: 48),
          title: Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          content: Text(
            body,
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
          actions: actions,
        );
      },
    );
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
