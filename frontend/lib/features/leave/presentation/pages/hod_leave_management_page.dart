import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mongo_dart/mongo_dart.dart' as mongo;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/widgets/mac_folder_fullpage.dart';
import '../../../../core/config/local_config.dart';

/// HOD Leave Management Page with Mac-style folder UI
class HodLeaveManagementPage extends StatefulWidget {
  const HodLeaveManagementPage({super.key});

  @override
  State<HodLeaveManagementPage> createState() => _HodLeaveManagementPageState();
}

class _HodLeaveManagementPageState extends State<HodLeaveManagementPage> {
  final String mongoUri = LocalConfig.mongoUri;
  final String collectionName = "leave_requests";

  List<Map<String, dynamic>> requests = [];
  bool loading = true;
  String? error;
  String? hodDepartment;

  @override
  void initState() {
    super.initState();
    _loadHodDepartmentAndFetchRequests();
  }

  Future<void> _loadHodDepartmentAndFetchRequests() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      hodDepartment = prefs.getString('department');
      if (kDebugMode) {
        print("DEBUG: HOD's department loaded from session: '$hodDepartment'");
      }
    });

    if (hodDepartment != null && hodDepartment!.isNotEmpty) {
      await fetchRequests();
    } else {
      setState(() {
        loading = false;
        error = "Could not identify HOD's department. Please log in again.";
      });
    }
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

      final query = mongo.where
          .eq('department', hodDepartment)
          .eq('staffStatus', 'approved')
          .sortBy('createdAt', descending: true);

      if (kDebugMode) {
        print("DEBUG: Executing MongoDB query for department: $hodDepartment");
      }
      final result = await collection.find(query).toList();

      if (kDebugMode) {
        print(
          "DEBUG: Found ${result.length} leave requests for this department.",
        );
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

      // Map finalDecision for hodStatus: keep as 'approved'/'rejected'
      final hodStatusValue =
          finalDecision.toLowerCase() == 'accepted'
              ? 'approved'
              : finalDecision.toLowerCase();

      var modifier = mongo.modify
          .set('status', finalDecision)
          .set('hodStatus', hodStatusValue)
          .set('updatedAt', DateTime.now());

      if (finalDecision.toLowerCase() == 'rejected') {
        modifier = modifier
            .set('rejectedBy', 'hod')
            .set('rejectionReason', reason ?? '')
            .set('status', 'rejected')
            .set('hodStatus', 'rejected');
      }

      // Get the request details before updating (for notification)
      final request = await collection.findOne(mongo.where.eq('_id', objectId));
      final studentEmail = request?['studentEmail'] ?? '';
      final studentName = request?['studentName'] ?? 'Student';

      final updateResult = await collection.updateOne(
        mongo.where.eq('_id', objectId),
        modifier,
      );

      await db.close();

      if (updateResult.isSuccess) {
        // Send notification to student via backend
        // Send notification to student via backend with retry
        _sendNotificationWithRetry(
          studentEmail: studentEmail,
          studentName: studentName,
          requestType: 'Leave',
          status: hodStatusValue,
          requestId: id,
        );

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

  // Count helpers
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
        return const Color(0xFF10B981);
      case 'rejected':
        return const Color(0xFFEF4444);
      case 'pending':
      case 'pending_hod':
      default:
        return const Color(0xFFF59E0B);
    }
  }

  Color _getStatusBackgroundColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return const Color(0xFFD1FAE5);
      case 'rejected':
        return const Color(0xFFFEE2E2);
      case 'pending':
      case 'pending_hod':
      default:
        return const Color(0xFFFEF3C7);
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
        title: const Text(
          'Leave Management',
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
            color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF3B82F6).withValues(alpha: 0.2),
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
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  const Color(0xFF667EEA).withValues(alpha: 0.2),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (loading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF667EEA)),
            ),
            SizedBox(height: 16),
            Text(
              'Loading leave requests...',
              style: TextStyle(color: Color(0xFF718096), fontSize: 16),
            ),
          ],
        ),
      );
    }

    if (error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red.withValues(alpha: 0.6),
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
      );
    }

    return MacFolderFullPage(
      title: 'Leave Requests - ${hodDepartment ?? "Department"}',
      acceptedLabel: 'Approved',
      pendingCount: _pendingCount,
      acceptedCount: _approvedCount,
      rejectedCount: _rejectedCount,
      allRequests: requests,
      requestCardBuilder: _buildLeaveRequestCard,
      onRefresh: fetchRequests,
      loading: loading,
      getStatusFromRequest: _getStatusFromRequest,
    );
  }

  Widget _buildLeaveRequestCard(Map<String, dynamic> request) {
    final String status = request['status'] ?? 'Pending';
    final String studentName = request['studentName'] ?? 'Unknown';
    final String leaveType = request['leaveType'] ?? 'N/A';
    final String fromDate = _formatDate(request['fromDate']);
    final String toDate = _formatDate(request['toDate']);
    final int duration =
        (request['duration'] is int)
            ? request['duration']
            : int.tryParse(request['duration']?.toString() ?? '0') ?? 0;
    final bool isPending =
        status.toLowerCase() == 'pending' ||
        status.toLowerCase() == 'pending_hod' ||
        status.isEmpty;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color:
              isPending
                  ? _getStatusColor(status).withValues(alpha: 0.3)
                  : const Color(0xFFE2E8F0),
          width: isPending ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color:
                isPending
                    ? _getStatusColor(status).withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.04),
            blurRadius: isPending ? 12 : 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _showLeaveDetailDialog(request),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  _getStatusColor(status).withValues(alpha: 0.08),
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
                              _getStatusColor(status).withValues(alpha: 0.7),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: _getStatusColor(
                                status,
                              ).withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            studentName.isNotEmpty
                                ? studentName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
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
                                fontSize: 16,
                                color: Color(0xFF1E293B),
                                letterSpacing: 0.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF3B82F6,
                                    ).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    leaveType,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF3B82F6),
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF64748B,
                                    ).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.timer_outlined,
                                        size: 12,
                                        color: const Color(0xFF64748B),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '$duration day${duration != 1 ? 's' : ''}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
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
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              _getStatusBackgroundColor(status),
                              _getStatusBackgroundColor(
                                status,
                              ).withValues(alpha: 0.7),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _getStatusColor(
                              status,
                            ).withValues(alpha: 0.3),
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
                                    0xFF10B981,
                                  ).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.flight_takeoff_rounded,
                                  size: 16,
                                  color: Color(0xFF10B981),
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
                                      maxLines: 1,
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
                                      maxLines: 1,
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
                                    0xFFEF4444,
                                  ).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.flight_land_rounded,
                                  size: 16,
                                  color: Color(0xFFEF4444),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Forwarded By Info
                  if (request['forwardedBy'] != null &&
                      request['forwardedBy'].toString().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.forward_to_inbox_rounded,
                            size: 16,
                            color: const Color(0xFF8B5CF6),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Forwarded by ${request['forwardedBy']}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF8B5CF6),
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
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

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF64748B)),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF475569),
            ),
          ),
        ],
      ),
    );
  }

  void _showLeaveDetailDialog(Map<String, dynamic> request) {
    if (!mounted) return;
    final status = request['status']?.toString().toLowerCase() ?? 'pending';

    showDialog(
      context: context,
      builder: (context) {
        bool isLoading = false;
        return StatefulBuilder(
          builder: (context, setState) {
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
                      margin: const EdgeInsets.only(
                        right: 16,
                        top: 8,
                        bottom: 8,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
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
                    _buildLeaveActionButtons(
                      status,
                      request,
                      isLoading: isLoading,
                      onLoadingChanged:
                          (val) => setState(() => isLoading = val),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
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

          if (request['image'] != null &&
              request['image'].toString().isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
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
            color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
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

  Widget _buildLeaveActionButtons(
    String status,
    Map<String, dynamic> request, {
    bool isLoading = false,
    ValueChanged<bool>? onLoadingChanged,
  }) {
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
                onPressed:
                    isLoading
                        ? null
                        : () async {
                          final reason = await _showRejectionReasonDialog();
                          if (reason == null || reason.trim().isEmpty) return;

                          onLoadingChanged?.call(true);
                          await updateStatus(
                            requestId,
                            'rejected',
                            reason: reason.trim(),
                          );
                          if (mounted) Navigator.of(context).pop();
                        },
                icon:
                    isLoading
                        ? const SizedBox.shrink()
                        : const Icon(Icons.close, size: 18),
                label: const Text('Reject'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed:
                    isLoading
                        ? null
                        : () async {
                          onLoadingChanged?.call(true);
                          await updateStatus(requestId, 'approved');
                          if (mounted) Navigator.of(context).pop();
                        },
                icon:
                    isLoading
                        ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                        : const Icon(Icons.check, size: 18),
                label: Text(isLoading ? 'Processing...' : 'Approve'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
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
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: _getStatusBackgroundColor(status),
            borderRadius: BorderRadius.circular(12),
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
                        color: Colors.red.withValues(alpha: 0.1),
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

  String _formatDateTime(dynamic dateTimeValue) {
    if (dateTimeValue == null) return 'N/A';
    try {
      DateTime dateTime;
      if (dateTimeValue is String) {
        dateTime = DateTime.parse(dateTimeValue);
      } else if (dateTimeValue is DateTime) {
        dateTime = dateTimeValue;
      } else {
        return 'N/A';
      }
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateTimeValue.toString();
    }
  }

  Future<void> _sendNotificationWithRetry({
    required String studentEmail,
    required String studentName,
    required String requestType,
    required String status,
    required String requestId,
  }) async {
    const int maxRetries = 3;
    const Duration initialDelay = Duration(seconds: 2);

    for (int i = 0; i < maxRetries; i++) {
      try {
        if (kDebugMode) {
          print(
            'DEBUG: Sending notification for $requestType $requestId (Attempt ${i + 1}/$maxRetries)...',
          );
        }

        final notifUrl = Uri.parse(
          '${LocalConfig.apiBaseUrl}/notifications/hod-decision',
        );

        final response = await http
            .post(
              notifUrl,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'studentEmail': studentEmail,
                'studentName': studentName,
                'requestType': requestType,
                'status': status,
              }),
            )
            .timeout(const Duration(seconds: 20));

        if (response.statusCode >= 200 && response.statusCode < 300) {
          if (kDebugMode) {
            print(
              'DEBUG: Notification sent successfully for $requestType request $requestId',
            );
          }
          return;
        } else {
          throw Exception(
            'Server returned ${response.statusCode}: ${response.body}',
          );
        }
      } catch (e) {
        if (kDebugMode) {
          print('DEBUG: Notification attempt ${i + 1} failed: $e');
        }
        if (i < maxRetries - 1) {
          await Future.delayed(initialDelay * (i + 1)); // Linear backoff
        }
      }
    }
    if (kDebugMode) {
      print(
        'DEBUG: Failed to send notification for $requestId after $maxRetries attempts.',
      );
    }
  }
}
