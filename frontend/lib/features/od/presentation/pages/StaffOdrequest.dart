import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/widgets/mac_folder_fullpage.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/config/local_config.dart';

class ODRequestsstaffPage extends StatefulWidget {
  const ODRequestsstaffPage({super.key});

  @override
  State<ODRequestsstaffPage> createState() => _ODRequestsstaffPageState();
}

class _ODRequestsstaffPageState extends State<ODRequestsstaffPage> {
  void _showSnackBar(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  Future<String?> _showRejectionReasonDialog() async {
    final TextEditingController reasonController = TextEditingController();
    return await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(8),
                child: const Icon(
                  Icons.info_outline,
                  color: Color(0xFFEF4444),
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Rejection Reason',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Please provide a reason for rejecting this request.',
                style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                maxLines: 3,
                maxLength: 200,
                decoration: InputDecoration(
                  hintText: 'Enter reason for rejection',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  counterText: '',
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
                autofocus: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              onPressed: () {
                final reason = reasonController.text.trim();
                if (reason.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Rejection reason is required.'),
                      backgroundColor: Color(0xFFEF4444),
                    ),
                  );
                  return;
                }
                Navigator.of(context).pop(reason);
              },
              child: const Text('Reject'),
            ),
          ],
        );
      },
    );
  }

  Future<void> updateStatusWithReason(
    String id,
    String status,
    String rejectionReason,
  ) async {
    setState(() {
      _isUpdating = true; // Show loader
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final staffName =
          prefs.getString('staffName') ?? prefs.getString('name') ?? 'Unknown';
      final inchargeCode =
          prefs.getString('inchargeName') ??
          prefs.getString('incharge') ??
          ''; // e.g., "II-A"

      // Get request details for notification (fetch locally from list)
      final request = requests.firstWhere(
        (r) => r['_id'] == id,
        orElse: () => {},
      );
      final studentEmail = request['studentEmail'] ?? '';
      final studentName =
          request['studentName'] ?? request['name'] ?? 'Student';

      final result = await ApiService.updateODRequestStatus(
        id: id,
        status: status,
        rejectionReason: rejectionReason,
        staffName: staffName,
        inchargeName: inchargeCode,
        year: selectedYear,
        section: selectedSection,
      );

      if (result['success']) {
        // Send notification
        _sendNotificationWithRetry(
          studentEmail: studentEmail,
          studentName: studentName,
          requestType: 'OD',
          status: status,
          requestId: id,
          approverRole: 'staff',
        );

        await fetchRequests();
        _showSnackBar(
          'Request $status successfully',
          status == 'rejected' ? Colors.red : Colors.green,
        );
      } else {
        _showSnackBar(
          result['message'] ?? 'Failed to update request',
          Colors.red,
        );
      }
    } catch (e) {
      _showSnackBar('Error updating request: $e', Colors.red);
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false; // Hide loader
        });
      }
    }
  }

  Future<void> _sendNotificationWithRetry({
    required String studentEmail,
    required String studentName,
    required String requestType,
    required String status,
    required String requestId,
    required String approverRole,
  }) async {
    const int maxRetries = 2;
    const Duration initialDelay = Duration(seconds: 2);

    // Construct notification content
    final statusText = status.toLowerCase();
    String title;
    String body;

    // Staff logic
    if (statusText == 'approved' ||
        statusText == 'accepted' ||
        statusText == 'forwarded') {
      title = '$requestType Request Forwarded';
      body =
          'Hi $studentName, your ${requestType.toLowerCase()} request has been forwarded to HOD for final approval.';
    } else if (statusText == 'rejected') {
      title = '$requestType Request Rejected';
      body =
          'Hi $studentName, your ${requestType.toLowerCase()} request has been rejected by Staff.';
    } else {
      title = '$requestType Request Update';
      body =
          'Hi $studentName, your ${requestType.toLowerCase()} request status has been updated by Staff.';
    }

    for (int i = 0; i < maxRetries; i++) {
      try {
        final notifUrl = Uri.parse(
          '${LocalConfig.apiBaseUrl}/notifications/send-notification',
        );

        await http
            .post(
              notifUrl,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'studentEmail': studentEmail,
                'title': title,
                'body': body,
                'data': {
                  'type': 'status_update',
                  'requestType': requestType,
                  'status': status,
                  'requestId': requestId,
                  'approverRole': approverRole,
                },
              }),
            )
            .timeout(const Duration(seconds: 5));

        if (kDebugMode) print('Notification request sent for $requestId');
        return;
      } catch (e) {
        if (kDebugMode) print('Notification attempt ${i + 1} failed: $e');
        if (i < maxRetries - 1) {
          await Future.delayed(initialDelay);
        }
      }
    }
  }

  List<Map<String, dynamic>> requests = [];
  bool loading = true;
  bool _isUpdating = false; // Add loader state for updates
  String? error;
  String? hodDepartment;
  String? selectedYear;
  String? selectedSection;
  String? selectedDepartment;

  // Filter options
  final List<String> _statusFilterOptions = [
    'All',
    'Pending',
    'Accepted',
    'Rejected',
  ];
  String _selectedStatusFilter = 'Pending';

  List<Map<String, dynamic>> _getFilteredRequests() {
    if (_selectedStatusFilter == 'All') {
      return requests;
    }

    final filtered =
        requests.where((req) {
          // Get staffStatus and normalize to lowercase
          final staffStatusRaw = req['staffStatus'];
          String staffStatus = '';

          if (staffStatusRaw != null &&
              staffStatusRaw.toString().trim().isNotEmpty) {
            staffStatus = staffStatusRaw.toString().toLowerCase().trim();
          } else {
            // If no staffStatus, default to pending
            staffStatus = 'pending';
          }

          if (kDebugMode) {
            print(
              'Filtering: ID=${req['_id']}, staffStatus="$staffStatus" (raw: "$staffStatusRaw"), selectedFilter=$_selectedStatusFilter',
            );
          }

          // Match filter with status - case insensitive
          bool matches = false;
          switch (_selectedStatusFilter) {
            case 'Pending':
              matches = (staffStatus == 'pending' || staffStatus == '');
              break;
            case 'Accepted':
              matches = (staffStatus == 'accepted');
              break;
            case 'Rejected':
              matches = (staffStatus == 'rejected');
              break;
          }

          if (kDebugMode && matches) {
            print('  ✓ MATCHED: $staffStatus matches $_selectedStatusFilter');
          }
          return matches;
        }).toList();

    if (kDebugMode) {
      print(
        '\nFilter result: ${filtered.length} items for $_selectedStatusFilter',
      );
      print('Filtered IDs:');
      for (var req in filtered) {
        print('  - ${req['_id']}: ${req['staffStatus']}');
      }
      print('');
    }
    return filtered;
  }

  @override
  void initState() {
    super.initState();
    _loadStaffDetailsAndFetchRequests();
  }

  Future<void> _loadStaffDetailsAndFetchRequests() async {
    final prefs = await SharedPreferences.getInstance();
    selectedYear = prefs.getString("year");
    // Try both 'section' and 'sec' keys
    selectedSection = prefs.getString("section") ?? prefs.getString("sec");
    selectedDepartment = prefs.getString("department");
    print(
      "DEBUG: Loaded year: $selectedYear, section: $selectedSection (section: ${prefs.getString('section')}, sec: ${prefs.getString('sec')}), department: $selectedDepartment",
    );
    await fetchRequests();
  }

  Future<void> fetchRequests() async {
    if (!mounted) return;
    setState(() {
      loading = true;
      error = null;
    });

    try {
      // Normalize year and section for robust matching
      String? normYear = selectedYear?.trim();
      String? normSection = selectedSection?.trim();

      if (normYear != null && normSection != null) {
        final result = await ApiService.getStaffODRequests(
          year: normYear,
          section: normSection,
          department: selectedDepartment ?? '',
        );

        if (result['success']) {
          if (mounted) {
            setState(() {
              loading = false;
              if (result['data'] != null) {
                requests = List<Map<String, dynamic>>.from(result['data']);
              } else {
                requests = [];
              }
            });
          }
        } else {
          throw Exception(result['message'] ?? 'Failed to fetch requests');
        }
      } else {
        setState(() {
          loading = false;
          requests = [];
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e.toString();
          loading = false;
        });
      }
    }
  }

  Future<void> updateStatus(String id, String status) async {
    if (status.toLowerCase() == 'rejected') {
      // Show rejection reason dialog and pass to updateStatusWithReason
      final reason = await _showRejectionReasonDialog();
      if (reason == null || reason.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Rejection cancelled - reason required'),
            ),
          );
        }
        return;
      }
      await updateStatusWithReason(id, status, reason);
      return;
    }
    // For accept, always use updateStatusWithReason to set all metadata
    await updateStatusWithReason(id, status, '');
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'pending':
        return const Color(0xFFF59E0B);
      case 'accepted':
        return const Color(0xFF10B981);
      case 'rejected':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF6B7280);
    }
  }

  Color _getStatusBackgroundColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'pending':
        return const Color(0xFFFEF3C7);
      case 'accepted':
        return const Color(0xFFD1FAE5);
      case 'rejected':
        return const Color(0xFFFEE2E2);
      default:
        return const Color(0xFFF3F4F6);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'OD Request Management',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: Color(0xFF1E293B),
          ),
        ),
        centerTitle: false,
        backgroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        toolbarHeight: 70,
        leadingWidth: 60,
        leading: Container(
          margin: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF3B82F6).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF3B82F6).withOpacity(0.2),
              width: 1,
            ),
          ),
          child: IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(
              Icons.arrow_back_ios_new,
              color: Color(0xFF3B82F6),
              size: 18,
            ),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFE2E8F0)),
        ),
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            color: const Color(0xFF3B82F6),
            backgroundColor: Colors.white,
            onRefresh: fetchRequests,
            child:
                loading
                    ? _buildLoadingState()
                    : requests.isEmpty
                    ? _buildEmptyState()
                    : MacFolderFullPage(
                      title: 'OD Request Management',
                      acceptedLabel: 'Accepted',
                      pendingCount:
                          requests.where((req) {
                            final staffStatusRaw =
                                (req['staffStatus'] ?? 'pending')
                                    .toString()
                                    .toLowerCase()
                                    .trim();
                            final mainStatus =
                                (req['status'] ?? '').toString().toLowerCase();
                            final rejectionReason =
                                (req['rejectionReason'] ?? '')
                                    .toString()
                                    .trim();
                            // Not pending if rejected or accepted/approved
                            if (rejectionReason.isNotEmpty ||
                                mainStatus == 'rejected')
                              return false;
                            if (staffStatusRaw == 'accepted' ||
                                staffStatusRaw == 'approved' ||
                                mainStatus == 'accepted')
                              return false;

                            return staffStatusRaw == 'pending' ||
                                staffStatusRaw == '';
                          }).length,
                      acceptedCount:
                          requests.where((req) {
                            final staffStatusRaw =
                                (req['staffStatus'] ?? '')
                                    .toString()
                                    .toLowerCase()
                                    .trim();
                            final mainStatus =
                                (req['status'] ?? '').toString().toLowerCase();
                            final rejectionReason =
                                (req['rejectionReason'] ?? '')
                                    .toString()
                                    .trim();
                            // Not accepted if rejected
                            if (rejectionReason.isNotEmpty ||
                                mainStatus == 'rejected')
                              return false;
                            return staffStatusRaw == 'accepted' ||
                                staffStatusRaw == 'approved' ||
                                mainStatus == 'accepted';
                          }).length,
                      rejectedCount:
                          requests.where((req) {
                            final mainStatus =
                                (req['status'] ?? '').toString().toLowerCase();
                            final rejectionReason =
                                (req['rejectionReason'] ?? '')
                                    .toString()
                                    .trim();
                            final staffStatusRaw =
                                (req['staffStatus'] ?? '')
                                    .toString()
                                    .toLowerCase()
                                    .trim();
                            return rejectionReason.isNotEmpty ||
                                mainStatus == 'rejected' ||
                                staffStatusRaw == 'rejected';
                          }).length,
                      allRequests: requests,
                      loading: loading,
                      onRefresh: fetchRequests,
                      getStatusFromRequest: (req) {
                        final staffStatusRaw =
                            (req['staffStatus'] ?? 'pending')
                                .toString()
                                .toLowerCase()
                                .trim();
                        final mainStatus =
                            (req['status'] ?? '').toString().toLowerCase();
                        final rejectionReason =
                            (req['rejectionReason'] ?? '').toString().trim();

                        if (rejectionReason.isNotEmpty ||
                            mainStatus == 'rejected') {
                          return 'rejected';
                        } else if (staffStatusRaw == 'accepted' ||
                            staffStatusRaw == 'approved' ||
                            mainStatus == 'accepted') {
                          return 'accepted';
                        }
                        return staffStatusRaw.isEmpty
                            ? 'pending'
                            : staffStatusRaw;
                      },
                      requestCardBuilder: (req) => _buildRequestCard(req),
                    ),
          ),
          if (_isUpdating)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
              strokeWidth: 2.5,
            ),
            SizedBox(height: 16),
            Text(
              'Loading Requests...',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Fetching OD requests from database',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.error_outline,
                size: 32,
                color: Color(0xFFEF4444),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Error Loading Requests',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: fetchRequests,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
                shadowColor: Colors.transparent,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFF64748B).withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.inbox_outlined,
                size: 32,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No OD Requests',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'No requests found for your department',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
        return Icons.check_circle_outline;
      case 'rejected':
        return Icons.cancel_outlined;
      case 'pending':
      default:
        return Icons.schedule_outlined;
    }
  }

  Widget _buildRequestCard(Map<String, dynamic> req) {
    // Determine the correct status
    String status;
    final String staffStatusRaw =
        (req['staffStatus'] ?? 'pending').toString().toLowerCase();
    final String mainStatus = (req['status'] ?? '').toString().toLowerCase();
    final String rejectionReason =
        (req['rejectionReason'] ?? '').toString().trim();

    if (rejectionReason.isNotEmpty || mainStatus == 'rejected') {
      status = 'rejected';
    } else if (staffStatusRaw == 'accepted' ||
        staffStatusRaw == 'approved' ||
        mainStatus == 'accepted') {
      status = 'accepted';
    } else {
      status = staffStatusRaw.isEmpty ? 'pending' : staffStatusRaw;
    }

    final subject = req['subject'] ?? 'OD Request';
    final fromDate = req['from'] ?? 'N/A';
    final toDate = req['to'] ?? 'N/A';
    final studentName = req['name'] ?? 'Student';
    final bool isPending = status == 'pending';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color:
              isPending
                  ? _getStatusColor(status).withOpacity(0.3)
                  : const Color(0xFFE2E8F0),
          width: isPending ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color:
                isPending
                    ? _getStatusColor(status).withOpacity(0.1)
                    : Colors.black.withOpacity(0.04),
            blurRadius: isPending ? 12 : 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap:
              () => showDialog(
                context: context,
                builder: (context) => _buildFullScreenDialog(req),
              ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  _getStatusColor(status).withOpacity(0.08),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.15],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Row with Avatar
                  Row(
                    children: [
                      // Student Avatar
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              _getStatusColor(status),
                              _getStatusColor(status).withOpacity(0.7),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: _getStatusColor(status).withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            studentName.isNotEmpty
                                ? studentName[0].toUpperCase()
                                : 'S',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              studentName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: Color(0xFF1E293B),
                                letterSpacing: 0.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              subject,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: Color(0xFF64748B),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      // Status Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusBackgroundColor(status),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _getStatusColor(status).withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getStatusIcon(status),
                              size: 14,
                              color: _getStatusColor(status),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              status.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: _getStatusColor(status),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Date Range Bar
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFE2E8F0),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF3B82F6,
                                  ).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.login_rounded,
                                  size: 16,
                                  color: Color(0xFF3B82F6),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'From',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF94A3B8),
                                      ),
                                    ),
                                    Text(
                                      fromDate,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF1E293B),
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Icon(
                            Icons.arrow_forward_rounded,
                            size: 18,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    const Text(
                                      'To',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF94A3B8),
                                      ),
                                    ),
                                    Text(
                                      toDate,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF1E293B),
                                      ),
                                      textAlign: TextAlign.end,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF8B5CF6,
                                  ).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.logout_rounded,
                                  size: 16,
                                  color: Color(0xFF8B5CF6),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Reason Preview
                  if (req['reason'] != null &&
                      req['reason'].toString().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFFE2E8F0),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.notes_rounded,
                            size: 16,
                            color: const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              req['reason'].toString(),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF475569),
                                height: 1.4,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Quick Action for Pending
                  if (isPending) ...[
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.touch_app_rounded,
                                  size: 16,
                                  color: const Color(0xFF64748B),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Tap to Review',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFullScreenDialog(Map<String, dynamic> req) {
    // Determine the correct status by checking multiple fields
    // Priority: 1) If rejectionReason exists -> rejected, 2) If status is rejected -> rejected, 3) Use staffStatus
    final String staffStatusRaw =
        (req['staffStatus'] ?? 'pending').toString().toLowerCase();
    final String mainStatus = (req['status'] ?? '').toString().toLowerCase();
    final String rejectionReason =
        (req['rejectionReason'] ?? '').toString().trim();

    String staffStatus;
    if (rejectionReason.isNotEmpty || mainStatus == 'rejected') {
      staffStatus = 'rejected';
    } else if (staffStatusRaw == 'accepted' ||
        staffStatusRaw == 'approved' ||
        mainStatus == 'accepted') {
      staffStatus = 'accepted';
    } else {
      staffStatus = staffStatusRaw.isEmpty ? 'pending' : staffStatusRaw;
    }

    // We use a StatefulBuilder to manage the loading state locally within the dialog
    bool isLoading = false;

    return StatefulBuilder(
      builder: (context, setState) {
        return Dialog.fullscreen(
          child: Scaffold(
            backgroundColor: const Color(0xFFFAFBFC),
            appBar: AppBar(
              title: const Text(
                'Request Details',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1F2937),
                ),
              ),
              backgroundColor: Colors.white,
              elevation: 0,
              leading: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, color: Color(0xFF1F2937)),
              ),
              actions: [
                Container(
                  margin: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusBackgroundColor(staffStatus),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    staffStatus.toUpperCase(),
                    style: TextStyle(
                      color: _getStatusColor(staffStatus),
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Container(height: 1, color: const Color(0xFFE5E7EB)),
              ),
            ),
            body: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: _buildLetterContent(req),
                  ),
                ),
                _buildActionButtons(
                  staffStatus,
                  req,
                  isLoading: isLoading,
                  onLoadingChanged: (val) {
                    setState(() {
                      isLoading = val;
                    });
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLetterContent(Map<String, dynamic> req) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDialogDetailRow(
            Icons.calendar_today_outlined,
            "From",
            req['from'] ?? 'N/A',
          ),
          const SizedBox(height: 16),
          _buildDialogDetailRow(Icons.event_outlined, "To", req['to'] ?? 'N/A'),
          const SizedBox(height: 16),
          _buildDialogDetailRow(
            Icons.access_time_outlined,
            "Date Submitted",
            req['createdAt'] != null ? req['createdAt'].split('T')[0] : 'N/A',
          ),
          const SizedBox(height: 16),
          // Show forwarding metadata if present
          if (req['forwardedBy'] != null)
            _buildDialogDetailRow(
              Icons.forward_to_inbox,
              "Forwarded By",
              req['forwardedBy'] ?? 'Unknown',
            ),
          if (req['forwardedByIncharge'] != null)
            _buildDialogDetailRow(
              Icons.account_box_outlined,
              "Class Incharge",
              req['forwardedByIncharge'] ?? 'Unknown',
            ),
          if (req['forwardedAt'] != null)
            _buildDialogDetailRow(
              Icons.schedule,
              "Forwarded At",
              req['forwardedAt']
                  .toString()
                  .replaceFirst('T', ' ')
                  .split('.')
                  .first,
            ),
          if (req['year'] != null)
            _buildDialogDetailRow(Icons.school, "Year", req['year'].toString()),
          if (req['section'] != null)
            _buildDialogDetailRow(
              Icons.group,
              "Section",
              req['section'].toString(),
            ),

          // Show rejection reason if present
          if (req['rejectionReason'] != null &&
              (req['rejectionReason'] as String).trim().isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.red.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: Colors.red,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Rejection Reason',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    req['rejectionReason'],
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            height: 1,
            color: const Color(0xFFE2E8F0),
          ),
          const SizedBox(height: 24),

          Text(
            req['subject'] ?? 'No Subject Provided',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            req['content'] ?? 'No content provided.',
            style: const TextStyle(
              fontSize: 15,
              height: 1.6,
              color: Color(0xFF475569),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 20),
          if (req['image'] != null && req['image'].toString().isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Proof Attached:",
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(base64Decode(req['image'])),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildDialogDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF3B82F6).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: const Color(0xFF3B82F6)),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(
    String status,
    Map<String, dynamic> req, {
    bool isLoading = false,
    ValueChanged<bool>? onLoadingChanged,
  }) {
    // We need to define isLoading inside the builder if we want it to update
    // But since we are passing it from the parent, we rely on parent rebuild.
    // However, StatefulBuilder builder provides a setState that only rebuilds its child.
    // So the isLoading variable must be defined OUTSIDE the builder if we were using it there,
    // but here we are using the passed parameters.
    // The previous tool call wrapped the validation in StatefulBuilder and passed `isLoading` (which was local to that builder?). Not quite.
    // Wait, the previous tool call defined `bool isLoading = false;` INSIDE the builder.
    // That means `isLoading` resets to false on every rebuild of the StatefulBuilder?
    // No, `StatefulBuilder`'s builder is called only once initially? No, it's called on setState.
    // Actually, `StatefulBuilder` doesn't hold state across its own rebuilds if the state variable is defined inside the builder function.
    // It needs to be defined outside? Or `StatefulBuilder` creates a context for `setState`.
    // The boolean variable `isLoading` should be held in the state of `_buildFullScreenDialog` if it were a widget,
    // or we can't persist it inside `builder`.
    //
    // WAIT. `StatefulBuilder` builder signature is `Widget Function(BuildContext, StateSetter)`.
    // If I define `bool isLoading = false;` inside the builder, it initializes to false.
    // When I call `setState(() { isLoading = true; })`, it triggers a rebuild of the builder.
    // The builder runs again. `bool isLoading = false;` executes again. `isLoading` becomes false.
    // This is a common mistake.
    //
    // Verification:
    // If I use `StatefulBuilder`, I should usually wrap a widget that holds the state, or the state variable should be outside.
    // But `_buildFullScreenDialog` is a method, not a class.
    // So I should define `bool isLoading = false;` *outside* the `StatefulBuilder`?
    // If I define it outside, it's a local variable of `_buildFullScreenDialog`.
    // `StatefulBuilder`'s `setState` won't update the local variable of the surrounding function?
    // Actually, closures capture variables.
    //
    // Let's correct `_buildFullScreenDialog` logic in the NEXT step if I messed up (I suspect I might have, but let's see).
    // Actually, if I defined it inside, it is definitely wrong.
    //
    // I will fix `_buildFullScreenDialog` and `_buildActionButtons` together here? No, I can't edit the same file in parallel overlapping regions easily or I might have race conditions if I didn't wait.
    // But I already sent the previous tool call.
    // If I made a mistake in the previous tool call, I need to fix it.
    //
    // Let's assume I need to fix `_buildActionButtons` now.
    // AND I should fix the `StatefulBuilder` usage.
    //
    // Actually, I can use a separate widget class for the dialog to be safe, OR:
    // Define `bool isLoading = false;` *before* `return StatefulBuilder(...)`.
    // And inside `StatefulBuilder`, I use that variable.
    // Since `isLoading` is captured by the closure, `setState` will trigger a rebuild, and the builder uses the captured variable.
    //
    // Wait, the Previous tool call:
    // ```dart
    //     // We use a StatefulBuilder...
    //     return StatefulBuilder(
    //       builder: (context, setState) {
    //         bool isLoading = false; // <--- ERROR: This resets it every time.
    //         return Dialog.fullscreen(...
    // ```
    // Yes, that is an error.
    //
    // I need to correct `_buildFullScreenDialog` FIRST or ALONG with `_buildActionButtons`.
    // Since I'm editing `_buildActionButtons` (lines 1404-1506), I can't touch lines 1130-1203 in the same atomic `replace_file_content` call?
    // Actually `multi_replace_file_content` exists! I should use that.
    //
    // But I already issued a `replace_file_content` for `_buildFullScreenDialog` in the previous step.
    // So the file *currently* has the bug.
    // I need to fix it.
    //
    // I will simply perform a `replace_file_content` on `_buildFullScreenDialog` AGAIN to fix the variable scope,
    // AND then update `_buildActionButtons`.
    // OR better, do both in one `multi_replace_file_content`.
    //
    // Actually, I am in the prompt *after* the previous tool call.
    // So the previous tool call *has happened*.
    // I will fix the `isLoading` placement in `_buildFullScreenDialog` AND update `_buildActionButtons` using `multi_replace_file_content`.

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(
          top: BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, -4),
            blurRadius: 16,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              icon:
                  isLoading
                      ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                      : const Icon(Icons.check_circle_outline, size: 20),
              label: Text(
                isLoading ? 'Processing...' : 'Forward to HOD',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onPressed:
                  (status == 'pending' && !isLoading)
                      ? () async {
                        onLoadingChanged?.call(true);
                        await updateStatus(req['_id'].toString(), 'accepted');
                        if (mounted) {
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Forwarded to HOD!'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        }
                      }
                      : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
                shadowColor: Colors.transparent,
                disabledBackgroundColor: const Color(0xFFE2E8F0),
                disabledForegroundColor: const Color(0xFF64748B),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton.icon(
              icon:
                  isLoading
                      ? const SizedBox.shrink()
                      : const Icon(Icons.cancel_outlined, size: 20),
              label: const Text(
                'Reject',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              onPressed:
                  (status == 'pending' && !isLoading)
                      ? () async {
                        final reason = await _showRejectionReasonDialog();
                        if (reason != null && reason.isNotEmpty) {
                          onLoadingChanged?.call(true);
                          await updateStatusWithReason(
                            req['_id'].toString(),
                            'rejected',
                            reason,
                          );
                          if (mounted) {
                            Navigator.of(context).pop();
                          }
                        }
                      }
                      : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
                shadowColor: Colors.transparent,
                disabledBackgroundColor: const Color(0xFFE2E8F0),
                disabledForegroundColor: const Color(0xFF64748B),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
