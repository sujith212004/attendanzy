import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:mongo_dart/mongo_dart.dart' as mongo;
import 'attendancedetails.dart'; // Assuming this is the attendance details page.
import '../../../../core/config/local_config.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  _AttendanceScreenState createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen>
    with TickerProviderStateMixin {
  List<Map<String, dynamic>> students = [];
  Map<String, dynamic> attendance =
      {}; // true (Present), false (Absent), null (OD)
  bool isLoading = true;
  String searchQuery = "";

  // Animation controllers
  late AnimationController _animationController;
  late AnimationController _floatingButtonController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;

  final String mongoUri = LocalConfig.mongoUri;
  final String studentCollection = "students";

  String? department;
  String? year;
  String? section;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _floatingButtonController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _floatingButtonController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final arguments =
        ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    department = arguments['department'];
    year = arguments['year'];
    section = arguments['section'];

    fetchStudents(department, year, section);
  }

  Future<void> fetchStudents(
    String? department,
    String? year,
    String? section,
  ) async {
    setState(() => isLoading = true);
    try {
      var db = await mongo.Db.create(mongoUri);
      await db.open();
      var collection = db.collection(studentCollection);

      // Fetching the entire document that matches department, year, and section
      var studentList = await collection.findOne({
        "dep": department,
        "year": year,
        "sec": section,
      });

      if (studentList != null && studentList['students'] != null) {
        setState(() {
          // Extract the students array
          students = List<Map<String, dynamic>>.from(studentList['students']);
          attendance = {
            for (var student in students) student["register_no"]: true,
          };
        });
        _animationController.forward();
        HapticFeedback.lightImpact();
      } else {
        _showSnackBar(
          "No students found for the selected parameters!",
          isError: true,
        );
      }
      await db.close();
    } catch (e) {
      _showSnackBar("Failed to load students: $e", isError: true);
      HapticFeedback.heavyImpact();
    } finally {
      setState(() => isLoading = false);
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

  void submitAttendance() async {
    _floatingButtonController.forward();
    HapticFeedback.mediumImpact();

    List<Map<String, dynamic>> absentees =
        students.where((s) => attendance[s["register_no"]] == false).toList();
    List<Map<String, dynamic>> presents =
        students.where((s) => attendance[s["register_no"]] == true).toList();
    List<Map<String, dynamic>> onDuty =
        students.where((s) => attendance[s["register_no"]] == null).toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => AttendanceDetailsScreen(
              presentStudents: presents,
              absentStudents: absentees,
              onDutyStudents: onDuty,
              department: department ?? '',
              year: year ?? '',
              section: section ?? '',
              onEdit: (updatedAttendance) {
                setState(() {
                  attendance = updatedAttendance;
                });
              },
            ),
      ),
    ).then((_) => _floatingButtonController.reverse());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildProfessionalAppBar(),
      body: isLoading ? _buildLoadingState() : _buildMainContent(),
      floatingActionButton: _buildFloatingActionButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
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
                  Icons.how_to_reg_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mark Attendance',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: constraints.maxWidth < 300 ? 16 : 18,
                        color: const Color(0xFF1A202C),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (department != null && year != null && section != null)
                      Text(
                        '$department $year-$section',
                        style: TextStyle(
                          fontSize: constraints.maxWidth < 300 ? 11 : 12,
                          color: const Color(0xFF6B7280),
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
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
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 16),
          child: _buildAttendanceSummary(),
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
                const Color(0xFF3B82F6).withOpacity(0.2),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAttendanceSummary() {
    final presentCount = attendance.values.where((v) => v == true).length;
    final absentCount = attendance.values.where((v) => v == false).length;
    final odCount = attendance.values.where((v) => v == null).length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF3B82F6).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSummaryChip('P', presentCount, const Color(0xFF10B981)),
          const SizedBox(width: 4),
          _buildSummaryChip('A', absentCount, const Color(0xFFEF4444)),
          const SizedBox(width: 4),
          _buildSummaryChip('OD', odCount, const Color(0xFFF59E0B)),
        ],
      ),
    );
  }

  Widget _buildSummaryChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(width: 2),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          LoadingAnimationWidget.staggeredDotsWave(
            color: const Color(0xFF3B82F6),
            size: 50,
          ),
          const SizedBox(height: 24),
          const Text(
            'Loading students...',
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
    final filteredStudents =
        students.where((student) {
          return searchQuery.isEmpty ||
              student['name'].toLowerCase().contains(
                searchQuery.toLowerCase(),
              ) ||
              student['register_no'].toLowerCase().contains(
                searchQuery.toLowerCase(),
              );
        }).toList();

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        children: [
          _buildSearchSection(),
          Expanded(
            child:
                students.isEmpty
                    ? _buildEmptyState()
                    : _buildStudentsList(filteredStudents),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Student List (${students.length})',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A202C),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Mark attendance for each student',
                      style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                    ),
                  ],
                ),
              ),
              _buildMarkAllButtons(),
            ],
          ),
          const SizedBox(height: 16),
          _buildSearchField(),
        ],
      ),
    );
  }

  Widget _buildMarkAllButtons() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildQuickActionButton(
          'All Present',
          Icons.check_circle_rounded,
          const Color(0xFF10B981),
          () => _markAllStudents(true),
        ),
        const SizedBox(width: 8),
        _buildQuickActionButton(
          'All Absent',
          Icons.cancel_rounded,
          const Color(0xFFEF4444),
          () => _markAllStudents(false),
        ),
      ],
    );
  }

  Widget _buildQuickActionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: () {
        onTap();
        HapticFeedback.lightImpact();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _markAllStudents(bool isPresent) {
    setState(() {
      for (var student in students) {
        attendance[student["register_no"]] = isPresent;
      }
    });
  }

  Widget _buildSearchField() {
    return Container(
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
      child: TextField(
        onChanged: (value) => setState(() => searchQuery = value),
        decoration: InputDecoration(
          hintText: "Search by name or register number...",
          hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: Color(0xFF6B7280),
          ),
          suffixIcon:
              searchQuery.isNotEmpty
                  ? IconButton(
                    icon: const Icon(
                      Icons.clear_rounded,
                      color: Color(0xFF6B7280),
                    ),
                    onPressed: () => setState(() => searchQuery = ""),
                  )
                  : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
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
              Icons.people_outline_rounded,
              size: 48,
              color: Color(0xFF3B82F6),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No Students Found',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'No students available for attendance marking',
            style: TextStyle(fontSize: 16, color: Color(0xFF6B7280)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStudentsList(List<Map<String, dynamic>> filteredStudents) {
    if (filteredStudents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withOpacity(0.1),
                borderRadius: BorderRadius.circular(50),
              ),
              child: const Icon(
                Icons.search_off_rounded,
                size: 48,
                color: Color(0xFFF59E0B),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Match Found',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No students match "$searchQuery"',
              style: const TextStyle(fontSize: 16, color: Color(0xFF6B7280)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
      itemCount: filteredStudents.length,
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
          child: _buildStudentCard(filteredStudents[index], index),
        );
      },
    );
  }

  Widget _buildStudentCard(Map<String, dynamic> student, int index) {
    final registerNo = student["register_no"];
    final currentAttendance = attendance[registerNo];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _getAttendanceColor(currentAttendance).withOpacity(0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                _buildStudentAvatar(student),
                const SizedBox(width: 16),
                Expanded(child: _buildStudentInfo(student)),
              ],
            ),
            const SizedBox(height: 16),
            _buildAttendanceOptions(registerNo, currentAttendance),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentAvatar(Map<String, dynamic> student) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF3B82F6), const Color(0xFF1D4ED8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3B82F6).withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Text(
          student['name'][0].toUpperCase(),
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildStudentInfo(Map<String, dynamic> student) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          student['name'],
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A202C),
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.badge_rounded, size: 16, color: Color(0xFF6B7280)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                student['register_no'],
                style: const TextStyle(
                  fontSize: 15,
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAttendanceOptions(String registerNo, dynamic currentAttendance) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildAttendanceButton(
          'P',
          true,
          registerNo,
          currentAttendance,
          const Color(0xFF10B981),
          Icons.check_circle_rounded,
        ),
        _buildAttendanceButton(
          'A',
          false,
          registerNo,
          currentAttendance,
          const Color(0xFFEF4444),
          Icons.cancel_rounded,
        ),
        _buildAttendanceButton(
          'OD',
          null,
          registerNo,
          currentAttendance,
          const Color(0xFFF59E0B),
          Icons.business_center_rounded,
        ),
      ],
    );
  }

  Widget _buildAttendanceButton(
    String label,
    dynamic value,
    String registerNo,
    dynamic currentValue,
    Color color,
    IconData icon,
  ) {
    final isSelected = currentValue == value;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => attendance[registerNo] = value);
          HapticFeedback.selectionClick();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected ? color : color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: color.withOpacity(isSelected ? 1.0 : 0.3),
              width: isSelected ? 2 : 1,
            ),
            boxShadow:
                isSelected
                    ? [
                      BoxShadow(
                        color: color.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                    : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: isSelected ? Colors.white : color),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getAttendanceColor(dynamic value) {
    if (value == true) return const Color(0xFF10B981);
    if (value == false) return const Color(0xFFEF4444);
    if (value == null) return const Color(0xFFF59E0B);
    return const Color(0xFF6B7280);
  }

  Widget _buildFloatingActionButton() {
    return AnimatedBuilder(
      animation: _floatingButtonController,
      builder: (context, child) {
        return Transform.scale(
          scale: 1.0 - (_floatingButtonController.value * 0.1),
          child: FloatingActionButton.extended(
            onPressed: students.isEmpty ? null : submitAttendance,
            backgroundColor: const Color(0xFF3B82F6),
            foregroundColor: Colors.white,
            elevation: 8,
            icon: Transform.rotate(
              angle: _floatingButtonController.value * 2 * 3.14159,
              child: const Icon(Icons.send_rounded),
            ),
            label: const Text(
              'Submit Attendance',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        );
      },
    );
  }
}
