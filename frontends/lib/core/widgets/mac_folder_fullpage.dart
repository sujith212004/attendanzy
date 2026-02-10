import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Full-page Mac-style folder widget that displays requests inside a folder view
/// Clicking a folder opens it to reveal the contents

class MacFolderFullPage extends StatefulWidget {
  final String title;
  final String acceptedLabel; // "Accepted" for OD, "Approved" for Leave
  final int pendingCount;
  final int acceptedCount;
  final int rejectedCount;
  final List<Map<String, dynamic>> allRequests;
  final Widget Function(Map<String, dynamic> request) requestCardBuilder;
  final VoidCallback onRefresh;
  final bool loading;
  final String Function(Map<String, dynamic>) getStatusFromRequest;

  const MacFolderFullPage({
    Key? key,
    required this.title,
    required this.acceptedLabel,
    required this.pendingCount,
    required this.acceptedCount,
    required this.rejectedCount,
    required this.allRequests,
    required this.requestCardBuilder,
    required this.onRefresh,
    required this.loading,
    required this.getStatusFromRequest,
  }) : super(key: key);

  @override
  State<MacFolderFullPage> createState() => _MacFolderFullPageState();
}

/// Custom painter for the realistic folder tab
class _RealisticFolderTabPainter extends CustomPainter {
  final Color color;
  final Color secondaryColor;

  _RealisticFolderTabPainter({
    required this.color,
    required this.secondaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final tabPaint =
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color, secondaryColor],
          ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path = Path();
    // Draw a curved tab shape
    path.moveTo(0, size.height * 0.8);
    path.quadraticBezierTo(
      size.width * 0.05,
      size.height * 0.1,
      size.width * 0.25,
      0,
    );
    path.lineTo(size.width * 0.75, 0);
    path.quadraticBezierTo(
      size.width * 0.95,
      size.height * 0.1,
      size.width,
      size.height * 0.8,
    );
    path.quadraticBezierTo(
      size.width * 0.98,
      size.height,
      size.width * 0.85,
      size.height,
    );
    path.lineTo(size.width * 0.15, size.height);
    path.quadraticBezierTo(
      size.width * 0.02,
      size.height,
      0,
      size.height * 0.8,
    );
    path.close();

    canvas.drawPath(path, tabPaint);

    // Optional: Add a subtle highlight
    final highlightPaint =
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white.withOpacity(0.25), Colors.transparent],
          ).createShader(Rect.fromLTWH(0, 0, size.width, size.height / 2));

    final highlightPath =
        Path()
          ..moveTo(0, size.height * 0.8)
          ..quadraticBezierTo(
            size.width * 0.05,
            size.height * 0.1,
            size.width * 0.25,
            0,
          )
          ..lineTo(size.width * 0.75, 0)
          ..quadraticBezierTo(
            size.width * 0.95,
            size.height * 0.1,
            size.width,
            size.height * 0.8,
          )
          ..lineTo(size.width, size.height * 0.4)
          ..quadraticBezierTo(
            size.width * 0.5,
            size.height * 0.1,
            0,
            size.height * 0.4,
          )
          ..close();

    canvas.drawPath(highlightPath, highlightPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MacFolderFullPageState extends State<MacFolderFullPage>
    with SingleTickerProviderStateMixin {
  String? _openedFolder;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  // Filter states
  String _searchQuery = '';
  String _selectedDateFilter = 'All';
  String _sortOrder = 'Newest';
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  final List<String> _dateFilters = [
    'All',
    'Today',
    'This Week',
    'This Month',
    'Last 30 Days',
  ];
  final List<String> _sortOptions = [
    'Newest',
    'Oldest',
    'Name A-Z',
    'Name Z-A',
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _openFolder(String folderType) {
    setState(() {
      _openedFolder = folderType;
      _searchQuery = '';
      _searchController.clear();
      _selectedDateFilter = 'All';
      _sortOrder = 'Newest';
    });
    _animationController.forward(from: 0);
  }

  void _closeFolder() {
    _animationController.reverse().then((_) {
      if (mounted) {
        setState(() {
          _openedFolder = null;
          _searchQuery = '';
          _searchController.clear();
          _selectedDateFilter = 'All';
          _sortOrder = 'Newest';
        });
      }
    });
  }

  List<Map<String, dynamic>> _getFilteredRequests(String folderType) {
    List<Map<String, dynamic>> filtered =
        widget.allRequests.where((req) {
          final status = widget.getStatusFromRequest(req);
          switch (folderType) {
            case 'Pending':
              return status == 'pending' ||
                  status == 'pending_hod' ||
                  status == '';
            case 'Accepted':
            case 'Approved':
              return status == 'accepted' || status == 'approved';
            case 'Rejected':
              return status == 'rejected';
            default:
              return true;
          }
        }).toList();

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered =
          filtered.where((req) {
            final name =
                (req['studentName'] ?? req['name'] ?? '')
                    .toString()
                    .toLowerCase();
            final email =
                (req['studentEmail'] ?? req['email'] ?? '')
                    .toString()
                    .toLowerCase();
            final type =
                (req['leaveType'] ?? req['odType'] ?? req['type'] ?? '')
                    .toString()
                    .toLowerCase();
            final reason = (req['reason'] ?? '').toString().toLowerCase();
            return name.contains(query) ||
                email.contains(query) ||
                type.contains(query) ||
                reason.contains(query);
          }).toList();
    }

    // Apply date filter
    if (_selectedDateFilter != 'All') {
      final now = DateTime.now();
      filtered =
          filtered.where((req) {
            DateTime? createdAt;
            try {
              if (req['createdAt'] is DateTime) {
                createdAt = req['createdAt'];
              } else if (req['createdAt'] != null) {
                createdAt = DateTime.parse(req['createdAt'].toString());
              }
            } catch (_) {}

            if (createdAt == null) return true;

            switch (_selectedDateFilter) {
              case 'Today':
                return createdAt.year == now.year &&
                    createdAt.month == now.month &&
                    createdAt.day == now.day;
              case 'This Week':
                final weekStart = now.subtract(Duration(days: now.weekday - 1));
                return createdAt.isAfter(
                  weekStart.subtract(const Duration(days: 1)),
                );
              case 'This Month':
                return createdAt.year == now.year &&
                    createdAt.month == now.month;
              case 'Last 30 Days':
                return createdAt.isAfter(
                  now.subtract(const Duration(days: 30)),
                );
              default:
                return true;
            }
          }).toList();
    }

    // Apply sorting
    filtered.sort((a, b) {
      switch (_sortOrder) {
        case 'Newest':
          return _compareDates(b['createdAt'], a['createdAt']);
        case 'Oldest':
          return _compareDates(a['createdAt'], b['createdAt']);
        case 'Name A-Z':
          final nameA =
              (a['studentName'] ?? a['name'] ?? '').toString().toLowerCase();
          final nameB =
              (b['studentName'] ?? b['name'] ?? '').toString().toLowerCase();
          return nameA.compareTo(nameB);
        case 'Name Z-A':
          final nameA =
              (a['studentName'] ?? a['name'] ?? '').toString().toLowerCase();
          final nameB =
              (b['studentName'] ?? b['name'] ?? '').toString().toLowerCase();
          return nameB.compareTo(nameA);
        default:
          return 0;
      }
    });

    return filtered;
  }

  int _compareDates(dynamic a, dynamic b) {
    try {
      DateTime dateA;
      DateTime dateB;

      if (a is DateTime) {
        dateA = a;
      } else if (a != null) {
        dateA = DateTime.parse(a.toString());
      } else {
        dateA = DateTime(1970);
      }

      if (b is DateTime) {
        dateB = b;
      } else if (b != null) {
        dateB = DateTime.parse(b.toString());
      } else {
        dateB = DateTime(1970);
      }

      return dateA.compareTo(dateB);
    } catch (_) {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_openedFolder != null) {
      return _buildOpenedFolderView();
    }
    return _buildFolderGrid();
  }

  Widget _buildFolderGrid() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with enhanced gradient
          Container(
            padding: const EdgeInsets.all(20),
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF3B82F6),
                  Color(0xFF1D4ED8),
                  Color(0xFF1E40AF),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF3B82F6).withOpacity(0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: const Icon(
                        Icons.folder_special_rounded,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${widget.allRequests.length} Total Requests',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withOpacity(0.95),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: widget.loading ? null : widget.onRefresh,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child:
                            widget.loading
                                ? Center(
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white.withOpacity(0.8),
                                      ),
                                    ),
                                  ),
                                )
                                : const Icon(
                                  Icons.refresh_rounded,
                                  color: Colors.white,
                                  size: 22,
                                ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Quick Stats Row
          Container(
            margin: const EdgeInsets.only(bottom: 20),
            child: Row(
              children: [
                Expanded(
                  child: _buildQuickStatCard(
                    label: 'Pending',
                    count: widget.pendingCount,
                    color: const Color(0xFFF59E0B),
                    icon: Icons.hourglass_empty_rounded,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildQuickStatCard(
                    label: widget.acceptedLabel,
                    count: widget.acceptedCount,
                    color: const Color(0xFF10B981),
                    icon: Icons.check_circle_rounded,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildQuickStatCard(
                    label: 'Rejected',
                    count: widget.rejectedCount,
                    color: const Color(0xFFEF4444),
                    icon: Icons.cancel_rounded,
                  ),
                ),
              ],
            ),
          ),

          // Instruction text
          Padding(
            padding: const EdgeInsets.only(bottom: 16, left: 4),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.touch_app_rounded,
                    size: 16,
                    color: const Color(0xFF3B82F6),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Tap a folder to view and manage requests',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),

          // Folders Grid
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 0.92,
            children: [
              _buildLargeFolderCard(
                title: 'Pending',
                count: widget.pendingCount,
                icon: Icons.hourglass_empty_rounded,
                color: const Color(0xFFF59E0B),
                secondaryColor: const Color(0xFFD97706),
              ),
              _buildLargeFolderCard(
                title: widget.acceptedLabel,
                count: widget.acceptedCount,
                icon: Icons.check_circle_rounded,
                color: const Color(0xFF10B981),
                secondaryColor: const Color(0xFF059669),
              ),
              _buildLargeFolderCard(
                title: 'Rejected',
                count: widget.rejectedCount,
                icon: Icons.cancel_rounded,
                color: const Color(0xFFEF4444),
                secondaryColor: const Color(0xFFDC2626),
              ),
              _buildAllFolderCard(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStatCard({
    required String label,
    required int count,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.15), width: 1),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 8),
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildLargeFolderCard({
    required String title,
    required int count,
    required IconData icon,
    required Color color,
    required Color secondaryColor,
  }) {
    final highlightColor = Color.lerp(color, Colors.white, 0.3)!;

    return GestureDetector(
      onTap: () => _openFolder(title),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFAFAFA),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.12),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Realistic folder shape
                  Expanded(
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // Back folder panel (depth layer)
                        Positioned(
                          top: 16,
                          left: 4,
                          right: 4,
                          bottom: 0,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  secondaryColor.withValues(alpha: 0.5),
                                  secondaryColor.withValues(alpha: 0.7),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),

                        // Folder tab (iconic curved tab)
                        Positioned(
                          top: 0,
                          left: 0,
                          child: CustomPaint(
                            size: const Size(60, 24),
                            painter: _RealisticFolderTabPainter(
                              color: highlightColor,
                              secondaryColor: color,
                            ),
                          ),
                        ),

                        // Main folder body
                        Positioned(
                          top: 18,
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [highlightColor, color, secondaryColor],
                                stops: const [0.0, 0.35, 1.0],
                              ),
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(4),
                                topRight: Radius.circular(14),
                                bottomLeft: Radius.circular(14),
                                bottomRight: Radius.circular(14),
                              ),
                              border: Border.all(
                                color: secondaryColor.withValues(alpha: 0.3),
                                width: 0.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: color.withValues(alpha: 0.25),
                                  blurRadius: 12,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Stack(
                              children: [
                                // Top glossy shine
                                Positioned(
                                  top: 0,
                                  left: 0,
                                  right: 0,
                                  height: 45,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.white.withValues(alpha: 0.4),
                                          Colors.white.withValues(alpha: 0.15),
                                          Colors.transparent,
                                        ],
                                      ),
                                      borderRadius: const BorderRadius.only(
                                        topRight: Radius.circular(14),
                                      ),
                                    ),
                                  ),
                                ),

                                // Paper texture
                                Positioned.fill(
                                  child: ClipRRect(
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(4),
                                      topRight: Radius.circular(14),
                                      bottomLeft: Radius.circular(14),
                                      bottomRight: Radius.circular(14),
                                    ),
                                    child: CustomPaint(
                                      painter: _LargePaperTexturePainter(
                                        color: Colors.white.withValues(
                                          alpha: 0.04,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                                // Folder crease/fold line
                                Positioned(
                                  top: 12,
                                  left: 12,
                                  right: 12,
                                  child: Container(
                                    height: 1.5,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.transparent,
                                          Colors.white.withValues(alpha: 0.25),
                                          Colors.white.withValues(alpha: 0.25),
                                          Colors.transparent,
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(1),
                                    ),
                                  ),
                                ),

                                // Content
                                Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(
                                            alpha: 0.2,
                                          ),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          icon,
                                          size: 32,
                                          color: Colors.white,
                                          shadows: [
                                            Shadow(
                                              color: Colors.black.withValues(
                                                alpha: 0.2,
                                              ),
                                              blurRadius: 6,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        title,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                          letterSpacing: 0.3,
                                          shadows: [
                                            Shadow(
                                              color: Color(0x40000000),
                                              blurRadius: 4,
                                              offset: Offset(0, 1),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Bottom shadow gradient
                                Positioned(
                                  bottom: 0,
                                  left: 0,
                                  right: 0,
                                  height: 16,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.transparent,
                                          Colors.black.withValues(alpha: 0.1),
                                        ],
                                      ),
                                      borderRadius: const BorderRadius.only(
                                        bottomLeft: Radius.circular(14),
                                        bottomRight: Radius.circular(14),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Count badge
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.white, const Color(0xFFF8F8F8)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: color.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    count.toString(),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAllFolderCard() {
    const color = Color(0xFF64748B);
    const secondaryColor = Color(0xFF475569);
    final highlightColor = const Color(0xFF94A3B8);

    return GestureDetector(
      onTap: () => _openFolder('All'),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFAFAFA),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Realistic folder shape
                  Expanded(
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // Back folder panel
                        Positioned(
                          top: 16,
                          left: 4,
                          right: 4,
                          bottom: 0,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  secondaryColor.withValues(alpha: 0.5),
                                  secondaryColor.withValues(alpha: 0.7),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),

                        // Folder tab
                        Positioned(
                          top: 0,
                          left: 0,
                          child: CustomPaint(
                            size: const Size(60, 24),
                            painter: _RealisticFolderTabPainter(
                              color: highlightColor,
                              secondaryColor: color,
                            ),
                          ),
                        ),

                        // Main folder body
                        Positioned(
                          top: 18,
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [highlightColor, color, secondaryColor],
                                stops: const [0.0, 0.35, 1.0],
                              ),
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(4),
                                topRight: Radius.circular(14),
                                bottomLeft: Radius.circular(14),
                                bottomRight: Radius.circular(14),
                              ),
                              border: Border.all(
                                color: secondaryColor.withValues(alpha: 0.3),
                                width: 0.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: color.withValues(alpha: 0.2),
                                  blurRadius: 12,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Stack(
                              children: [
                                // Top shine
                                Positioned(
                                  top: 0,
                                  left: 0,
                                  right: 0,
                                  height: 45,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.white.withValues(alpha: 0.35),
                                          Colors.white.withValues(alpha: 0.1),
                                          Colors.transparent,
                                        ],
                                      ),
                                      borderRadius: const BorderRadius.only(
                                        topRight: Radius.circular(14),
                                      ),
                                    ),
                                  ),
                                ),

                                // Paper texture
                                Positioned.fill(
                                  child: ClipRRect(
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(4),
                                      topRight: Radius.circular(14),
                                      bottomLeft: Radius.circular(14),
                                      bottomRight: Radius.circular(14),
                                    ),
                                    child: CustomPaint(
                                      painter: _LargePaperTexturePainter(
                                        color: Colors.white.withValues(
                                          alpha: 0.04,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                                // Crease line
                                Positioned(
                                  top: 12,
                                  left: 12,
                                  right: 12,
                                  child: Container(
                                    height: 1.5,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.transparent,
                                          Colors.white.withValues(alpha: 0.2),
                                          Colors.white.withValues(alpha: 0.2),
                                          Colors.transparent,
                                        ],
                                      ),
                                    ),
                                  ),
                                ),

                                // Content
                                Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(
                                            alpha: 0.2,
                                          ),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.folder_copy_rounded,
                                          size: 32,
                                          color: Colors.white,
                                          shadows: [
                                            Shadow(
                                              color: Colors.black.withValues(
                                                alpha: 0.2,
                                              ),
                                              blurRadius: 6,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      const Text(
                                        'All Requests',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                          letterSpacing: 0.3,
                                          shadows: [
                                            Shadow(
                                              color: Color(0x40000000),
                                              blurRadius: 4,
                                              offset: Offset(0, 1),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Bottom shadow
                                Positioned(
                                  bottom: 0,
                                  left: 0,
                                  right: 0,
                                  height: 16,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.transparent,
                                          Colors.black.withValues(alpha: 0.1),
                                        ],
                                      ),
                                      borderRadius: const BorderRadius.only(
                                        bottomLeft: Radius.circular(14),
                                        bottomRight: Radius.circular(14),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Count badge
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF64748B), Color(0xFF475569)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    widget.allRequests.length.toString(),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOpenedFolderView() {
    final folderType = _openedFolder!;
    final isAll = folderType == 'All';
    final filteredRequests = _getFilteredRequests(isAll ? 'All' : folderType);

    Color folderColor;
    Color secondaryColor;
    IconData folderIcon;

    switch (folderType) {
      case 'Pending':
        folderColor = const Color(0xFFF59E0B);
        secondaryColor = const Color(0xFFD97706);
        folderIcon = Icons.hourglass_empty_rounded;
        break;
      case 'Accepted':
      case 'Approved':
        folderColor = const Color(0xFF10B981);
        secondaryColor = const Color(0xFF059669);
        folderIcon = Icons.check_circle_rounded;
        break;
      case 'Rejected':
        folderColor = const Color(0xFFEF4444);
        secondaryColor = const Color(0xFFDC2626);
        folderIcon = Icons.cancel_rounded;
        break;
      default:
        folderColor = const Color(0xFF64748B);
        secondaryColor = const Color(0xFF475569);
        folderIcon = Icons.folder_copy_rounded;
    }

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: Column(
              children: [
                // Open folder header with enhanced design
                Container(
                  margin: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [folderColor, secondaryColor],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: folderColor.withOpacity(0.35),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Folder top flap with glassmorphism effect
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white.withOpacity(0.25),
                              Colors.white.withOpacity(0.05),
                            ],
                          ),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(24),
                            topRight: Radius.circular(24),
                          ),
                        ),
                        child: Row(
                          children: [
                            // Back button with hover effect
                            GestureDetector(
                              onTap: _closeFolder,
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.arrow_back_rounded,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Folder icon container
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Icon(
                                folderIcon,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    folderType,
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${filteredRequests.length} Requests',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white.withOpacity(0.95),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Refresh button
                            GestureDetector(
                              onTap: widget.loading ? null : widget.onRefresh,
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child:
                                    widget.loading
                                        ? SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  Colors.white.withOpacity(0.8),
                                                ),
                                          ),
                                        )
                                        : const Icon(
                                          Icons.refresh_rounded,
                                          color: Colors.white,
                                          size: 22,
                                        ),
                              ),
                            ),
                          ],
                        ),
                      ),

                     
                      Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(24),
                            bottomRight: Radius.circular(24),
                          ),
                        ),
                        child: Center(
                          child: Container(
                            width: 50,
                            height: 3,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Search and Filter Bar
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      // Search Bar
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _searchController,
                          focusNode: _searchFocusNode,
                          decoration: InputDecoration(
                            hintText: 'Search by name, email, or type...',
                            hintStyle: TextStyle(
                              color: const Color(0xFF94A3B8),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            prefixIcon: Container(
                              padding: const EdgeInsets.all(12),
                              child: Icon(
                                Icons.search_rounded,
                                color: folderColor,
                                size: 22,
                              ),
                            ),
                            suffixIcon:
                                _searchQuery.isNotEmpty
                                    ? GestureDetector(
                                      onTap: () {
                                        _searchController.clear();
                                        setState(() {
                                          _searchQuery = '';
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(12),
                                        child: Icon(
                                          Icons.close_rounded,
                                          color: const Color(0xFF94A3B8),
                                          size: 20,
                                        ),
                                      ),
                                    )
                                    : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Filter Pills Row
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            // Date Filter Dropdown
                            _buildFilterDropdown(
                              icon: Icons.calendar_today_rounded,
                              label: _selectedDateFilter,
                              color: folderColor,
                              items: _dateFilters,
                              onChanged: (value) {
                                setState(() {
                                  _selectedDateFilter = value!;
                                });
                              },
                            ),
                            const SizedBox(width: 10),
                            // Sort Dropdown
                            _buildFilterDropdown(
                              icon: Icons.sort_rounded,
                              label: _sortOrder,
                              color: folderColor,
                              items: _sortOptions,
                              onChanged: (value) {
                                setState(() {
                                  _sortOrder = value!;
                                });
                              },
                            ),
                            const SizedBox(width: 10),
                            // Clear Filters Button
                            if (_searchQuery.isNotEmpty ||
                                _selectedDateFilter != 'All' ||
                                _sortOrder != 'Newest')
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _searchController.clear();
                                    _searchQuery = '';
                                    _selectedDateFilter = 'All';
                                    _sortOrder = 'Newest';
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEE2E2),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color(0xFFFECACA),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.filter_alt_off_rounded,
                                        size: 16,
                                        color: const Color(0xFFEF4444),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Clear',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFFEF4444),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Folder contents - request list
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: folderColor.withOpacity(0.15),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child:
                          filteredRequests.isEmpty
                              ? _buildEmptyFolderContent(
                                folderType,
                                folderColor,
                                folderIcon,
                              )
                              : RefreshIndicator(
                                onRefresh: () async => widget.onRefresh(),
                                color: folderColor,
                                child: ListView.separated(
                                  padding: const EdgeInsets.all(16),
                                  itemCount: filteredRequests.length,
                                  separatorBuilder:
                                      (_, __) => const SizedBox(height: 12),
                                  itemBuilder: (context, index) {
                                    return widget.requestCardBuilder(
                                      filteredRequests[index],
                                    );
                                  },
                                ),
                              ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilterDropdown({
    required IconData icon,
    required String label,
    required Color color,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: label,
          icon: Icon(Icons.keyboard_arrow_down_rounded, color: color, size: 20),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: color,
          ),
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.circular(12),
          items:
              items.map((String item) {
                return DropdownMenuItem<String>(
                  value: item,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (items.indexOf(item) == 0)
                        Icon(icon, size: 16, color: color),
                      if (items.indexOf(item) == 0) const SizedBox(width: 8),
                      Text(
                        item,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color:
                              item == label ? color : const Color(0xFF475569),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
          onChanged: onChanged,
          selectedItemBuilder: (BuildContext context) {
            return items.map((String item) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 16, color: color),
                  const SizedBox(width: 8),
                  Text(
                    item,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ],
              );
            }).toList();
          },
        ),
      ),
    );
  }

  Widget _buildEmptyFolderContent(
    String folderType,
    Color color,
    IconData icon,
  ) {
    final hasFilters =
        _searchQuery.isNotEmpty ||
        _selectedDateFilter != 'All' ||
        _sortOrder != 'Newest';

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              hasFilters ? Icons.search_off_rounded : icon,
              size: 50,
              color: color.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            hasFilters
                ? 'No matching requests'
                : 'No ${folderType.toLowerCase()} requests',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasFilters
                ? 'Try adjusting your search or filters'
                : 'This folder is empty',
            style: TextStyle(fontSize: 14, color: const Color(0xFF94A3B8)),
          ),
          if (hasFilters) ...[
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () {
                setState(() {
                  _searchController.clear();
                  _searchQuery = '';
                  _selectedDateFilter = 'All';
                  _sortOrder = 'Newest';
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withOpacity(0.3), width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.filter_alt_off_rounded, size: 18, color: color),
                    const SizedBox(width: 8),
                    Text(
                      'Clear Filters',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Custom painter for the paper texture effect inside folder cards
class _LargePaperTexturePainter extends CustomPainter {
  final Color color;

  _LargePaperTexturePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.fill;

    // Draw subtle random lines to simulate a paper texture
    final random = math.Random(12345);
    for (int i = 0; i < 18; i++) {
      final y = random.nextDouble() * size.height;
      final opacity = 0.04 + random.nextDouble() * 0.04;
      paint.color = color.withOpacity(opacity);
      canvas.drawRect(
        Rect.fromLTWH(
          random.nextDouble() * size.width,
          y,
          size.width * (0.2 + random.nextDouble() * 0.2),
          1 + random.nextDouble() * 1.5,
        ),
        paint,
      );
    }
    // Optionally add some dots
    for (int i = 0; i < 12; i++) {
      paint.color = color.withOpacity(0.03 + random.nextDouble() * 0.04);
      canvas.drawCircle(
        Offset(
          random.nextDouble() * size.width,
          random.nextDouble() * size.height,
        ),
        0.7 + random.nextDouble() * 1.2,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Custom painter for folder background
class _FolderPainter extends CustomPainter {
  final Color color;
  final Color secondaryColor;

  _FolderPainter({required this.color, required this.secondaryColor});

  @override
  void paint(Canvas canvas, Size size) {
    // Just a subtle background effect
    final paint =
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withValues(alpha: 0.05),
              secondaryColor.withValues(alpha: 0.02),
            ],
          ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path =
        Path()..addRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(0, 0, size.width, size.height),
            const Radius.circular(24),
          ),
        );

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
