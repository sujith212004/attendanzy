import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mongo_dart/mongo_dart.dart' as mongo;
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/config/local_config.dart';

class AttendanceDetailsScreen extends StatefulWidget {
  final List<Map<String, dynamic>> presentStudents;
  final List<Map<String, dynamic>> absentStudents;
  final List<Map<String, dynamic>> onDutyStudents;
  final Function(Map<String, bool>) onEdit;
  final String department;
  final String year;
  final String section;

  const AttendanceDetailsScreen({
    super.key,
    required this.presentStudents,
    required this.absentStudents,
    required this.onDutyStudents,
    required this.onEdit,
    required this.department,
    required this.year,
    required this.section,
  });

  @override
  _AttendanceDetailsScreenState createState() =>
      _AttendanceDetailsScreenState();
}

class _AttendanceDetailsScreenState extends State<AttendanceDetailsScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _animationController;
  late AnimationController _fabController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _scaleAnimation;

  final String mongoUri = LocalConfig.mongoUri;
  final String studentCollection = "students";
  final String absenteesCollection = "absentees";

  String? classInChargeNumber;
  bool isLoading = true;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _tabController = TabController(length: 3, vsync: this);
    _initializeData();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fabController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _animationController.dispose();
    _fabController.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    await fetchClassInChargeNumber();
    setState(() => isLoading = false);
    _animationController.forward();
    HapticFeedback.lightImpact();
  }

  Future<void> fetchClassInChargeNumber() async {
    try {
      var db = await mongo.Db.create(mongoUri);
      await db.open();

      var collection = db.collection(studentCollection);
      var result = await collection.findOne({
        "dep": widget.department,
        "year": widget.year,
        "sec": widget.section,
      });

      if (result != null && result.containsKey("incharge_no")) {
        setState(() => classInChargeNumber = result["incharge_no"]);
      } else {
        _showSnackBar(
          "Incharge number not found for the selected department, year, and section.",
          isError: true,
        );
      }

      await db.close();
    } catch (e) {
      _showSnackBar("Error fetching incharge number: $e", isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor:
            isError ? const Color(0xFFEF4444) : const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> saveAttendanceToDatabase() async {
    setState(() => isSaving = true);
    _fabController.forward();
    HapticFeedback.mediumImpact();

    try {
      var db = await mongo.Db.create(mongoUri);
      await db.open();

      var collection = db.collection(absenteesCollection);
      var dataToInsert = {
        "date": DateTime.now().toIso8601String(),
        "department": widget.department,
        "year": widget.year,
        "section": widget.section,
        "total_present": widget.presentStudents.length,
        "total_absent": widget.absentStudents.length,
        "total_on_duty": widget.onDutyStudents.length,
        "present_students":
            widget.presentStudents
                .map(
                  (student) => {
                    "name": student['name'],
                    "register_no": student['register_no'],
                  },
                )
                .toList(),
        "absentees":
            widget.absentStudents
                .map(
                  (student) => {
                    "name": student['name'],
                    "register_no": student['register_no'],
                  },
                )
                .toList(),
        "on_duty":
            widget.onDutyStudents
                .map(
                  (student) => {
                    "name": student['name'],
                    "register_no": student['register_no'],
                  },
                )
                .toList(),
      };

      var result = await collection.insertOne(dataToInsert);
      await db.close();

      if (result.isSuccess) {
        _showSnackBar("Attendance successfully stored in the database!");
        HapticFeedback.heavyImpact();
      } else {
        _showSnackBar(
          "Failed to store attendance in the database!",
          isError: true,
        );
        HapticFeedback.heavyImpact();
      }
    } catch (e) {
      _showSnackBar("Error saving attendance: $e", isError: true);
      HapticFeedback.heavyImpact();
    } finally {
      setState(() => isSaving = false);
      _fabController.reverse();
    }
  }

  Future<void> shareAttendanceList() async {
    if (isLoading) {
      _showSnackBar("Please wait, fetching incharge number...", isError: true);
      return;
    }

    if (widget.absentStudents.isEmpty && widget.onDutyStudents.isEmpty) {
      _showSnackBar(
        "No absentees or on-duty students to share.",
        isError: true,
      );
      return;
    }

    if (classInChargeNumber == null) {
      _showSnackBar("Incharge number not available.", isError: true);
      return;
    }

    await saveAttendanceToDatabase();

    String formattedDate =
        "${DateTime.now().day}-${DateTime.now().month}-${DateTime.now().year}";

    String message = "📊 Attendance Report for $formattedDate\n\n";
    message += "📈 Summary:\n";
    message += "• Present: ${widget.presentStudents.length}\n";
    message += "• Absent: ${widget.absentStudents.length}\n";
    message += "• On Duty: ${widget.onDutyStudents.length}\n\n";

    if (widget.absentStudents.isNotEmpty) {
      message += "❌ Absentees:\n";
      for (int i = 0; i < widget.absentStudents.length; i++) {
        message +=
            "${i + 1}. ${widget.absentStudents[i]['name']} (${widget.absentStudents[i]['register_no']})\n";
      }
    }

    if (widget.onDutyStudents.isNotEmpty) {
      message += "\n🏢 On Duty:\n";
      for (int i = 0; i < widget.onDutyStudents.length; i++) {
        message +=
            "${i + 1}. ${widget.onDutyStudents[i]['name']} (${widget.onDutyStudents[i]['register_no']})\n";
      }
    }

    String encodedMessage = Uri.encodeComponent(message);
    String whatsappUrl =
        "https://wa.me/$classInChargeNumber?text=$encodedMessage";

    HapticFeedback.mediumImpact();

    try {
      if (await canLaunchUrl(Uri.parse(whatsappUrl))) {
        await launchUrl(Uri.parse(whatsappUrl));
      } else {
        _showSnackBar("WhatsApp is not installed!", isError: true);
      }
    } catch (e) {
      _showSnackBar("Error launching WhatsApp: $e", isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildProfessionalAppBar(),
      body: isLoading ? _buildLoadingState() : _buildMainContent(),
      floatingActionButton: _buildFloatingActionButtons(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  PreferredSizeWidget _buildProfessionalAppBar() {
    return AppBar(
      title: LayoutBuilder(
        builder: (context, constraints) {
          final availableWidth = constraints.maxWidth;
          final isVerySmall = availableWidth < 200;
          final isSmall = availableWidth < 280;
          final isMedium = availableWidth < 350;

          return Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isVerySmall ? 'Attendance' : 'Attendance Details',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize:
                        isVerySmall
                            ? 13
                            : (isSmall ? 15 : (isMedium ? 16 : 18)),
                    color: const Color(0xFF1A202C),
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                if (!isVerySmall) ...[
                  const SizedBox(height: 1),
                  Flexible(
                    child: Text(
                      isSmall
                          ? '${widget.department} ${widget.year}${widget.section}'
                          : '${widget.department} ${widget.year}-${widget.section} • ${widget.presentStudents.length + widget.absentStudents.length + widget.onDutyStudents.length} Students',
                      style: TextStyle(
                        fontSize: isSmall ? 9 : (isMedium ? 10 : 12),
                        color: const Color(0xFF6B7280),
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ],
            ),
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
      actions: [
        LayoutBuilder(
          builder: (context, constraints) {
            final screenWidth = MediaQuery.of(context).size.width;
            final totalStudents =
                widget.presentStudents.length +
                widget.absentStudents.length +
                widget.onDutyStudents.length;

            if (screenWidth < 380) {
              // For very small screens, show just the number with minimal design
              return Container(
                margin: const EdgeInsets.only(right: 8, top: 4, bottom: 4),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                constraints: const BoxConstraints(maxWidth: 50),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Text(
                    totalStudents > 99 ? '99+' : '$totalStudents',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF3B82F6),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            } else if (screenWidth < 450) {
              // For medium screens, show compact summary
              return Container(
                margin: const EdgeInsets.only(right: 12),
                constraints: const BoxConstraints(maxWidth: 70),
                child: _buildAttendanceSummary(),
              );
            } else {
              // For larger screens, show the full summary
              return Container(
                margin: const EdgeInsets.only(right: 16),
                child: _buildAttendanceSummary(),
              );
            }
          },
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(50),
        child: Container(
          color: Colors.white,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isSmallScreen = constraints.maxWidth < 400;
              return TabBar(
                controller: _tabController,
                indicatorColor: const Color(0xFF3B82F6),
                indicatorWeight: 3,
                labelColor: const Color(0xFF3B82F6),
                unselectedLabelColor: const Color(0xFF6B7280),
                labelStyle: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: isSmallScreen ? 12 : 14,
                ),
                unselectedLabelStyle: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: isSmallScreen ? 11 : 13,
                ),
                isScrollable: isSmallScreen,
                tabAlignment:
                    isSmallScreen ? TabAlignment.start : TabAlignment.fill,
                tabs: [
                  Tab(
                    icon: const Icon(Icons.check_circle_rounded, size: 16),
                    child: Text(
                      isSmallScreen
                          ? 'Present\n(${widget.presentStudents.length})'
                          : 'Present (${widget.presentStudents.length})',
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Tab(
                    icon: const Icon(Icons.cancel_rounded, size: 16),
                    child: Text(
                      isSmallScreen
                          ? 'Absent\n(${widget.absentStudents.length})'
                          : 'Absent (${widget.absentStudents.length})',
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Tab(
                    icon: const Icon(Icons.business_center_rounded, size: 16),
                    child: Text(
                      isSmallScreen
                          ? 'OD\n(${widget.onDutyStudents.length})'
                          : 'On Duty (${widget.onDutyStudents.length})',
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildAttendanceSummary() {
    final totalStudents =
        widget.presentStudents.length +
        widget.absentStudents.length +
        widget.onDutyStudents.length;

    return Container(
      constraints: const BoxConstraints(maxWidth: 80, maxHeight: 50),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF3B82F6).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Total',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w500,
              color: Color(0xFF6B7280),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Flexible(
            child: Text(
              totalStudents > 999 ? '999+' : '$totalStudents',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF3B82F6),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ],
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
          SizedBox(height: 24),
          Text(
            'Loading attendance details...',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: TabBarView(
        controller: _tabController,
        children: [
          _buildStudentList(
            widget.presentStudents,
            "🎉 All students are present!",
            const Color(0xFF10B981),
            Icons.check_circle_rounded,
          ),
          _buildStudentList(
            widget.absentStudents,
            "✅ No absentees today!",
            const Color(0xFFEF4444),
            Icons.cancel_rounded,
          ),
          _buildStudentList(
            widget.onDutyStudents,
            "📋 No students on duty today!",
            const Color(0xFFF59E0B),
            Icons.business_center_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildStudentList(
    List<Map<String, dynamic>> students,
    String emptyMessage,
    Color color,
    IconData icon,
  ) {
    if (students.isEmpty) {
      return Center(
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Icon(icon, size: 48, color: color),
              ),
              const SizedBox(height: 24),
              Text(
                emptyMessage,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF374151),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: students.length,
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
          child: _buildStudentCard(students[index], index, color, icon),
        );
      },
    );
  }

  Widget _buildStudentCard(
    Map<String, dynamic> student,
    int index,
    Color color,
    IconData icon,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(25),
                border: Border.all(color: color.withOpacity(0.3)),
              ),
              child: Center(
                child: Text(
                  student['name'][0].toUpperCase(),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    student['name'],
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A202C),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.badge_rounded,
                        size: 14,
                        color: Color(0xFF6B7280),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        student['register_no'],
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF6B7280),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingActionButtons() {
    return AnimatedBuilder(
      animation: _fabController,
      builder: (context, child) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final screenWidth = MediaQuery.of(context).size.width;
            final isSmallScreen = screenWidth < 400;

            return Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? 12 : 16,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Transform.scale(
                      scale: 1.0 - (_fabController.value * 0.1),
                      child: FloatingActionButton.extended(
                        onPressed: () => Navigator.pop(context),
                        backgroundColor: const Color(0xFF6B7280),
                        foregroundColor: Colors.white,
                        heroTag: "edit",
                        icon: const Icon(Icons.edit_rounded, size: 18),
                        label: Text(
                          isSmallScreen ? 'Edit' : 'Edit Attendance',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: isSmallScreen ? 12 : 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: isSmallScreen ? 12 : 16),
                  Expanded(
                    child: Transform.scale(
                      scale: 1.0 - (_fabController.value * 0.1),
                      child: FloatingActionButton.extended(
                        onPressed: isSaving ? null : shareAttendanceList,
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        heroTag: "whatsapp",
                        icon:
                            isSaving
                                ? Transform.rotate(
                                  angle: _fabController.value * 2 * 3.14159,
                                  child: const Icon(
                                    Icons.sync_rounded,
                                    size: 18,
                                  ),
                                )
                                : const Icon(Icons.share_rounded, size: 18),
                        label: Text(
                          isSaving
                              ? (isSmallScreen ? 'Saving...' : 'Saving...')
                              : (isSmallScreen ? 'Share' : 'Share Report'),
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: isSmallScreen ? 12 : 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
