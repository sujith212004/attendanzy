import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:mongo_dart/mongo_dart.dart' as mongo;
import '../../../../core/services/pdf_generator_service.dart';
import '../../../../core/config/local_config.dart';

class StudentODStatusPage extends StatefulWidget {
  final String studentEmail;

  const StudentODStatusPage({super.key, required this.studentEmail});

  @override
  State<StudentODStatusPage> createState() => _StudentODStatusPageState();
}

class _StudentODStatusPageState extends State<StudentODStatusPage>
    with TickerProviderStateMixin {
  // Helper widget for status badge
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

  // Helper widget for detail row
  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Text(
          '$label:',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Color(0xFF374151),
            fontSize: 13,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Color(0xFF374151),
              fontSize: 13,
              fontWeight: FontWeight.w400,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  final String mongoUri = LocalConfig.mongoUri;
  final String collectionName = "od_requests";

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
    'Accepted',
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
      final db = await mongo.Db.create(mongoUri);
      await db.open();
      final collection = db.collection(collectionName);
      final result =
          await collection
              .find(
                mongo.where
                    .eq("studentEmail", widget.studentEmail)
                    .sortBy('createdAt', descending: true),
              )
              .toList();
      await db.close();

      // Apply filtering
      List<Map<String, dynamic>> filteredRequests =
          List<Map<String, dynamic>>.from(result);

      if (_selectedFilter != 'All') {
        filteredRequests =
            filteredRequests.where((request) {
              final status =
                  (request['status'] ?? 'pending').toString().toLowerCase();
              return status == _selectedFilter.toLowerCase();
            }).toList();
      }

      // Sort by timestamp (newest first)
      filteredRequests.sort((a, b) {
        final timestampA = a['timestamp'] ?? '';
        final timestampB = b['timestamp'] ?? '';
        return timestampB.compareTo(timestampA);
      });

      setState(() {
        myRequests = filteredRequests;
        loading = false;
      });

      HapticFeedback.lightImpact();
    } catch (e) {
      setState(() {
        error = e.toString();
        loading = false;
      });
      HapticFeedback.heavyImpact();
    } finally {
      _refreshController.reverse();
    }
  }

  List<Map<String, dynamic>> get _allRequests {
    return myRequests;
  }

  int get _pendingCount =>
      _allRequests
          .where(
            (r) =>
                (r['status'] ?? 'pending').toString().toLowerCase() ==
                'pending',
          )
          .length;

  int get _acceptedCount =>
      _allRequests
          .where(
            (r) =>
                (r['status'] ?? 'pending').toString().toLowerCase() ==
                'accepted',
          )
          .length;

  int get _rejectedCount =>
      _allRequests
          .where(
            (r) =>
                (r['status'] ?? 'pending').toString().toLowerCase() ==
                'rejected',
          )
          .length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildProfessionalAppBar(),
      body: Column(
        children: [
          if (!loading) _buildFilterSection(),
          Expanded(
            child:
                loading
                    ? _buildLoadingState()
                    : error != null
                    ? _buildErrorState()
                    : myRequests.isEmpty
                    ? _buildEmptyState()
                    : _buildRequestsList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: fetchStudentRequests,
        backgroundColor: const Color(0xFF3B82F6),
        child: AnimatedBuilder(
          animation: _refreshController,
          builder: (context, child) {
            return Transform.rotate(
              angle: _refreshController.value * 2 * 3.14159,
              child: const Icon(Icons.refresh_rounded, color: Colors.white),
            );
          },
        ),
      ),
    );
  }

  PreferredSizeWidget _buildProfessionalAppBar() {
    return AppBar(
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
                  Icons.assignment_turned_in_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'My OD Requests',
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
    );
  }

  Widget _buildFilterSection() {
    return Container(
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
                    const SizedBox(height: 8),
                    _buildFilterChips(),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      '${myRequests.length}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF3B82F6),
                      ),
                    ),
                    const Text(
                      'Total',
                      style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildStatusSummary(),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return Wrap(
      spacing: 8,
      children:
          _filterOptions.map((filter) {
            final isSelected = _selectedFilter == filter;
            return GestureDetector(
              onTap: () {
                setState(() => _selectedFilter = filter);
                fetchStudentRequests();
                HapticFeedback.selectionClick();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color:
                      isSelected
                          ? const Color(0xFF3B82F6)
                          : const Color(0xFF3B82F6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF3B82F6).withOpacity(0.3),
                  ),
                ),
                child: Text(
                  filter,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isSelected ? Colors.white : const Color(0xFF3B82F6),
                  ),
                ),
              ),
            );
          }).toList(),
    );
  }

  Widget _buildStatusSummary() {
    return Row(
      children: [
        _buildStatusChip('Pending', _pendingCount, const Color(0xFFF59E0B)),
        const SizedBox(width: 8),
        _buildStatusChip('Accepted', _acceptedCount, const Color(0xFF10B981)),
        const SizedBox(width: 8),
        _buildStatusChip('Rejected', _rejectedCount, const Color(0xFFEF4444)),
      ],
    );
  }

  String _formatTimestamp(String? timestamp, {String? fallback}) {
    // Try timestamp first
    String? value =
        (timestamp != null && timestamp.isNotEmpty && timestamp != 'null')
            ? timestamp
            : null;

    // If timestamp invalid, try fallback
    if (value == null &&
        fallback != null &&
        fallback.isNotEmpty &&
        fallback != 'null') {
      value = fallback;
    }

    if (value == null || value.isEmpty) return 'Unknown date';

    try {
      final date = DateTime.parse(value);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays > 7) {
        return '${date.day}/${date.month}/${date.year}';
      } else if (difference.inDays > 0) {
        return '${difference.inDays}d ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours}h ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes}m ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return 'Unknown date';
    }
  }

  Widget _buildStatusChip(String label, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
          ),
          SizedBox(height: 16),
          Text(
            'Loading your requests...',
            style: TextStyle(fontSize: 16, color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.red.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(50),
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  size: 48,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Something went wrong',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF374151),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                error ?? 'Unknown error occurred',
                style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: fetchStudentRequests,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withOpacity(0.1),
                borderRadius: BorderRadius.circular(50),
              ),
              child: const Icon(
                Icons.assignment_outlined,
                size: 48,
                color: Color(0xFF3B82F6),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _selectedFilter == 'All'
                  ? 'No OD Requests Yet'
                  : 'No $_selectedFilter Requests',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _selectedFilter == 'All'
                  ? 'You haven\'t submitted any OD requests yet'
                  : 'No requests found with $_selectedFilter status',
              style: const TextStyle(fontSize: 16, color: Color(0xFF6B7280)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestsList() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ListView.builder(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: myRequests.length,
        itemBuilder: (context, index) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: Offset(0, _slideAnimation.value),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(
                parent: _animationController,
                curve: Interval(index * 0.1, 1.0, curve: Curves.easeOut),
              ),
            ),
            child: _buildRequestCard(myRequests[index], index),
          );
        },
      ),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> req, int index) {
    // Determine the correct status
    String status;
    final String staffStatusRaw =
        (req['staffStatus'] ?? 'pending').toString().toLowerCase();
    final String mainStatus = (req['status'] ?? '').toString().toLowerCase();
    final String rejectionReason =
        (req['rejectionReason'] ?? '').toString().trim();

    if (rejectionReason.isNotEmpty || mainStatus == 'rejected') {
      status = 'rejected';
    } else if (mainStatus == 'accepted' ||
        (staffStatusRaw == 'accepted' &&
            (req['hodStatus']?.toString().toLowerCase() == 'accepted' ||
                req['hodStatus']?.toString().toLowerCase() == 'approved'))) {
      status = 'accepted';
    } else {
      status = 'pending';
    }

    final String subject = req['subject'] ?? 'OD Request';
    final String fromDate = req['from'] ?? 'N/A';
    final String toDate = req['to'] ?? 'N/A';
    final String content = req['content'] ?? req['reason'] ?? '';
    final bool isPending = status == 'pending';

    // Status display logic
    final bool staffApproved =
        (req['staffStatus']?.toString().toLowerCase() == 'accepted' ||
            req['staffStatus']?.toString().toLowerCase() == 'approved');
    final bool hodPending =
        (req['hodStatus']?.toString().toLowerCase() == 'pending' ||
            req['hodStatus'] == null);
    final String hodStatusVal =
        (req['hodStatus'] ?? '').toString().toLowerCase();
    final bool isAccepted =
        mainStatus == 'accepted' ||
        mainStatus == 'approved' ||
        hodStatusVal == 'accepted' ||
        hodStatusVal == 'approved';

    final Color statusColor = _getStatusColor(status);
    final String timestamp = req['timestamp']?.toString() ?? '';
    final String formattedDate = _formatTimestamp(
      timestamp,
      fallback: req['createdAt']?.toString(),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color:
              isPending
                  ? statusColor.withOpacity(0.3)
                  : const Color(0xFFE2E8F0),
          width: isPending ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color:
                isPending
                    ? statusColor.withOpacity(0.1)
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
          onTap: () {
            HapticFeedback.selectionClick();
            _showODRequestDetails(req, status, statusColor, formattedDate);
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [statusColor.withOpacity(0.08), Colors.transparent],
                stops: const [0.0, 0.15],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Row with Icon
                  Row(
                    children: [
                      // Icon Container
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [statusColor, statusColor.withOpacity(0.7)],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: statusColor.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.assignment_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              subject,
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
                            // Status Badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _getStatusIcon(status),
                                    size: 12,
                                    color: statusColor,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    status.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: statusColor,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Three-dot menu
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: PopupMenuButton<String>(
                          icon: Icon(
                            Icons.more_horiz_rounded,
                            size: 18,
                            color: Colors.grey.shade600,
                          ),
                          padding: EdgeInsets.zero,
                          splashRadius: 20,
                          offset: const Offset(0, 35),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 8,
                          onSelected: (String value) {
                            if (value == 'edit') {
                              _editODRequest(req, index);
                            } else if (value == 'delete') {
                              _deleteODRequest(req, index);
                            }
                          },
                          itemBuilder: (BuildContext context) {
                            List<PopupMenuEntry<String>> items = [];
                            if (isPending) {
                              items.add(
                                PopupMenuItem<String>(
                                  value: 'edit',
                                  child: Row(
                                    children: const [
                                      Icon(
                                        Icons.edit_rounded,
                                        size: 18,
                                        color: Color(0xFF3B82F6),
                                      ),
                                      SizedBox(width: 12),
                                      Text('Edit Request'),
                                    ],
                                  ),
                                ),
                              );
                            }
                            if (!isPending) {
                              items.add(
                                PopupMenuItem<String>(
                                  value: 'delete',
                                  child: Row(
                                    children: const [
                                      Icon(
                                        Icons.delete_outline_rounded,
                                        size: 18,
                                        color: Color(0xFFEF4444),
                                      ),
                                      SizedBox(width: 12),
                                      Text('Delete Application'),
                                    ],
                                  ),
                                ),
                              );
                            }
                            return items;
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Staff approved, waiting for HOD message
                  if (staffApproved && hodPending && !isAccepted)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFF10B981).withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.verified_rounded,
                              color: Color(0xFF10B981),
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Approved by staff, waiting for HOD',
                                style: TextStyle(
                                  color: Color(0xFF10B981),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Rejected Message
                  if (req['staffStatus'] == 'rejected' ||
                      status == 'rejected' &&
                          (req['rejectionReason']?.toString().isNotEmpty ??
                              false))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFFEF4444).withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.info_outline_rounded,
                              color: Color(0xFFEF4444),
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Rejected by ${req['rejectedBy']?.toString().toUpperCase() ?? 'Staff'}',
                                    style: const TextStyle(
                                      color: Color(0xFFEF4444),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                  if (req['rejectionReason'] != null)
                                    Text(
                                      req['rejectionReason'],
                                      style: const TextStyle(
                                        color: Color(0xFFEF4444),
                                        fontWeight: FontWeight.w500,
                                        fontSize: 12,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

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
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // From
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
                              const SizedBox(height: 2),
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
                        // Arrow
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 16,
                          color: Colors.grey.shade400,
                        ),
                        // To
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
                              const SizedBox(height: 2),
                              Text(
                                toDate,
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

                  // Content Preview
                  if (content.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      content,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  // Footer Actions
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 14,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        formattedDate,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      // Action Button
                      if (isAccepted)
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () => _downloadODRequest(req),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: const [
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
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF10B981),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      else if (isPending)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF3B82F6).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Reviewing',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF3B82F6),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Helper to show a snackbar

  Future<void> _downloadODRequest(Map<String, dynamic> request) async {
    try {
      await PdfGeneratorService.generateODRequestPdf(
        request: request,
        studentEmail: widget.studentEmail,
      );
    } catch (e) {
      _showSnackBar('Error downloading OD request: $e', Colors.red);
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
      case 'approved':
        return Icons.check_circle_rounded;
      case 'rejected':
        return Icons.cancel_rounded;
      case 'pending':
      case 'pending_hod':
      default:
        return Icons.access_time_filled_rounded;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
        return const Color(0xFF10B981);
      case 'rejected':
        return const Color(0xFFEF4444);
      case 'pending':
      default:
        return const Color(0xFFF59E0B);
    }
  }

  void _showODRequestDetails(
    Map<String, dynamic> request,
    String status,
    Color statusColor,
    String formattedDate,
  ) {
    final String rejectionReason = request['rejectionReason']?.toString() ?? '';
    // Compute the correct date for the popup
    final String? rawTimestamp = request['timestamp']?.toString();
    final String? rawCreatedAt = request['createdAt']?.toString();
    final String submittedRelative = _formatTimestamp(
      rawTimestamp,
      fallback: rawCreatedAt,
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
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: false,
        builder:
            (context) => Scaffold(
              appBar: AppBar(
                backgroundColor: Colors.white,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios_rounded,
                    color: Color(0xFF64748B),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                title: const Text(
                  'OD Request Details',
                  style: TextStyle(
                    color: Color(0xFF1A202C),
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                actions: [
                  Container(
                    margin: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 16,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: statusColor, width: 1),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFFF8FAFC),
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 500),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.07),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                      border: Border.all(
                        color: Colors.grey.shade200,
                        width: 1.2,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.assignment_turned_in_rounded,
                              color: Color(0xFF3B82F6),
                              size: 28,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'OD Request',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 22,
                                color: Color(0xFF1A202C),
                              ),
                            ),
                            const Spacer(),
                            _buildStatusBadge(status, statusColor),
                          ],
                        ),
                        // Show message if staff approved and hod pending (not if already accepted)
                        if ((request['staffStatus']?.toString().toLowerCase() ==
                                    'accepted' ||
                                request['staffStatus']
                                        ?.toString()
                                        .toLowerCase() ==
                                    'approved') &&
                            (request['hodStatus']?.toString().toLowerCase() ==
                                    'pending' ||
                                request['hodStatus'] == null) &&
                            request['status']?.toString().toLowerCase() !=
                                'accepted' &&
                            request['hodStatus']?.toString().toLowerCase() !=
                                'accepted')
                          Padding(
                            padding: const EdgeInsets.only(
                              top: 12.0,
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
                                Expanded(
                                  child: Text(
                                    'Approved by staff, waiting for HOD approval',
                                    style: TextStyle(
                                      color: Color(0xFF10B981),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                    overflow: TextOverflow.visible,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 18),
                        Divider(color: Colors.grey.shade300, thickness: 1),
                        const SizedBox(height: 18),
                        Text(
                          'Applicant Details',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: Color(0xFF3B82F6),
                          ),
                        ),
                        const SizedBox(height: 10),
                        _buildDetailRow(
                          Icons.person_rounded,
                          'From',
                          request['from'] ?? '',
                        ),
                        const SizedBox(height: 8),
                        _buildDetailRow(
                          Icons.business_rounded,
                          'To',
                          request['to'] ?? '',
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'Request Information',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: Color(0xFF3B82F6),
                          ),
                        ),
                        const SizedBox(height: 10),
                        _buildDetailRow(
                          Icons.subject_rounded,
                          'Subject',
                          request['subject'] ?? '',
                        ),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.access_time_rounded,
                              size: 18,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Submitted:',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF374151),
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Column(
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
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'Reason',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: Color(0xFF3B82F6),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Text(
                            request['reason'] ?? '',
                            style: const TextStyle(
                              color: Colors.black87,
                              fontSize: 14,
                              height: 1.5,
                            ),
                          ),
                        ),
                        if (status == 'rejected' &&
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
                                    'Rejection Reason: $rejectionReason',
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
                        if ((request['status']?.toString().toLowerCase() ==
                                'accepted' ||
                            request['status']?.toString().toLowerCase() ==
                                'approved' ||
                            request['hodStatus']?.toString().toLowerCase() ==
                                'accepted' ||
                            request['hodStatus']?.toString().toLowerCase() ==
                                'approved')) ...[
                          const SizedBox(height: 28),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                _downloadODRequest(request);
                              },
                              icon: const Icon(
                                Icons.download_rounded,
                                size: 20,
                              ),
                              label: const Text(
                                'Download OD Request',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
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
            ),
      ),
    );
  }

  void _editODRequest(Map<String, dynamic> request, int index) {
    // Check if request is approved - don't allow editing
    final String status = (request['status'] ?? '').toString().toLowerCase();
    if (status == 'accepted' || status == 'approved') {
      _showSnackBar('Cannot edit approved requests', Colors.orange);
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        final TextEditingController subjectController = TextEditingController(
          text: request['subject'],
        );
        final TextEditingController contentController = TextEditingController(
          text: request['content'],
        );
        final TextEditingController fromController = TextEditingController(
          text: request['from'],
        );
        final TextEditingController toController = TextEditingController(
          text: request['to'],
        );

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
                'Edit OD Request',
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
                      controller: fromController,
                      decoration: InputDecoration(
                        labelText: 'From',
                        prefixIcon: Icon(
                          Icons.person_outline_rounded,
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
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: TextField(
                      controller: toController,
                      decoration: InputDecoration(
                        labelText: 'To',
                        prefixIcon: Icon(
                          Icons.business_rounded,
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
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: TextField(
                      controller: subjectController,
                      decoration: InputDecoration(
                        labelText: 'Subject',
                        prefixIcon: Icon(
                          Icons.subject_rounded,
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
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: TextField(
                      controller: contentController,
                      decoration: InputDecoration(
                        labelText: 'Content',
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
                      maxLines: 5,
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
                _updateODRequestInDatabase(
                  request,
                  fromController.text.trim(),
                  toController.text.trim(),
                  subjectController.text.trim(),
                  contentController.text.trim(),
                  index,
                );
                Navigator.of(context).pop();
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
  }

  void _deleteODRequest(Map<String, dynamic> request, int index) {
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
            'Are you sure you want to delete this OD request? This action cannot be undone.',
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
                _deleteODRequestFromDatabase(request, index);
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

  Future<void> _updateODRequestInDatabase(
    Map<String, dynamic> request,
    String from,
    String to,
    String subject,
    String content,
    int index,
  ) async {
    try {
      final mongoUri = LocalConfig.mongoUri;
      const collectionName = "od_requests";

      final db = await mongo.Db.create(mongoUri);
      await db.open();
      final collection = db.collection(collectionName);

      // Find the request by student email and timestamp to update it
      final filter = {
        'studentEmail': request['studentEmail'],
        'createdAt': request['createdAt'] ?? request['timestamp'],
      };

      final update = {
        r'$set': {
          'from': from,
          'to': to,
          'subject': subject,
          'content': content,
          'updatedAt': DateTime.now().toIso8601String(),
        },
      };

      final result = await collection.updateOne(filter, update);
      await db.close();

      if (result.isSuccess) {
        setState(() {
          myRequests[index]['from'] = from;
          myRequests[index]['to'] = to;
          myRequests[index]['subject'] = subject;
          myRequests[index]['content'] = content;
        });

        _showSnackBar('Request updated successfully!', Colors.green);
      } else {
        _showSnackBar(
          'Failed to update request. Please try again.',
          Colors.red,
        );
      }
    } catch (e) {
      _showSnackBar('Error updating request: $e', Colors.red);
    }
  }

  Future<void> _deleteODRequestFromDatabase(
    Map<String, dynamic> request,
    int index,
  ) async {
    try {
      final mongoUri = LocalConfig.mongoUri;
      const collectionName = "od_requests";

      final db = await mongo.Db.create(mongoUri);
      await db.open();
      final collection = db.collection(collectionName);

      // Find the request by student email and timestamp to delete it
      final filter = {
        'studentEmail': request['studentEmail'],
        'createdAt': request['createdAt'] ?? request['timestamp'],
      };

      final result = await collection.deleteOne(filter);
      await db.close();

      if (result.isSuccess) {
        setState(() {
          myRequests.removeAt(index);
        });

        _showSnackBar('Request deleted successfully!', Colors.green);
      } else {
        _showSnackBar(
          'Failed to delete request. Please try again.',
          Colors.red,
        );
      }
    } catch (e) {
      _showSnackBar('Error deleting request: $e', Colors.red);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
