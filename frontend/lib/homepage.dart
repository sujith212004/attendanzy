import 'package:flutter/material.dart';
import 'package:flutter_attendence_app/DepAttendance.dart';
import 'package:flutter_attendence_app/Staff/Department_Report.dart';
import 'package:flutter_attendence_app/Staff/StaffOdrequest.dart';
import 'package:flutter_attendence_app/Staff/leavereqStaffpage.dart';
import 'package:flutter_attendence_app/Studentissuehodview.dart';
import 'package:flutter_attendence_app/Studentissues.dart';
import 'package:flutter_attendence_app/Timetabledepartment.dart';
import 'package:flutter_attendence_app/changepassword.dart';
import 'package:flutter_attendence_app/odrequestadminpage.dart';
import 'package:flutter_attendence_app/odrequestpage.dart';
import 'package:flutter_attendence_app/leave_request_page.dart';
import 'package:flutter_attendence_app/leave_requests_admin_page.dart';
import 'package:flutter_attendence_app/services/absentees_page.dart';
import 'request_status_page.dart';
import 'profile_page.dart';
import 'gpa_calculator.dart';
import 'cgpa_calculator_page.dart';
import 'package:url_launcher/url_launcher.dart';
import 'services/feedback_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomePage extends StatefulWidget {
  final String name;
  final String email;
  final Map<String, dynamic> profile;
  final bool isStaff;
  final String role; // 'user', 'staff', 'hod'

  const HomePage({
    super.key,
    required this.name,
    required this.email,
    required this.profile,
    required this.isStaff,
    required this.role,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _feedbackText = "";
  int _rating = 0;

  bool get isUser => widget.role.toLowerCase() == 'user';
  bool get isStaff => widget.role.toLowerCase() == 'staff';
  bool get isHod => widget.role.toLowerCase() == 'hod';

  // Cache commonly used values
  late final String dashboardTitle;
  late final String attendanceTitle;
  late final String attendanceSubtitle;
  late final IconData attendanceIcon;

  @override
  void initState() {
    super.initState();
    _initializeTitles();
  }

  void _initializeTitles() {
    dashboardTitle =
        isUser
            ? "Student Dashboard"
            : isStaff
            ? "Staff Dashboard"
            : "HOD Dashboard";

    if (isStaff) {
      attendanceTitle = "Mark Attendance";
      attendanceSubtitle = "Mark student attendance";
      attendanceIcon = Icons.groups;
    } else if (isHod) {
      attendanceTitle = "Department Attendance";
      attendanceSubtitle = "View department data";
      attendanceIcon = Icons.bar_chart;
    } else {
      attendanceTitle = "Absentees";
      attendanceSubtitle = "View absent students";
      attendanceIcon = Icons.groups;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              dashboardTitle,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 19,
                color: Color(0xFF1A202C),
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Welcome back, ${widget.name}!',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Color.fromARGB(255, 0, 0, 0),
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 20,
        toolbarHeight: 85,
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
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 20),
            child: PopupMenuButton<String>(
              onSelected: _handleMenuSelection,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 12,
              color: Colors.white,
              shadowColor: Colors.black.withOpacity(0.1),
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFE2E8F0),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.more_vert_rounded,
                  color: Color(0xFF475569),
                  size: 20,
                ),
              ),
              itemBuilder:
                  (_) => [
                    _buildPopupMenuItem(
                      "profile",
                      Icons.person_outline,
                      "Profile",
                    ),
                    _buildPopupMenuItem(
                      "change_password",
                      Icons.lock_outline,
                      "Change Password",
                    ),

                    _buildPopupMenuItem(
                      "feedback",
                      Icons.feedback_outlined,
                      "Send Feedback",
                    ),
                    _buildPopupMenuItem("about", Icons.info_outline, "About"),
                  ],
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Professional Header Card
            Container(
              width: double.infinity,
              height: 160, // Increased height for better content display
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF667EEA),
                    Color(0xFF764BA2),
                    Color(0xFF667EEA),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  stops: [0.0, 0.5, 1.0],
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF667EEA).withOpacity(0.4),
                    blurRadius: 25,
                    offset: const Offset(0, 12),
                    spreadRadius: 2,
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0.1),
                      Colors.white.withOpacity(0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 160),
                    child: Stack(
                      children: [
                        // Animated background patterns
                        Positioned(
                          right: -40,
                          top: -40,
                          child: Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  Colors.white.withOpacity(0.2),
                                  Colors.white.withOpacity(0.1),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: -30,
                          bottom: -30,
                          child: Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  Colors.white.withOpacity(0.15),
                                  Colors.white.withOpacity(0.05),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Floating accent circles
                        Positioned(
                          right: 60,
                          top: 25,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.3),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 45,
                          top: 35,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.4),
                            ),
                          ),
                        ),
                        // Main Content
                        Positioned.fill(
                          child: Padding(
                            padding: const EdgeInsets.all(28),
                            child: Row(
                              children: [
                                Container(
                                  width: 70,
                                  height: 70,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.white.withOpacity(0.9),
                                        Colors.white.withOpacity(0.7),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Icon(
                                    _getRoleIcon(),
                                    color: const Color(0xFF667EEA),
                                    size: 32,
                                  ),
                                ),
                                const SizedBox(width: 24),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _getGreeting(),
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                          letterSpacing: -0.3,
                                          shadows: [
                                            Shadow(
                                              color: Colors.black26,
                                              offset: Offset(0, 1),
                                              blurRadius: 2,
                                            ),
                                          ],
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 12),
                                      Flexible(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                Colors.white.withOpacity(0.25),
                                                Colors.white.withOpacity(0.15),
                                              ],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                            border: Border.all(
                                              color: Colors.white.withOpacity(
                                                0.3,
                                              ),
                                              width: 1,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(
                                                  0.1,
                                                ),
                                                blurRadius: 4,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  "Let's make today amazing!",
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w600,
                                                    shadows: [
                                                      Shadow(
                                                        color: Colors.black26,
                                                        offset: Offset(0, 0.5),
                                                        blurRadius: 1,
                                                      ),
                                                    ],
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Enhanced Time indicator
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.white.withOpacity(0.9),
                                        Colors.white.withOpacity(0.7),
                                      ],
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                    ),
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.3),
                                      width: 1,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: const Color(
                                            0xFF667EEA,
                                          ).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Icon(
                                          _getTimeIcon(),
                                          size: 20,
                                          color: const Color(0xFF667EEA),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        _getTimeLabel(),
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF667EEA),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 28),

            // Quick Access Section
            const Text(
              "Quick Access",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF2D3748),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Access your most used features",
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 20),

            // Primary Cards
            Row(
              children: [
                Expanded(
                  child: _buildModernCard(
                    title: 'Profile',
                    subtitle: 'View your details',
                    icon: Icons.person_outline,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4299E1), Color(0xFF3182CE)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    onTap: _navigateToProfile,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildModernCard(
                    title: 'Results',
                    subtitle: 'Check exam results',
                    icon: Icons.school_outlined,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF9F7AEA), Color(0xFF805AD5)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    onTap: _launchResultsUrl,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Staff-only Timetable Generation as a card
            if (isStaff) ...[
              Row(
                children: [
                  Expanded(
                    child: _buildModernCard(
                      title: "OD Requests Management",
                      subtitle: "Manage OD requests",
                      icon: Icons.schedule,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      onTap: () {
                        _navigateToStaffOdRequests();
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildModernCard(
                      title: "Leave Requests Management",
                      subtitle: "Manage leave requests",
                      icon: Icons.schedule,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      onTap: () {
                        _navigateToStaffLeaveRequests();
                      },
                    ),
                  ),
                ],
              ),
            ],

            // Role-specific sections
            if (isUser) ...[
              // const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _buildModernCard(
                      title: "Request Status",
                      subtitle: "Track OD & Leave requests",
                      icon: Icons.assignment_turned_in_outlined,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF00FFDE), Color(0xFF805AD5)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      onTap: _navigateToRequestStatus,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildModernCard(
                      title: "Student Issues",
                      subtitle: "Report issues",
                      icon: Icons.support_agent_outlined,
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF56565), Color(0xFFE53E3E)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      onTap: _navigateToStudentIssues,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildModernCard(
                      title: "OD Request",
                      subtitle: "Request on duty",
                      icon: Icons.event_available_outlined,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF68D391), Color(0xFF48BB78)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      onTap: _navigateToODRequest,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildModernCard(
                      title: "Leave Request",
                      subtitle: "Apply for leave",
                      icon: Icons.calendar_month_outlined,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      onTap: _navigateToLeaveRequest,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
            ],

            if (isHod) ...[
              Row(
                children: [
                  Expanded(
                    child: _buildModernCard(
                      title: "Student Issues",
                      subtitle: "View student issues",
                      icon: Icons.support_outlined,
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF56565), Color(0xFFE53E3E)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      onTap: _navigateToHODStudentIssues,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildModernCard(
                      title: "Department Reports",
                      subtitle: "View department reports",
                      icon: Icons.assessment_outlined,
                      gradient: const LinearGradient(
                        colors: [Color(0xFFfaa307), Color(0xFFffba08)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      onTap: _navigateToDepartmentReports,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: _buildModernCard(
                      title: "OD Management",
                      subtitle: "Manage OD requests",
                      icon: Icons.admin_panel_settings_outlined,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF68D391), Color(0xFF48BB78)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      onTap: _navigateToHODODRequests,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildModernCard(
                      title: "Leave Management",
                      subtitle: "Manage leave requests",
                      icon: Icons.calendar_today_outlined,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      onTap: _navigateToHODLeaveRequests,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
            ],
          ],
        ),
      ),
      // Help FloatingActionButton removed
    );
  }

  // Optimized navigation methods
  Future<void> _handleMenuSelection(String choice) async {
    switch (choice) {
      case "profile":
        _navigateToProfile();
        break;
      case "change_password":
        _navigateToChangePassword();
        break;
      // case 'help':
      //   _navigateToHelp(); // Help removed
      case "feedback":
        _showFeedbackDialog();
        break;
      case "about":
        _showAboutDialog();
        break;
      case "logout":
        await _handleLogout();
        break;
    }
  }

  void _handleAttendanceTap() {
    if (isStaff) {
      Navigator.of(context).pushNamed('/attendancepage');
    } else if (isHod) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => DepartmentAttendancePage()));
    } else {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => AbsenteesPage()));
    }
  }

  void _navigateToProfile() {
    // Prefer student sub-map for year/department/section if present
    dynamic year =
        (widget.profile['student'] != null &&
                widget.profile['student']['year'] != null)
            ? widget.profile['student']['year']
            : (widget.profile['year'] ?? widget.profile['studentYear']);
    dynamic department =
        (widget.profile['student'] != null &&
                widget.profile['student']['department'] != null)
            ? widget.profile['student']['department']
            : (widget.profile['department'] ??
                widget.profile['dept'] ??
                widget.profile['studentDept']);
    dynamic section =
        (widget.profile['student'] != null &&
                widget.profile['student']['section'] != null)
            ? widget.profile['student']['section']
            : (widget.profile['section'] ??
                widget.profile['sec'] ??
                widget.profile['studentSection']);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => ProfilePage(
              name: widget.name,
              email: widget.email,
              year: year?.toString() ?? '-',
              department: department?.toString() ?? '-',
              section: section?.toString() ?? '-',
            ),
      ),
    );
  }

  Future<void> _launchResultsUrl() async {
    const url = 'http://www.coe.act.edu.in/students';
    try {
      if (await canLaunch(url)) {
        await launch(url);
      } else {
        _showSnackBar('Could not launch the results page', isError: true);
      }
    } catch (e) {
      _showSnackBar('Error opening results page', isError: true);
    }
  }

  void _navigateToTimetable() {
    if (isHod) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const HODTimetablePage()));
    } else {
      Navigator.of(context).pushNamed('/timetablepage');
    }
  }

  void _navigateToCGPACalculator() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const CgpaCalculatorPage()));
  }

  void _navigateToDepartmentReports() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const DepartmentReport()));
  }

  void _navigateToGPACalculator() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const GPACalculatorPage()));
  }

  void _navigateToODRequest() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => ODRequestPage()));
  }

  void _navigateToLeaveRequest() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const LeaveRequestPage()));
  }

  void _navigateToStudentIssues() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const Studentissues()));
  }

  void _navigateToODRequests() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => ODRequestPage()));
  }

  void _navigateToLeaveStatus() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const LeaveRequestPage()));
  }

  void _navigateToRequestStatus() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RequestStatusPage(studentEmail: widget.email),
      ),
    );
  }

  void _navigateToHODODRequests() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ODRequestsAdminPage()));
  }

  void _navigateToStaffOdRequests() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ODRequestsstaffPage()));
  }

  void _navigateToHODLeaveRequests() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const LeaveRequestsAdminPage()));
  }

  void _navigateToStaffLeaveRequests() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const LeaveRequestsStaffPage()));
  }

  void _navigateToHODStudentIssues() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const Studentissuehodview()));
  }

  void _navigateToChangePassword() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) =>
                ChangePasswordPage(email: widget.email, role: widget.role),
      ),
    );
    print(widget.email);
    print(widget.role);
  }

  // void _navigateToHelp() {
  //   Navigator.of(
  //     context,
  //   ).push(MaterialPageRoute(builder: (_) => const HelpPage()));
  // }

  Future<void> _handleLogout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      if (mounted) {
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/login', (route) => false);
      }
    } catch (e) {
      _showSnackBar('Error during logout', isError: true);
    }
  }

  void _showAboutDialog() {
    showAboutDialog(
      context: context,
      applicationName: 'Attendanzy',
      applicationVersion: '1.0.0',
      applicationIcon: const Icon(Icons.school),
      children: const [
        Text(
          'A comprehensive attendance management system for educational institutions.',
        ),
      ],
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red : Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _showFeedbackDialog() {
    bool isSubmitting = false;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (_) => StatefulBuilder(
            builder:
                (context, setState) => AlertDialog(
                  title: const Text(
                    "Send Feedback",
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        maxLines: 3,
                        enabled: !isSubmitting,
                        decoration: const InputDecoration(
                          hintText: "Write your feedback here",
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (val) => _feedbackText = val,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          5,
                          (index) => IconButton(
                            icon: Icon(
                              index < _rating ? Icons.star : Icons.star_border,
                              color: Colors.amber,
                            ),
                            onPressed:
                                isSubmitting
                                    ? null
                                    : () => setState(() => _rating = index + 1),
                          ),
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed:
                          isSubmitting
                              ? null
                              : () => Navigator.of(context).pop(),
                      child: Text(
                        "Cancel",
                        style: TextStyle(
                          color: isSubmitting ? Colors.grey : Colors.black54,
                        ),
                      ),
                    ),
                    ElevatedButton(
                      onPressed:
                          isSubmitting
                              ? null
                              : () async {
                                setState(() => isSubmitting = true);
                                await _submitFeedback(context);
                                setState(() => isSubmitting = false);
                              },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3B82F6),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(100, 36),
                      ),
                      child:
                          isSubmitting
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
                              : const Text("Submit"),
                    ),
                  ],
                ),
          ),
    );
  }

  Future<void> _submitFeedback(BuildContext dialogContext) async {
    if (_feedbackText.trim().isEmpty || _rating == 0) {
      _showSnackBar("Please provide feedback and rating", isError: true);
      return;
    }

    try {
      final success = await FeedbackService.submitFeedback(
        widget.email,
        _feedbackText,
        _rating,
      );

      if (!mounted) return;

      Navigator.of(dialogContext).pop();
      _showSnackBar(
        success ? "Thank you for your feedback" : "Failed to submit feedback",
        isError: !success,
      );

      if (success) {
        _feedbackText = "";
        _rating = 0;
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(dialogContext).pop();
      _showSnackBar("Error submitting feedback", isError: true);
    }
  }

  // Professional UI Helper Methods
  PopupMenuItem<String> _buildPopupMenuItem(
    String value,
    IconData icon,
    String text, {
    bool isDestructive = false,
  }) {
    return PopupMenuItem(
      value: value,
      height: 48,
      child: Row(
        children: [
          Icon(
            icon,
            color:
                isDestructive
                    ? const Color(0xFFEF4444)
                    : const Color(0xFF64748B),
            size: 20,
          ),
          const SizedBox(width: 12),
          Text(
            text,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color:
                  isDestructive
                      ? const Color(0xFFEF4444)
                      : const Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getRoleIcon() {
    if (isUser) return Icons.school_outlined;
    if (isStaff) return Icons.person_outline;
    return Icons.admin_panel_settings_outlined;
  }

  IconData _getTimeIcon() {
    final now = DateTime.now();
    final hour = now.hour;

    if (hour < 12) {
      return Icons.wb_sunny; // Morning
    } else if (hour < 17) {
      return Icons.wb_sunny_outlined; // Afternoon
    } else {
      return Icons.nights_stay; // Evening
    }
  }

  String _getTimeLabel() {
    final now = DateTime.now();
    final hour = now.hour;

    if (hour < 12) {
      return 'Morning';
    } else if (hour < 17) {
      return 'Afternoon';
    } else {
      return 'Evening';
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    String greeting;
    if (hour < 12) {
      greeting = "Good morning";
    } else if (hour < 17) {
      greeting = "Good afternoon";
    } else {
      greeting = "Good evening";
    }
    return "$greeting! Ready to get started?";
  }

  Widget _buildModernCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required LinearGradient gradient,
    required VoidCallback onTap,
  }) {
    return Container(
      height: 140,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: gradient.colors.first.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 24, color: Colors.white),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    height: 1.1,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withOpacity(0.85),
                    fontWeight: FontWeight.w400,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
