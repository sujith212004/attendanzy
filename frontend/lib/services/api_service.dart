import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

/// API Service for Attendanzy Backend
class ApiService {
  // Base URL from centralized config
  static String get baseUrl => ApiConfig.baseUrl;

  /// Login user
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

  /// Submit OD Request
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

  /// Get student's OD requests
  static Future<Map<String, dynamic>> getStudentODRequests(String email) async {
    try {
      print(
        '📡 Fetching OD requests from: $baseUrl/od-requests/student/$email',
      );
      final response = await http
          .get(
            Uri.parse('$baseUrl/od-requests/student/$email'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));

      print('📨 Response status: ${response.statusCode}');
      print('📨 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        print('✅ OD requests parsed successfully');
        
        // Ensure response always has these fields
        return {
          'success': data['success'] ?? true,
          'message': data['message'] ?? '',
          'requests': data['requests'] ?? data['data'] ?? [],
          'count': data['count'] ?? (data['requests'] as List?)?.length ?? 0,
        };
      } else {
        try {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          print('❌ API error: ${response.statusCode} - ${data['message']}');
          return {
            'success': false,
            'message':
                data['message'] ??
                'Failed to fetch OD requests (${response.statusCode})',
            'requests': [],
          };
        } catch (_) {
          return {
            'success': false,
            'message': 'Server error (${response.statusCode}): ${response.body}',
            'requests': [],
          };
        }
      }
    } catch (e) {
      print('❌ Exception fetching OD requests: $e');
      return {
        'success': false,
        'message': 'Failed to connect to server: $e',
        'requests': [],
      };
    }
  }

  /// Get student's leave requests
  static Future<Map<String, dynamic>> getStudentLeaveRequests(
    String email,
  ) async {
    try {
      print(
        '📡 Fetching leave requests from: $baseUrl/leave-requests/student/$email',
      );
      final response = await http
          .get(
            Uri.parse('$baseUrl/leave-requests/student/$email'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));

      print('📨 Response status: ${response.statusCode}');
      print('📨 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        print('✅ Leave requests parsed successfully');
        
        // Ensure response always has these fields
        return {
          'success': data['success'] ?? true,
          'message': data['message'] ?? '',
          'requests': data['requests'] ?? data['data'] ?? [],
          'count': data['count'] ?? (data['requests'] as List?)?.length ?? 0,
        };
      } else {
        try {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          print('❌ API error: ${response.statusCode} - ${data['message']}');
          return {
            'success': false,
            'message':
                data['message'] ??
                'Failed to fetch leave requests (${response.statusCode})',
            'requests': [],
          };
        } catch (_) {
          return {
            'success': false,
            'message': 'Server error (${response.statusCode}): ${response.body}',
            'requests': [],
          };
        }
      }
    } catch (e) {
      print('❌ Exception fetching leave requests: $e');
      return {
        'success': false,
        'message': 'Failed to connect to server: $e',
        'requests': [],
      };
    }
  }

  /// Get OD requests for staff
  static Future<Map<String, dynamic>> getStaffODRequests({
    required String year,
    required String section,
    required String department,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/od-requests/staff').replace(
        queryParameters: {
          'year': year,
          'section': section,
          'department': department,
        },
      );

      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      );

      final data = jsonDecode(response.body);
      return data;
    } catch (e) {
      return {'success': false, 'message': 'Failed to connect to server: $e'};
    }
  }

  /// Update OD Request Status (Staff)
  static Future<Map<String, dynamic>> updateODRequestStatus({
    required String id,
    required String status,
    String? rejectionReason,
    String? staffName,
    String? inchargeName,
    String? year,
    String? section,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/od-requests/$id/staff-status'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'status': status,
          'rejectionReason': rejectionReason,
          'staffName': staffName,
          'inchargeName': inchargeName,
          'year': year,
          'section': section,
        }),
      );

      final data = jsonDecode(response.body);
      return data;
    } catch (e) {
      return {'success': false, 'message': 'Failed to connect to server: $e'};
    }
  }

  /// Get Leave requests for staff
  static Future<Map<String, dynamic>> getStaffLeaveRequests({
    required String year,
    required String section,
    required String department,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/leave-requests/staff').replace(
        queryParameters: {
          'year': year,
          'section': section,
          'department': department,
        },
      );

      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      );

      final data = jsonDecode(response.body);
      return data;
    } catch (e) {
      return {'success': false, 'message': 'Failed to connect to server: $e'};
    }
  }

  /// Update Leave Request Status (Staff)
  static Future<Map<String, dynamic>> updateLeaveRequestStatus({
    required String id,
    required String status,
    String? rejectionReason,
    String? staffName,
    String? inchargeName,
    String? year,
    String? section,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/leave-requests/$id/staff-status'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'status': status,
          'rejectionReason': rejectionReason,
          'staffName': staffName,
          'inchargeName': inchargeName,
          'year': year,
          'section': section,
        }),
      );

      final data = jsonDecode(response.body);
      return data;
    } catch (e) {
      return {'success': false, 'message': 'Failed to connect to server: $e'};
    }
  }

  /// Debug: Check backend health
  static Future<Map<String, dynamic>> checkBackendHealth() async {
    try {
      print('🔍 Checking backend health: $baseUrl/health');
      final response = await http.get(
        Uri.parse('$baseUrl/health'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));

      print('📨 Health check response: ${response.statusCode}');
      print('📨 Body: ${response.body}');

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {
          'success': false,
          'message': 'Backend returned status ${response.statusCode}',
        };
      }
    } catch (e) {
      print('❌ Health check failed: $e');
      return {
        'success': false,
        'message': 'Backend unavailable: $e',
      };
    }
  }

  /// Debug: Check database status
  static Future<Map<String, dynamic>> checkDatabaseStatus() async {
    try {
      print('🔍 Checking database status: $baseUrl/db-status');
      final response = await http.get(
        Uri.parse('$baseUrl/db-status'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));

      print('📨 DB status response: ${response.statusCode}');
      print('📨 Body: ${response.body}');

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {
          'success': false,
          'message': 'DB status check failed: ${response.statusCode}',
        };
      }
    } catch (e) {
      print('❌ DB status check failed: $e');
      return {
        'success': false,
        'message': 'Database status unavailable: $e',
      };
    }
  }
}
