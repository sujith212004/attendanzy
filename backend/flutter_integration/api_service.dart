import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // Base URL - Update this to your server IP when deploying
  static const String baseUrl = 'http://localhost:5000/api';

  // For Android emulator, use: http://10.0.2.2:5000/api
  // For real device on same network, use: http://YOUR_COMPUTER_IP:5000/api

  /// Login user
  ///
  /// Example
  /// ```dart
  /// final result = await ApiService.login(
  ///   email: 'student@example.com',
  ///   password: 'password123',
  ///   role: 'user',
  ///   department: 'Computer Science',
  /// );
  /// ```
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
    required String role,
    required String department,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          'role': role,
          'department': department,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'user': data['user'],
          'profile': data['profile'],
        };
      } else {
        return {'success': false, 'message': data['message'] ?? 'Login failed'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Failed to connect to server: $e'};
    }
  }

  /// Change password
  static Future<Map<String, dynamic>> changePassword({
    required String email,
    required String oldPassword,
    required String newPassword,
    required String role,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/change-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'oldPassword': oldPassword,
          'newPassword': newPassword,
          'role': role,
        }),
      );

      final data = jsonDecode(response.body);
      return data;
    } catch (e) {
      return {'success': false, 'message': 'Failed to connect to server: $e'};
    }
  }

  /// Get user profile
  static Future<Map<String, dynamic>> getProfile({
    required String email,
    required String role,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/auth/profile?email=$email&role=$role'),
        headers: {'Content-Type': 'application/json'},
      );

      final data = jsonDecode(response.body);
      return data;
    } catch (e) {
      return {'success': false, 'message': 'Failed to connect to server: $e'};
    }
  }

  /// Submit OD Request
  ///
  /// Example:
  /// ```dart
  /// final result = await ApiService.submitODRequest(
  ///   studentName: 'John Doe',
  ///   studentEmail: 'john@example.com',
  ///   from: 'John Doe (CSE, 3-A)',
  ///   to: 'HOD, Computer Science',
  ///   subject: 'OD Request for Hackathon',
  ///   content: 'Request for OD...',
  ///   department: 'Computer Science',
  ///   year: '3',
  ///   section: 'A',
  ///   image: base64Image,
  /// );
  /// ```
  static Future<Map<String, dynamic>> submitODRequest({
    required String studentName,
    required String studentEmail,
    required String from,
    required String to,
    required String subject,
    required String content,
    required String department,
    required String year,
    required String section,
    String? image,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/od-requests'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'studentName': studentName,
          'studentEmail': studentEmail,
          'from': from,
          'to': to,
          'subject': subject,
          'content': content,
          'department': department,
          'year': year,
          'section': section,
          'image': image ?? '',
        }),
      );

      final data = jsonDecode(response.body);
      return data;
    } catch (e) {
      return {'success': false, 'message': 'Failed to connect to server: $e'};
    }
  }

  /// Get student's OD requests
  static Future<Map<String, dynamic>> getStudentODRequests(String email) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/od-requests/student/$email'),
        headers: {'Content-Type': 'application/json'},
      );

      final data = jsonDecode(response.body);
      return data;
    } catch (e) {
      return {'success': false, 'message': 'Failed to connect to server: $e'};
    }
  }

  /// Get OD requests for staff review
  static Future<Map<String, dynamic>> getStaffODRequests({
    String? department,
    String? year,
    String? section,
  }) async {
    try {
      String queryParams = '';
      if (department != null) queryParams += 'department=$department&';
      if (year != null) queryParams += 'year=$year&';
      if (section != null) queryParams += 'section=$section&';

      final response = await http.get(
        Uri.parse('$baseUrl/od-requests/staff?$queryParams'),
        headers: {'Content-Type': 'application/json'},
      );

      final data = jsonDecode(response.body);
      return data;
    } catch (e) {
      return {'success': false, 'message': 'Failed to connect to server: $e'};
    }
  }

  /// Get OD requests for HOD review
  static Future<Map<String, dynamic>> getHODODRequests({
    String? department,
  }) async {
    try {
      String queryParams = department != null ? 'department=$department' : '';

      final response = await http.get(
        Uri.parse('$baseUrl/od-requests/hod?$queryParams'),
        headers: {'Content-Type': 'application/json'},
      );

      final data = jsonDecode(response.body);
      return data;
    } catch (e) {
      return {'success': false, 'message': 'Failed to connect to server: $e'};
    }
  }

  /// Update OD request staff status
  static Future<Map<String, dynamic>> updateODStaffStatus({
    required String requestId,
    required String status, // 'approved' or 'rejected'
    String? remarks,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/od-requests/$requestId/staff-status'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'status': status, 'remarks': remarks}),
      );

      final data = jsonDecode(response.body);
      return data;
    } catch (e) {
      return {'success': false, 'message': 'Failed to connect to server: $e'};
    }
  }

  /// Update OD request HOD status
  static Future<Map<String, dynamic>> updateODHODStatus({
    required String requestId,
    required String status, // 'approved' or 'rejected'
    String? remarks,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/od-requests/$requestId/hod-status'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'status': status, 'remarks': remarks}),
      );

      final data = jsonDecode(response.body);
      return data;
    } catch (e) {
      return {'success': false, 'message': 'Failed to connect to server: $e'};
    }
  }

  /// Submit Leave Request
  static Future<Map<String, dynamic>> submitLeaveRequest({
    required String studentName,
    required String studentEmail,
    required String from,
    required String to,
    required String subject,
    required String content,
    required String reason,
    required String leaveType,
    required String fromDate,
    required String toDate,
    required int duration,
    required String department,
    required String year,
    required String section,
    String? image,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/leave-requests'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'studentName': studentName,
          'studentEmail': studentEmail,
          'from': from,
          'to': to,
          'subject': subject,
          'content': content,
          'reason': reason,
          'leaveType': leaveType,
          'fromDate': fromDate,
          'toDate': toDate,
          'duration': duration,
          'department': department,
          'year': year,
          'section': section,
          'image': image ?? '',
        }),
      );

      final data = jsonDecode(response.body);
      return data;
    } catch (e) {
      return {'success': false, 'message': 'Failed to connect to server: $e'};
    }
  }

  /// Get student's leave requests
  static Future<Map<String, dynamic>> getStudentLeaveRequests(
    String email,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/leave-requests/student/$email'),
        headers: {'Content-Type': 'application/json'},
      );

      final data = jsonDecode(response.body);
      return data;
    } catch (e) {
      return {'success': false, 'message': 'Failed to connect to server: $e'};
    }
  }

  /// Get leave requests for staff review
  static Future<Map<String, dynamic>> getStaffLeaveRequests({
    String? department,
    String? year,
    String? section,
  }) async {
    try {
      String queryParams = '';
      if (department != null) queryParams += 'department=$department&';
      if (year != null) queryParams += 'year=$year&';
      if (section != null) queryParams += 'section=$section&';

      final response = await http.get(
        Uri.parse('$baseUrl/leave-requests/staff?$queryParams'),
        headers: {'Content-Type': 'application/json'},
      );

      final data = jsonDecode(response.body);
      return data;
    } catch (e) {
      return {'success': false, 'message': 'Failed to connect to server: $e'};
    }
  }

  /// Get leave requests for HOD review
  static Future<Map<String, dynamic>> getHODLeaveRequests({
    String? department,
  }) async {
    try {
      String queryParams = department != null ? 'department=$department' : '';

      final response = await http.get(
        Uri.parse('$baseUrl/leave-requests/hod?$queryParams'),
        headers: {'Content-Type': 'application/json'},
      );

      final data = jsonDecode(response.body);
      return data;
    } catch (e) {
      return {'success': false, 'message': 'Failed to connect to server: $e'};
    }
  }

  /// Update leave request staff status
  static Future<Map<String, dynamic>> updateLeaveStaffStatus({
    required String requestId,
    required String status, // 'approved' or 'rejected'
    String? remarks,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/leave-requests/$requestId/staff-status'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'status': status, 'remarks': remarks}),
      );

      final data = jsonDecode(response.body);
      return data;
    } catch (e) {
      return {'success': false, 'message': 'Failed to connect to server: $e'};
    }
  }

  /// Update leave request HOD status
  static Future<Map<String, dynamic>> updateLeaveHODStatus({
    required String requestId,
    required String status, // 'approved' or 'rejected'
    String? remarks,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/leave-requests/$requestId/hod-status'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'status': status, 'remarks': remarks}),
      );

      final data = jsonDecode(response.body);
      return data;
    } catch (e) {
      return {'success': false, 'message': 'Failed to connect to server: $e'};
    }
  }
}
