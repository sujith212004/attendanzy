import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mongo_dart/mongo_dart.dart' as mongo;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/widgets/mac_folder_fullpage.dart';
import '../../../../core/config/local_config.dart';

class LeaveRequestsAdminPage extends StatefulWidget {
  const LeaveRequestsAdminPage({super.key});

  @override
  State<LeaveRequestsAdminPage> createState() => _LeaveRequestsAdminPageState();
}

class _LeaveRequestsAdminPageState extends State<LeaveRequestsAdminPage> {
  final String mongoUri = LocalConfig.mongoUri;
  final String collectionName = "leave_requests";

  List<Map<String, dynamic>> requests = [];
  bool loading = true;
  String? error;
  String? hodDepartment;

  String? selectedYear;
  String? selectedSection;

  List<String> availableYears = [];
  List<String> availableSections = [];

  // Count helpers for MacFolderFullPage
  int get _pendingCount =>
      requests.where((r) {
        final status = (r['status'] ?? '').toString().toLowerCase();
        return status == 'pending' || status == 'pending_hod' || status == '';
      }).length;

  int get _approvedCount =>
      requests.where((r) {
        final status = (r['status'] ?? '').toString().toLowerCase();
        return status == 'approved';
      }).length;

  int get _rejectedCount =>
      requests.where((r) {
        final status = (r['status'] ?? '').toString().toLowerCase();
        return status == 'rejected';
      }).length;

  String _getStatusFromRequest(Map<String, dynamic> request) {
    return (request['status'] ?? '').toString().toLowerCase();
  }

  @override
  void initState() {
    super.initState();
    _loadHodDepartmentAndShowFilter();
  }

  Future<void> _loadHodDepartmentAndShowFilter() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      hodDepartment = prefs.getString('department');
      if (kDebugMode) {
        print("DEBUG: HOD's department loaded from session: '$hodDepartment'");
      }
    });

    if (hodDepartment != null && hodDepartment!.isNotEmpty) {
      _showFilterPage();
    } else {
      setState(() {
        loading = false;
        error = "Could not identify HOD's department. Please log in again.";
      });
    }
  }

  Future<void> _fetchAvailableFilters() async {
    try {
      final db = await mongo.Db.create(mongoUri);
      await db.open();
      final collection = db.collection(collectionName);

      // Fetch distinct years
      final yearPipeline = [
        {
          '\$match': {'department': hodDepartment},
        },
        {
          '\$group': {'_id': '\$year'},
        },
        {
          '\$sort': {'_id': 1},
        },
      ];
      final yearResult = await collection.aggregate(yearPipeline);
      availableYears =
          (yearResult['result'] as List)
              .map((e) => e['_id'].toString())
              .toList();

      // Fetch distinct sections
      final sectionPipeline = [
        {
          '\$match': {'department': hodDepartment},
        },
        {
          '\$group': {'_id': '\$section'},
        },
        {
          '\$sort': {'_id': 1},
        },
      ];
      final sectionResult = await collection.aggregate(sectionPipeline);
      availableSections =
          (sectionResult['result'] as List)
              .map((e) => e['_id'].toString())
              .toList();

      await db.close();
    } catch (e) {
      if (kDebugMode) {
        print("DEBUG: Error fetching filters: $e");
      }
    }
  }

  void _showFilterPage() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (context) => HodLeaveFilterPage(
              onFiltersSelected: (year, section) {
                setState(() {
                  selectedYear = year;
                  selectedSection = section;
                });
                fetchRequests();
              },
            ),
      ),
    );
  }

  Future<void> fetchRequests() async {
    if (!mounted) return;
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final db = await mongo.Db.create(mongoUri);
      await db.open();
      final collection = db.collection(collectionName);

      var query = mongo.where.eq('department', hodDepartment);

      if (selectedYear != null && selectedYear!.isNotEmpty) {
        query = query.eq('year', selectedYear);
      }

      if (selectedSection != null && selectedSection!.isNotEmpty) {
        query = query.eq('section', selectedSection);
      }

      query = query.sortBy('createdAt', descending: true);

      if (kDebugMode) {
        print(
          "DEBUG: Executing MongoDB query for department: $hodDepartment, year: $selectedYear, section: $selectedSection",
        );
      }
      final result = await collection.find(query).toList();

      if (kDebugMode) {
        print("DEBUG: Found ${result.length} leave requests for this filter.");
      }

      await db.close();
      if (mounted) {
        setState(() {
          requests = List<Map<String, dynamic>>.from(result);
          loading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print("DEBUG: An error occurred while fetching requests: $e");
      }
      if (mounted) {
        setState(() {
          error = e.toString();
          loading = false;
        });
      }
    }
  }

  Future<void> updateStatus(
    String id,
    String finalDecision, {
    String? reason,
  }) async {
    try {
      final db = await mongo.Db.create(mongoUri);
      await db.open();
      final collection = db.collection(collectionName);

      final objectId = mongo.ObjectId.fromHexString(id);

      // Build modifier
      var modifier = mongo.modify
          .set('status', finalDecision) // final approval/rejection
          .set('updatedAt', DateTime.now());

      if (finalDecision.toLowerCase() == 'rejected') {
        // store who rejected and reason
        modifier = modifier
            .set('rejectedBy', 'hod')
            .set('rejectionReason', reason ?? '')
            .set('status', 'rejected');
      }

      final updateResult = await collection.updateOne(
        mongo.where.eq('_id', objectId),
        modifier,
      );

      await db.close();

      if (updateResult.isSuccess) {
        await fetchRequests();
        _showSnackBar(
          'Leave request $finalDecision successfully',
          Colors.green,
        );
      } else {
        _showSnackBar('Failed to update leave request', Colors.red);
      }
    } catch (e) {
      _showSnackBar('Error updating leave request: $e', Colors.red);
    }
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
      case 'pending_hod':
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
      case 'pending_hod':
      default:
        return Icons.pending;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(
          selectedYear != null && selectedSection != null
              ? 'Leave Requests - $selectedYear $selectedSection'
              : 'Leave Requests Management',
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: Color(0xFF1A202C),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF1A202C),
        centerTitle: true,
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
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF10B981).withOpacity(0.2),
                width: 1,
              ),
            ),
            child: IconButton(
              onPressed: _showFilterPage,
              icon: const Icon(
                Icons.filter_list,
                color: Color(0xFF10B981),
                size: 18,
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  const Color(0xFF667EEA).withOpacity(0.2),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ),
      body:
          loading
              ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFF667EEA),
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Loading leave requests...',
                      style: TextStyle(color: Color(0xFF718096), fontSize: 16),
                    ),
                  ],
                ),
              )
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
                      'Error: $error',
                      style: const TextStyle(color: Colors.red, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: fetchRequests,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF667EEA),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              )
              : MacFolderFullPage(
                title: 'Leave Requests - ${hodDepartment ?? "Department"}',
                acceptedLabel: 'Approved',
                pendingCount: _pendingCount,
                acceptedCount: _approvedCount,
                rejectedCount: _rejectedCount,
                allRequests: requests,
                loading: loading,
                onRefresh: fetchRequests,
                getStatusFromRequest: _getStatusFromRequest,
                requestCardBuilder: (req) => _buildLeaveRequestCard(req),
              ),
    );
  }

  Widget _buildLeaveRequestCard(Map<String, dynamic> request) {
    final String status = request['status'] ?? 'Pending';
    final String studentName = request['studentName'] ?? 'Unknown';
    final String studentEmail = request['studentEmail'] ?? 'No email';
    final String leaveType = request['leaveType'] ?? 'N/A';
    final String fromDate = _formatDate(request['fromDate']);
    final String toDate = _formatDate(request['toDate']);
    final int duration =
        (request['duration'] is int)
            ? request['duration']
            : int.tryParse(request['duration']?.toString() ?? '0') ?? 0;

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

                  // Request Details using the same pattern as OD
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

                  const SizedBox(height: 12),

                  _buildDetailRow(
                    Icons.person_outline,
                    'Student Email',
                    studentEmail,
                  ),

                  const SizedBox(height: 12),

                  if (request['forwardedBy'] != null &&
                      request['forwardedBy'].toString().isNotEmpty) ...[
                    _buildDetailRow(
                      Icons.forward_outlined,
                      'Forwarded by',
                      request['forwardedBy'] ?? 'N/A',
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Show processing history for approved/rejected requests
                  if (status.toLowerCase() == 'approved' ||
                      status.toLowerCase() == 'rejected') ...[
                    const Divider(height: 32),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        'Processing History',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                    if (request['updatedAt'] != null)
                      _buildDetailRow(
                        Icons.access_time,
                        status.toLowerCase() == 'approved'
                            ? 'Approved on'
                            : 'Rejected on',
                        _formatDate(request['updatedAt']),
                      ),
                    if (status.toLowerCase() == 'rejected' &&
                        request['rejectionReason'] != null &&
                        request['rejectionReason'].toString().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _buildDetailRow(
                        Icons.info_outline,
                        'Rejection Reason',
                        request['rejectionReason'],
                      ),
                    ],
                  ],
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
      case 'pending_hod':
        return Colors.orange.withOpacity(0.1);
      default:
        return Colors.grey.withOpacity(0.1);
    }
  }

  Widget _buildFullScreenDialog(Map<String, dynamic> request) {
    final status = request['status']?.toString().toLowerCase() ?? 'pending';
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
                color: _getStatusBackgroundColor(status),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                status.toUpperCase(),
                style: TextStyle(
                  color: _getStatusColor(status),
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
            _buildLeaveActionButtons(status, request),
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

          // Add forwarded information if present
          if (request['forwardedBy'] != null &&
              request['forwardedBy'].toString().isNotEmpty)
            Column(
              children: [
                const SizedBox(height: 16),
                _buildDialogDetailRow(
                  Icons.forward_outlined,
                  "Forwarded By",
                  request['forwardedBy'] ?? 'N/A',
                ),
                if (request['forwardedAt'] != null)
                  Column(
                    children: [
                      const SizedBox(height: 16),
                      _buildDialogDetailRow(
                        Icons.schedule_outlined,
                        "Forwarded At",
                        _formatDateTime(request['forwardedAt']),
                      ),
                    ],
                  ),
              ],
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
                  child: Image.memory(base64Decode(request['image'])),
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
    final requestId = request['_id']?.toHexString() ?? '';

    if (status.toLowerCase() == 'pending' ||
        status.toLowerCase() == 'pending_hod') {
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
                  final reason = await _showRejectionReasonDialog();
                  if (reason == null || reason.trim().isEmpty) return;
                  await updateStatus(
                    requestId,
                    'Rejected',
                    reason: reason.trim(),
                  );
                  Navigator.of(context).pop();
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
                  updateStatus(requestId, 'Approved');
                  Navigator.of(context).pop();
                },
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Approve'),
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

  String _formatDateTime(String? dateTimeString) {
    if (dateTimeString == null) return 'N/A';
    try {
      final dateTime = DateTime.parse(dateTimeString);
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateTimeString;
    }
  }
}

class HodLeaveFilterPage extends StatefulWidget {
  final Function(String?, String?) onFiltersSelected;

  const HodLeaveFilterPage({super.key, required this.onFiltersSelected});

  @override
  State<HodLeaveFilterPage> createState() => _HodLeaveFilterPageState();
}

class _HodLeaveFilterPageState extends State<HodLeaveFilterPage> {
  String? selectedYear;
  String? selectedSection;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'Filter Requests',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: Color(0xFF1A202C),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF1A202C),
        centerTitle: true,
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
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Year and Section',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1A202C),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Choose the year and section to view requests for.',
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 32),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: DropdownButtonFormField<String>(
                value: selectedYear,
                decoration: const InputDecoration(
                  labelText: 'Select Year',
                  prefixIcon: Icon(
                    Icons.calendar_today,
                    color: Color(0xFF667EEA),
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  labelStyle: TextStyle(
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text(
                      'All Years',
                      style: TextStyle(color: Color(0xFF64748B)),
                    ),
                  ),
                  const DropdownMenuItem<String>(
                    value: '2nd Year',
                    child: Text(
                      '2nd Year',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                  const DropdownMenuItem<String>(
                    value: '3rd Year',
                    child: Text(
                      '3rd Year',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                  const DropdownMenuItem<String>(
                    value: '4th Year',
                    child: Text(
                      '4th Year',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
                onChanged: (String? newValue) {
                  setState(() {
                    selectedYear = newValue;
                  });
                },
              ),
            ),
            const SizedBox(height: 20),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: DropdownButtonFormField<String>(
                value: selectedSection,
                decoration: const InputDecoration(
                  labelText: 'Select Section',
                  prefixIcon: Icon(Icons.group, color: Color(0xFF667EEA)),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  labelStyle: TextStyle(
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text(
                      'All Sections',
                      style: TextStyle(color: Color(0xFF64748B)),
                    ),
                  ),
                  const DropdownMenuItem<String>(
                    value: 'A',
                    child: Text(
                      'A',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                  const DropdownMenuItem<String>(
                    value: 'B',
                    child: Text(
                      'B',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                  const DropdownMenuItem<String>(
                    value: 'C',
                    child: Text(
                      'C',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
                onChanged: (String? newValue) {
                  setState(() {
                    selectedSection = newValue;
                  });
                },
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  widget.onFiltersSelected(selectedYear, selectedSection);
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF667EEA),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: const Text('Apply Filters'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
