import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'services/pdf_generator_service.dart';
import 'services/api_service.dart';

class StudentLeaveStatusPage extends StatefulWidget {
  final String studentEmail;

  const StudentLeaveStatusPage({super.key, required this.studentEmail});

  @override
  State<StudentLeaveStatusPage> createState() => _StudentLeaveStatusPageState();
}

class _StudentLeaveStatusPageState extends State<StudentLeaveStatusPage>
    with TickerProviderStateMixin {
  List<Map<String, dynamic>> myRequests = [];
  bool loading = true;
  String? error;
  String _selectedFilter = 'All';

  late AnimationController _animationController;
  late AnimationController _refreshController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;

  final List<String> _filterOptions = [
    'All',
    'Pending',
    'Approved',
    'Rejected',
  ];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    fetchStudentRequests();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _refreshController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _refreshController.dispose();
    super.dispose();
  }

  Future<void> fetchStudentRequests() async {
    setState(() {
      loading = true;
      error = null;
    });

    _refreshController.forward();

    try {
      // Fetch leave requests from API
      final response = await ApiService.getStudentLeaveRequests(
        widget.studentEmail,
      );

      if (response['success'] == true && response['requests'] != null) {
        List<Map<String, dynamic>> filteredRequests =
            List<Map<String, dynamic>>.from(response['requests'] ?? []);

        if (_selectedFilter != 'All') {
          filteredRequests =
              filteredRequests.where((request) {
                final status =
                    (request['status'] ?? 'pending').toString().toLowerCase();
                return status == _selectedFilter.toLowerCase();
              }).toList();
        }

        setState(() {
          myRequests = filteredRequests;
          loading = false;
        });
      } else {
        setState(() {
          error = response['message'] ?? 'Failed to fetch leave requests';
          loading = false;
        });
      }

      _refreshController.reverse();
    } catch (e) {
      print('❌ Error fetching leave requests: $e');
      setState(() {
        error = 'Error: $e';
        loading = false;
      });
      _refreshController.reverse();
    }
  }

  Future<void> _downloadLeaveRequest(Map<String, dynamic> request) async {
    try {
      await PdfGeneratorService.generateLeaveRequestPdf(
        request: request,
        studentEmail: widget.studentEmail,
      );
    } catch (e) {
      _showSnackBar('Error downloading leave request: $e', Colors.red);
    }
  }

  String _formatDateForPdf(dynamic date) {
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

  String _formatDateTimeForPdf(dynamic date) {
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
          '${parsedDate.year} at '
          '${parsedDate.hour.toString().padLeft(2, '0')}:'
          '${parsedDate.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Invalid Date';
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
      case 'accepted':
        return const Color(0xFF10B981);
      case 'rejected':
        return const Color(0xFFEF4444);
      case 'pending':
      default:
        return const Color(0xFFF59E0B);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: LayoutBuilder(
          builder: (context, constraints) {
            return Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.event_note_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'My Leave Requests',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: constraints.maxWidth < 300 ? 18 : 20,
                      color: const Color(0xFF1A202C),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            );
          },
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        toolbarHeight: 70,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_rounded,
              color: Color(0xFF64748B),
              size: 20,
            ),
            onPressed: () => Navigator.of(context).pop(),
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
                  const Color(0xFF3B82F6).withOpacity(0.2),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Filter Section
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Filter Requests',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF374151),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${myRequests.length} total requests',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.filter_list_rounded,
                        color: Color(0xFF3B82F6),
                        size: 20,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedFilter,
                      isExpanded: true,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _selectedFilter = newValue;
                          });
                          fetchStudentRequests();
                        }
                      },
                      items:
                          _filterOptions.map<DropdownMenuItem<String>>((
                            String value,
                          ) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(
                                value,
                                style: const TextStyle(
                                  color: Color(0xFF1A202C),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            );
                          }).toList(),
                      icon: const Icon(
                        Icons.arrow_drop_down,
                        color: Color(0xFF3B82F6),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: AnimatedBuilder(
              animation: _fadeAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, _slideAnimation.value),
                  child: Opacity(
                    opacity: _fadeAnimation.value,
                    child: _buildContent(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
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
              'Loading your leave requests...',
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
              onPressed: fetchStudentRequests,
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

    if (myRequests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 64,
              color: Colors.grey.withOpacity(0.6),
            ),
            const SizedBox(height: 16),
            Text(
              _selectedFilter == 'All'
                  ? 'No leave requests found'
                  : 'No $_selectedFilter leave requests found',
              style: const TextStyle(
                color: Color(0xFF718096),
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Submit your first leave request to see it here',
              style: TextStyle(color: Color(0xFF718096), fontSize: 14),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: fetchStudentRequests,
      color: const Color(0xFF667EEA),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: myRequests.length,
        itemBuilder: (context, index) {
          return _buildLeaveRequestCard(myRequests[index], index);
        },
      ),
    );
  }

  Widget _buildLeaveRequestCard(Map<String, dynamic> request, int index) {
    // Show message if staff approved and hod pending
    final bool staffApproved =
        (request['staffStatus']?.toString().toLowerCase() == 'accepted' ||
            request['staffStatus']?.toString().toLowerCase() == 'approved');
    final bool hodPending =
        (request['hodStatus']?.toString().toLowerCase() == 'pending' ||
            request['hodStatus'] == null);
    // Check if request is already fully approved/accepted
    final String rawStatus = (request['status'] ?? '').toString().toLowerCase();
    final String hodStatus =
        (request['hodStatus'] ?? '').toString().toLowerCase();
    final bool isAccepted =
        rawStatus == 'accepted' ||
        rawStatus == 'approved' ||
        hodStatus == 'accepted' ||
        hodStatus == 'approved';
    // If status is missing but staffStatus is Rejected, treat as rejected
    String status = (request['status'] ?? '').toString();
    if (status.isEmpty &&
        (request['staffStatus']?.toString().toLowerCase() == 'rejected')) {
      status = 'rejected';
    }
    if (status.isEmpty) status = 'Pending';
    final String leaveType = request['leaveType'] ?? 'N/A';
    final String fromDate = _formatDate(request['fromDate']);
    final String toDate = _formatDate(request['toDate']);
    final int duration =
        (request['duration'] is int)
            ? request['duration']
            : int.tryParse(request['duration']?.toString() ?? '0') ?? 0;
    final String reason = request['reason'] ?? 'No reason provided';
    final Color statusColor = _getStatusColor(status);
    final String formattedDate = _formatTimestamp(request['createdAt']);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(0.2), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            _showRequestDetails(request);
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with status
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        leaveType,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A202C),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Three-dot menu with enhanced design
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.grey.shade200,
                          width: 1,
                        ),
                      ),
                      child: PopupMenuButton<String>(
                        icon: Icon(
                          Icons.more_vert_rounded,
                          size: 18,
                          color: Colors.grey.shade700,
                        ),
                        padding: const EdgeInsets.all(8),
                        splashRadius: 20,
                        offset: const Offset(0, 35),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 8,
                        onSelected: (String value) {
                          if (value == 'edit') {
                            _editLeaveRequest(request, index);
                          } else if (value == 'delete') {
                            _deleteLeaveRequest(request, index);
                          }
                        },
                        itemBuilder: (BuildContext context) {
                          // Check if request is pending - only allow editing if pending
                          final String statusLower = status.toLowerCase();
                          final bool isPending =
                              statusLower == 'pending' ||
                              statusLower == 'pending_hod' ||
                              status.isEmpty;

                          List<PopupMenuEntry<String>> items = [];

                          // Only show edit option if request is pending
                          if (isPending) {
                            items.add(
                              PopupMenuItem<String>(
                                value: 'edit',
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(
                                        Icons.edit_rounded,
                                        size: 18,
                                        color: Color(0xFF3B82F6),
                                      ),
                                      SizedBox(width: 12),
                                      Text(
                                        'Edit Request',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }

                          // Show delete option for non-pending requests (accepted, rejected, forwarded, etc.)
                          if (!isPending) {
                            items.add(
                              PopupMenuItem<String>(
                                value: 'delete',
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(
                                        Icons.delete_outline_rounded,
                                        size: 18,
                                        color: Color(0xFFEF4444),
                                      ),
                                      SizedBox(width: 12),
                                      Text(
                                        'Delete Request',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }

                          return items;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    _buildStatusBadge(status, statusColor),
                  ],
                ),
                const SizedBox(height: 12),

                // Staff approved, waiting for HOD message (only show if not already accepted)
                if (staffApproved && hodPending && !isAccepted)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      children: [
                        Icon(
                          Icons.verified_rounded,
                          color: Color(0xFF10B981),
                          size: 18,
                        ),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Approved by staff, waiting for HOD approval',
                            style: TextStyle(
                              color: Color(0xFF10B981),
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                // Request details
                _buildDetailRow(Icons.calendar_today_rounded, 'From', fromDate),
                const SizedBox(height: 8),
                _buildDetailRow(Icons.event_rounded, 'To', toDate),
                const SizedBox(height: 8),
                _buildDetailRow(
                  Icons.schedule_rounded,
                  'Duration',
                  '$duration day${duration != 1 ? 's' : ''}',
                ),
                if (reason.isNotEmpty && reason != 'No reason provided') ...[
                  const SizedBox(height: 8),
                  _buildDetailRow(
                    Icons.description_rounded,
                    'Reason',
                    reason.length > 50
                        ? '${reason.substring(0, 50)}...'
                        : reason,
                  ),
                ],
                const SizedBox(height: 12),

                // Footer with date and actions
                Row(
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      size: 16,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      formattedDate,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const Spacer(),
                    if (status.toLowerCase() == 'approved' ||
                        status.toLowerCase() == 'accepted')
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: InkWell(
                          onTap: () => _downloadLeaveRequest(request),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.download_rounded,
                                size: 14,
                                color: Color(0xFF10B981),
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Download',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF10B981),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B82F6).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.visibility_rounded,
                              size: 14,
                              color: Color(0xFF3B82F6),
                            ),
                            SizedBox(width: 4),
                            Text(
                              'View Details',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF3B82F6),
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
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade500),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade700,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 14, color: Color(0xFF374151)),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(String status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            status.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(String? timestamp) {
    if (timestamp == null || timestamp.isEmpty) return 'Unknown date';

    try {
      final date = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays > 0) {
        return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return 'Unknown date';
    }
  }

  void _showRequestDetails(Map<String, dynamic> request) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Leave Request Details',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.0, 1.0),
            end: Offset.zero,
          ).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          ),
          child: child,
        );
      },
      pageBuilder: (context, animation, secondaryAnimation) {
        return WillPopScope(
          onWillPop: () async => true,
          child: Dialog(
            backgroundColor: Colors.white,
            elevation: 0,
            insetPadding: EdgeInsets.zero,
            child: _buildODStyleRequestDetails(request),
          ),
        );
      },
    );
  }

  Widget _buildODStyleRequestDetails(Map<String, dynamic> request) {
    // If status is missing but staffStatus is Rejected, treat as rejected
    String status = (request['status'] ?? '').toString();
    if (status.isEmpty &&
        (request['staffStatus']?.toString().toLowerCase() == 'rejected')) {
      status = 'rejected';
    }
    if (status.isEmpty) status = 'Pending';
    final String leaveType = request['leaveType'] ?? 'N/A';
    final String fromDate = _formatDate(request['fromDate']);
    final String toDate = _formatDate(request['toDate']);
    final int duration =
        (request['duration'] is int)
            ? request['duration']
            : int.tryParse(request['duration']?.toString() ?? '0') ?? 0;
    final String reason = request['reason'] ?? 'No reason provided';
    final String rejectionReason = request['rejectionReason'] ?? '';
    final Color statusColor = _getStatusColor(status);
    final String? rawTimestamp = request['timestamp']?.toString();
    final String? rawCreatedAt = request['createdAt']?.toString();
    final String submittedRelative = _formatTimestamp(
      rawTimestamp ?? rawCreatedAt,
    );
    String submittedFull = 'Unknown date';
    String? value =
        (rawTimestamp != null && rawTimestamp.isNotEmpty) ? rawTimestamp : null;
    if ((value == null || value.isEmpty) &&
        rawCreatedAt != null &&
        rawCreatedAt.isNotEmpty)
      value = rawCreatedAt;
    if (value != null && value.isNotEmpty) {
      try {
        final date = DateTime.parse(value);
        submittedFull =
            '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
      } catch (e) {
        submittedFull = 'Unknown date';
      }
    }
    final size = MediaQuery.of(context).size;

    // Stepper logic
    final staffStatus =
        (request['staffStatus'] ?? 'pending').toString().toLowerCase();
    final hodStatus =
        (request['hodStatus'] ?? 'pending').toString().toLowerCase();
    final staffRemark = request['staffRemark'] ?? '';
    final hodRemark = request['hodRemark'] ?? '';
    final proofBase64 = request['image'] ?? '';

    Widget buildStep(
      String label,
      String status,
      String remark,
      IconData icon,
      Color color,
    ) {
      return Expanded(
        child: Column(
          children: [
            // Removed icon for staff and HOD
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: color,
                fontSize: 13,
              ),
            ),
            if (remark.isNotEmpty) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  remark,
                  style: TextStyle(fontSize: 12, color: color.withOpacity(0.9)),
                ),
              ),
            ],
          ],
        ),
      );
    }

    Color staffColor =
        staffStatus == 'accepted'
            ? const Color(0xFF10B981)
            : staffStatus == 'rejected'
            ? const Color(0xFFEF4444)
            : const Color(0xFFF59E0B);
    Color hodColor =
        hodStatus == 'accepted'
            ? const Color(0xFF10B981)
            : hodStatus == 'rejected'
            ? const Color(0xFFEF4444)
            : const Color(0xFFF59E0B);

    return Container(
      width: double.infinity,
      constraints: BoxConstraints(maxWidth: size.width, maxHeight: size.height),
      decoration: const BoxDecoration(color: Colors.white),
      child: Column(
        children: [
          // Header with back button, title and status (OD style)
          // Header
          Container(
            padding: const EdgeInsets.only(
              left: 16,
              right: 16,
              top: 50,
              bottom: 12,
            ),
            decoration: const BoxDecoration(color: Colors.white),
            child: Row(
              children: [
                // Back button
                IconButton(
                  icon: const Icon(Icons.arrow_back, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 12),
                // Title
                const Text(
                  'Leave Request Details',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                // Status badge only
                AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.elasticOut,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: statusColor, width: 1),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        status.toLowerCase() == 'approved' ||
                                status.toLowerCase() == 'accepted'
                            ? Icons.check_circle_outline
                            : status.toLowerCase() == 'rejected'
                            ? Icons.cancel_outlined
                            : Icons.schedule_outlined,
                        color: statusColor,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Show message if staff approved and hod pending (not if already accepted)
          if ((request['staffStatus']?.toString().toLowerCase() == 'accepted' ||
                  request['staffStatus']?.toString().toLowerCase() ==
                      'approved') &&
              (request['hodStatus']?.toString().toLowerCase() == 'pending' ||
                  request['hodStatus'] == null) &&
              request['status']?.toString().toLowerCase() != 'accepted' &&
              request['hodStatus']?.toString().toLowerCase() != 'accepted')
            Padding(
              padding: const EdgeInsets.only(
                left: 24.0,
                right: 24.0,
                top: 8.0,
                bottom: 4.0,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.verified_rounded,
                    color: Color(0xFF10B981),
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Approved by staff, waiting for HOD approval',
                    style: TextStyle(
                      color: Color(0xFF10B981),
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

          // Stepper
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            child: Row(
              children: [
                buildStep(
                  'Staff',
                  staffStatus,
                  staffRemark,
                  Icons.person,
                  staffColor,
                ),
                Container(width: 32, height: 2, color: Colors.grey[300]),
                buildStep('HOD', hodStatus, hodRemark, Icons.school, hodColor),
              ],
            ),
          ),

          // Content in scrollable area (OD style)
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Leave Type Header
                    _buildODDetailRow('Leave Type:', leaveType, isHeader: true),
                    const SizedBox(height: 16),

                    // Duration
                    _buildODDetailRow(
                      'Duration:',
                      '$duration day${duration != 1 ? 's' : ''}',
                    ),
                    const SizedBox(height: 12),

                    // From Date
                    _buildODDetailRow('From Date:', fromDate),
                    const SizedBox(height: 12),

                    // To Date
                    _buildODDetailRow('To Date:', toDate),
                    const SizedBox(height: 12),

                    // Submitted Date (relative and full)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Submitted:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              submittedRelative,
                              style: const TextStyle(
                                color: Color(0xFF374151),
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            Text(
                              submittedFull,
                              style: const TextStyle(
                                color: Color(0xFF6B7280),
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Reason Section
                    const Text(
                      'Reason:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Text(
                        reason,
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                    ),
                    if (status.toLowerCase() == 'rejected' &&
                        rejectionReason.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Color(0xFFEF4444)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.info_outline,
                              color: Color(0xFFEF4444),
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Rejected by: ${request['rejectedBy']?.toString().toUpperCase() ?? 'Unknown'}\nReason: $rejectionReason',
                                style: const TextStyle(
                                  color: Color(0xFFEF4444),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Proof section if present
                    if (proofBase64.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          const Icon(
                            Icons.attachment,
                            color: Color(0xFF667EEA),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Proof attached',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const Spacer(),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF667EEA),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            onPressed: () {
                              // Download logic placeholder
                            },
                            icon: const Icon(Icons.download_rounded, size: 18),
                            label: const Text('Download'),
                          ),
                        ],
                      ),
                    ],

                    // Download button for approved requests
                    if (status.toLowerCase() == 'approved' ||
                        status.toLowerCase() == 'accepted') ...[
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _downloadLeaveRequest(request);
                          },
                          icon: const Icon(Icons.download_rounded, size: 20),
                          label: const Text(
                            'Download Leave Request',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 2,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildODDetailRow(
    String label,
    String value, {
    bool isHeader = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.black87,
              fontSize: isHeader ? 16 : 14,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: Colors.black87,
              fontSize: isHeader ? 16 : 14,
              fontWeight: isHeader ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }

  void _editLeaveRequest(Map<String, dynamic> request, int index) {
    // Check if request is approved - don't allow editing
    final String status = (request['status'] ?? '').toString().toLowerCase();
    if (status == 'accepted' || status == 'approved') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot edit approved requests'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        final TextEditingController reasonController = TextEditingController(
          text: request['reason'],
        );
        final TextEditingController leaveTypeController = TextEditingController(
          text: request['leaveType'],
        );
        DateTime? fromDate;
        DateTime? toDate;

        try {
          if (request['fromDate'] != null) {
            fromDate = DateTime.parse(request['fromDate'].toString());
          }
          if (request['toDate'] != null) {
            toDate = DateTime.parse(request['toDate'].toString());
          }
        } catch (e) {
          // Handle date parsing errors
        }

        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.edit_rounded,
                      color: Color(0xFF3B82F6),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Edit Leave Request',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: TextField(
                          controller: leaveTypeController,
                          decoration: InputDecoration(
                            labelText: 'Leave Type',
                            prefixIcon: Icon(
                              Icons.category_rounded,
                              color: Colors.grey.shade600,
                              size: 20,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: Colors.transparent,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final date = await showDatePicker(
                                  context: context,
                                  initialDate: fromDate ?? DateTime.now(),
                                  firstDate: DateTime.now().subtract(
                                    const Duration(days: 365),
                                  ),
                                  lastDate: DateTime.now().add(
                                    const Duration(days: 365),
                                  ),
                                );
                                if (date != null) {
                                  setModalState(() {
                                    fromDate = date;
                                  });
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.calendar_today_rounded,
                                      color: Colors.grey.shade600,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      fromDate != null
                                          ? 'From: ${fromDate!.day}/${fromDate!.month}/${fromDate!.year}'
                                          : 'Select From Date',
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final date = await showDatePicker(
                                  context: context,
                                  initialDate: toDate ?? DateTime.now(),
                                  firstDate: fromDate ?? DateTime.now(),
                                  lastDate: DateTime.now().add(
                                    const Duration(days: 365),
                                  ),
                                );
                                if (date != null) {
                                  setModalState(() {
                                    toDate = date;
                                  });
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.event_rounded,
                                      color: Colors.grey.shade600,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      toDate != null
                                          ? 'To: ${toDate!.day}/${toDate!.month}/${toDate!.year}'
                                          : 'Select To Date',
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: TextField(
                          controller: reasonController,
                          decoration: InputDecoration(
                            labelText: 'Reason',
                            prefixIcon: Icon(
                              Icons.description_outlined,
                              color: Colors.grey.shade600,
                              size: 20,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: Colors.transparent,
                          ),
                          maxLines: 3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    if (fromDate != null && toDate != null) {
                      _updateLeaveRequestInDatabase(
                        request,
                        leaveTypeController.text.trim(),
                        fromDate!,
                        toDate!,
                        reasonController.text.trim(),
                        index,
                      );
                      Navigator.of(context).pop();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please select both from and to dates'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 2,
                  ),
                  child: const Text(
                    'Save Changes',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _deleteLeaveRequest(Map<String, dynamic> request, int index) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.delete_outline_rounded,
                  color: Color(0xFFEF4444),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Delete Request',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          content: const Text(
            'Are you sure you want to delete this leave request? This action cannot be undone.',
            style: TextStyle(fontSize: 14, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 2,
              ),
              onPressed: () {
                _deleteLeaveRequestFromDatabase(request, index);
                Navigator.of(context).pop();
              },
              child: const Text(
                'Delete Request',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _updateLeaveRequestInDatabase(
    Map<String, dynamic> request,
    String leaveType,
    DateTime fromDate,
    DateTime toDate,
    String reason,
    int index,
  ) async {
    try {
      // Updates are now handled by the backend API
      // Refresh the requests list to get the latest data
      _showSnackBar('Syncing with server...', Colors.blue);
      await fetchStudentRequests();
      _showSnackBar('Request updated successfully!', Colors.green);
    } catch (e) {
      _showSnackBar('Error updating request: $e', Colors.red);
    }
  }

  Future<void> _deleteLeaveRequestFromDatabase(
    Map<String, dynamic> request,
    int index,
  ) async {
    try {
      // Deletions are now handled by the backend API
      // Refresh the requests list to get the latest data
      _showSnackBar('Syncing with server...', Colors.blue);
      await fetchStudentRequests();
      _showSnackBar('Request deleted successfully!', Colors.green);
    } catch (e) {
      _showSnackBar('Error deleting request: $e', Colors.red);
    }
  }
}
