import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/widgets/mac_folder_fullpage.dart';
import '../../../../core/services/api_service.dart';

class LeaveRequestsStaffPage extends StatefulWidget {
  const LeaveRequestsStaffPage({super.key});

  @override
  State<LeaveRequestsStaffPage> createState() => _LeaveRequestsStaffPageState();
}

class _LeaveRequestsStaffPageState extends State<LeaveRequestsStaffPage> {
  List<Map<String, dynamic>> requests = [];
  bool loading = true;
  bool _isUpdating = false;
  String? error;
  String? hodDepartment;
  String? selectedYear;
  String? selectedSection;
  String? selectedDepartment;

  // Filter options
  final List<String> _statusFilterOptions = [
    'All',
    'Pending',
    'Approved',
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
            case 'Approved':
              matches = (staffStatus == 'approved');
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
    print(
      "DEBUG: Loaded year: $selectedYear, section: $selectedSection (section: ${prefs.getString('section')}, sec: ${prefs.getString('sec')})",
    );

    if (selectedYear == null || selectedSection == null) {
      setState(() {
        error = "Year or Section not found for staff.";
        loading = false;
      });
      return;
    }

    await fetchRequests();
  }

  Future<void> fetchRequests() async {
    if (!mounted) return;
    setState(() {
      loading = true;
      error = null;
    });

    try {
      String? normYear = selectedYear?.trim();
      String? normSection = selectedSection?.trim();

      if (normYear != null && normSection != null) {
        final result = await ApiService.getStaffLeaveRequests(
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
      final reason = await _showRejectionReasonDialog();
      if (reason == null || reason.isEmpty) {
        _showSnackBar('Rejection cancelled. Reason required.', Colors.red);
        return;
      }
      await updateStatusWithReason(id, status, reason);
      return;
    }
    await updateStatusWithReason(id, status, '');
  }

  Future<void> updateStatusWithReason(
    String id,
    String status,
    String rejectionReason,
  ) async {
    setState(() {
      _isUpdating = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final staffName =
          prefs.getString('staffName') ?? prefs.getString('name') ?? 'Unknown';
      final inchargeCode =
          prefs.getString('inchargeName') ?? prefs.getString('incharge') ?? '';

      final result = await ApiService.updateLeaveRequestStatus(
        id: id,
        status: status,
        rejectionReason: rejectionReason,
        staffName: staffName,
        inchargeName: inchargeCode,
        year: selectedYear,
        section: selectedSection,
      );

      if (result['success']) {
        await fetchRequests();
        _showSnackBar(
          'Leave request $status successfully',
          status == 'rejected' ? Colors.red : Colors.green,
        );
      } else {
        _showSnackBar(
          result['message'] ?? 'Failed to update leave request',
          Colors.red,
        );
      }
    } catch (e) {
      _showSnackBar('Error updating leave request: $e', Colors.red);
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  Future<String?> _showRejectionReasonDialog() async {
    TextEditingController controller = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.all(10),
                      child: const Icon(
                        Icons.info_outline,
                        color: Colors.red,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Text(
                        'Rejection Reason',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 20,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                const Text(
                  'Please provide a reason for rejecting this leave request. This will be visible to the student.',
                  style: TextStyle(fontSize: 14, color: Color(0xFF4B5563)),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: controller,
                  autofocus: true,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Enter reason for rejection',
                    filled: true,
                    fillColor: const Color(0xFFF3F4F6),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFF667EEA),
                        width: 2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 26),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(null),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF6B7280),
                        textStyle: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () {
                        final reason = controller.text.trim();
                        if (reason.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please enter a rejection reason'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }
                        Navigator.of(context).pop(reason);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEF4444),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        textStyle: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      child: const Text('Submit'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

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

  String _formatDate(dynamic date) {
    if (date == null) return 'N/A';

    try {
      DateTime parsedDate;
      if (date is String) {
        parsedDate = DateTime.parse(date);
      } else if (date is DateTime) {
        parsedDate = date;
      } else {
        return 'Invalid Date';
      }

      return '${parsedDate.day.toString().padLeft(2, '0')}/'
          '${parsedDate.month.toString().padLeft(2, '0')}/'
          '${parsedDate.year}';
    } catch (e) {
      return 'Invalid Date';
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'pending':
      default:
        return Colors.orange;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      case 'pending':
      default:
        return Icons.pending;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'Leave Requests Management',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
        ),
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: fetchRequests,
            child:
                loading
                    ? const Center(child: CircularProgressIndicator())
                    : error != null
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 64,
                            color: Colors.red.withOpacity(0.6),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            error!,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 16,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: fetchRequests,
                            icon: const Icon(Icons.refresh, size: 18),
                            label: const Text('Try Again'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF667EEA),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                    : MacFolderFullPage(
                      title: 'Leave Request Management',
                      acceptedLabel: 'Approved',
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

                            if (rejectionReason.isNotEmpty ||
                                mainStatus == 'rejected')
                              return false;
                            if (staffStatusRaw == 'approved' ||
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

                            if (rejectionReason.isNotEmpty ||
                                mainStatus == 'rejected')
                              return false;
                            return staffStatusRaw == 'approved' ||
                                staffStatusRaw == 'accepted' ||
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
                            mainStatus == 'rejected')
                          return 'rejected';
                        if (staffStatusRaw == 'approved' ||
                            staffStatusRaw == 'accepted' ||
                            mainStatus == 'accepted')
                          return 'approved';
                        return staffStatusRaw.isEmpty
                            ? 'pending'
                            : staffStatusRaw;
                      },
                      requestCardBuilder: (req) => _buildLeaveRequestCard(req),
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

  Widget _buildLeaveRequestCard(Map<String, dynamic> request) {
    // Use staffStatus for filtering display, not HOD status
    final String staffStatus =
        (request['staffStatus'] ?? 'pending').toString().toLowerCase();
    final String status = staffStatus; // Use staff decision for display
    final String studentName =
        (request['name'] != null &&
                request['name'].toString().trim().isNotEmpty)
            ? request['name']
            : (request['studentName'] != null &&
                request['studentName'].toString().trim().isNotEmpty)
            ? request['studentName']
            : 'Unknown';
    final String studentEmail = request['studentEmail'] ?? 'No email';
    final String studentClass = request['class'] ?? 'N/A';
    final String studentYear = request['year'] ?? 'N/A';
    final String leaveType = request['leaveType'] ?? 'N/A';
    final String fromDate = _formatDate(request['fromDate']);
    final String toDate = _formatDate(request['toDate']);
    final int duration =
        (request['duration'] is int)
            ? request['duration']
            : int.tryParse(request['duration']?.toString() ?? '0') ?? 0;

    // Format submission time
    String? createdAtStr = request['createdAt'];
    String submissionTime = 'Unknown';
    if (createdAtStr != null && createdAtStr.isNotEmpty) {
      try {
        final dt = DateTime.parse(createdAtStr);
        submissionTime =
            '${dt.day.toString().padLeft(2, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.year}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      } catch (e) {
        submissionTime = createdAtStr;
      }
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap:
              () => showDialog(
                context: context,
                builder: (context) => _buildFullScreenDialog(request),
              ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border(
                left: BorderSide(color: _getStatusColor(status), width: 4),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Submission Time Row
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 18,
                        color: Color(0xFF64748B),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Submitted: $submissionTime',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 10),
                  // Header Row
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: _getStatusColor(status).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _getStatusColor(status).withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Icon(
                          _getStatusIcon(status),
                          color: _getStatusColor(status),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$leaveType Request - $studentName',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 18,
                                color: Color(0xFF1E293B),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _getStatusBackgroundColor(status),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                status.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: _getStatusColor(status),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Student Details
                  _buildDetailRow(
                    Icons.person_outline,
                    'Student Name',
                    studentName,
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow(
                    Icons.email_outlined,
                    'Student Email',
                    studentEmail,
                  ),
                  // const SizedBox(height: 12),
                  // _buildDetailRow(Icons.class_outlined, 'Class', studentClass),
                  const SizedBox(height: 12),
                  _buildDetailRow(
                    Icons.calendar_today_outlined,
                    'Year',
                    studentYear,
                  ),
                  const SizedBox(height: 20),
                  // Request Details
                  _buildDetailRow(
                    Icons.calendar_today_outlined,
                    'From Date',
                    fromDate,
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow(Icons.event_outlined, 'To Date', toDate),
                  const SizedBox(height: 12),
                  _buildDetailRow(
                    Icons.timer_outlined,
                    'Duration',
                    '$duration day${duration != 1 ? 's' : ''}',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFF64748B).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: const Color(0xFF64748B)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _getStatusBackgroundColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Colors.green.withOpacity(0.1);
      case 'rejected':
        return Colors.red.withOpacity(0.1);
      case 'pending':
        return Colors.orange.withOpacity(0.1);
      default:
        return Colors.grey.withOpacity(0.1);
    }
  }

  Widget _buildFullScreenDialog(Map<String, dynamic> request) {
    // Use staffStatus to determine if buttons should be shown
    final staffStatus =
        (request['staffStatus'] ?? 'pending').toString().toLowerCase();
    return Dialog.fullscreen(
      child: Scaffold(
        backgroundColor: const Color(0xFFFAFBFC),
        appBar: AppBar(
          title: const Text(
            'Leave Request Details',
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                child: _buildLeaveLetterContent(request),
              ),
            ),
            _buildLeaveActionButtons(staffStatus, request),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaveLetterContent(Map<String, dynamic> request) {
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
            Icons.person_outline,
            "Student Name",
            request['studentName'] ?? 'Unknown',
          ),
          const SizedBox(height: 16),
          _buildDialogDetailRow(
            Icons.email_outlined,
            "Student Email",
            request['studentEmail'] ?? 'No email',
          ),
          const SizedBox(height: 16),
          _buildDialogDetailRow(
            Icons.medical_services_outlined,
            "Leave Type",
            request['leaveType'] ?? 'N/A',
          ),
          const SizedBox(height: 16),
          _buildDialogDetailRow(
            Icons.calendar_today_outlined,
            "From Date",
            _formatDate(request['fromDate']),
          ),
          const SizedBox(height: 16),
          _buildDialogDetailRow(
            Icons.event_outlined,
            "To Date",
            _formatDate(request['toDate']),
          ),
          const SizedBox(height: 16),
          _buildDialogDetailRow(
            Icons.timer_outlined,
            "Duration",
            '${request['duration'] ?? 0} day${(request['duration'] ?? 0) != 1 ? 's' : ''}',
          ),
          const SizedBox(height: 16),
          _buildDialogDetailRow(
            Icons.access_time_outlined,
            "Date Submitted",
            request['createdAt'] != null
                ? request['createdAt'].toString().split('T')[0]
                : 'N/A',
          ),
          const SizedBox(height: 16),
          // Show forwarding metadata if present
          if (request['forwardedBy'] != null)
            _buildDialogDetailRow(
              Icons.forward_to_inbox,
              "Forwarded By",
              request['forwardedBy'] ?? 'Unknown',
            ),
          if (request['forwardedByIncharge'] != null)
            _buildDialogDetailRow(
              Icons.account_box_outlined,
              "Class Incharge",
              request['forwardedByIncharge'] ?? 'Unknown',
            ),
          if (request['forwardedAt'] != null)
            _buildDialogDetailRow(
              Icons.schedule,
              "Forwarded At",
              request['forwardedAt']
                  .toString()
                  .replaceFirst('T', ' ')
                  .split('.')
                  .first,
            ),
          if (request['year'] != null)
            _buildDialogDetailRow(
              Icons.school,
              "Year",
              request['year'].toString(),
            ),
          if (request['section'] != null)
            _buildDialogDetailRow(
              Icons.group,
              "Section",
              request['section'].toString(),
            ),

          if (request['rejectionReason'] != null &&
              (request['rejectionReason'] as String).trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 20, bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, color: Colors.red, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Rejection Reason: ${request['rejectionReason']}',
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            height: 1,
            color: const Color(0xFFE2E8F0),
          ),
          const SizedBox(height: 24),

          Text(
            'Leave Application - ${request['leaveType'] ?? 'Leave Request'}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            request['reason'] ?? 'No reason provided',
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF4B5563),
              height: 1.6,
            ),
          ),
          const SizedBox(height: 24),

          const SizedBox(height: 12),
          if (request['image'] != null &&
              request['image'].toString().isNotEmpty)
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
                  child: Image.memory(
                    base64Decode(request['image'].toString()),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildDialogDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF3B82F6).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
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
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1F2937),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLeaveActionButtons(String status, Map<String, dynamic> request) {
    // Handle both MongoDB ObjectId and String ID from API
    final requestId = request['_id'].toString();

    if (status.toLowerCase() == 'pending') {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE5E7EB), width: 1)),
        ),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () async {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Processing rejection...'),
                      duration: Duration(milliseconds: 500),
                    ),
                  );
                  // Call updateStatus which handles the dialog internally
                  await updateStatus(requestId, 'rejected');
                },
                icon: const Icon(Icons.close, size: 18),
                label: const Text('Reject'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Forwarding to HOD...'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                  Future.delayed(const Duration(milliseconds: 300), () {
                    updateStatus(requestId, 'approved');
                  });
                },
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Forward to HOD'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE5E7EB), width: 1)),
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: _getStatusBackgroundColor(status),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _getStatusColor(status).withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _getStatusIcon(status),
                color: _getStatusColor(status),
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'Request ${status.toUpperCase()}',
                style: TextStyle(
                  color: _getStatusColor(status),
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }
  }
}
