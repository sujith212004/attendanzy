import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/widgets/success_animation.dart';
import '../../../../core/services/api_service.dart';

class LeaveRequestPage extends StatefulWidget {
  const LeaveRequestPage({super.key});

  @override
  State<LeaveRequestPage> createState() => _LeaveRequestPageState();
}

class _LeaveRequestPageState extends State<LeaveRequestPage>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController subjectController = TextEditingController();
  final TextEditingController contentController = TextEditingController();
  final TextEditingController fromDateController = TextEditingController();
  final TextEditingController toDateController = TextEditingController();
  final TextEditingController leaveTypeController = TextEditingController();

  late AnimationController _animationController;
  late AnimationController _submitController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _scaleAnimation;

  File? _proofImage;
  bool _isSubmitting = false;
  DateTime? _fromDate;
  DateTime? _toDate;
  String _selectedLeaveType = 'Sick Leave';

  // Auto-filled addresses
  String? _fromAddress;
  String? _toAddress;

  // Leave type options
  final List<String> _leaveTypes = [
    'Sick Leave',
    'Emergency Leave',
    'Personal Leave',
    'Medical Leave',
    'Family Leave',
    'Other',
  ];

  /// Fetches the logged-in student's email and department from SharedPreferences.
  Future<Map<String, String>> _getStudentSessionDetails() async {
    final prefs = await SharedPreferences.getInstance();

    final email = prefs.getString('email') ?? '';
    final department = prefs.getString('department') ?? '';
    final name = prefs.getString('name') ?? '';
    final year = prefs.getString('year') ?? '';
    final section = prefs.getString('sec') ?? '';

    return {
      'email': email,
      'department': department,
      'name': name,
      'year': year,
      'section': section,
    };
  }

  String? requestStatus; // "pending", "accepted", "rejected"
  bool expanded = false;
  Map<String, dynamic>? savedRequestData;

  // Removed userIdentifier as address is now auto-filled

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadRequestStatus(); // Load request status on page open
    leaveTypeController.text = _selectedLeaveType;
    _fetchAddresses();
  }

  Future<void> _fetchAddresses() async {
    final sessionDetails = await _getStudentSessionDetails();
    final name = sessionDetails['name'] ?? '';
    final department = sessionDetails['department'] ?? '';
    final year = sessionDetails['year'] ?? '';
    final section = sessionDetails['section'] ?? '';
    // Student address: Name (Dept, Year-Section)
    _fromAddress = '$name ($department, $year-$section)';
    // HOD address: Head of Department, Dept
    _toAddress = 'Head of Department, $department';
    setState(() {});
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _submitController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _slideAnimation = Tween<double>(begin: 50.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 0.8, curve: Curves.easeOutCubic),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.4, 1.0, curve: Curves.elasticOut),
      ),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _submitController.dispose();
    subjectController.dispose();
    contentController.dispose();
    fromDateController.dispose();
    toDateController.dispose();
    leaveTypeController.dispose();
    super.dispose();
  }

  Future<void> _loadRequestStatus() async {
    try {
      final sessionDetails = await _getStudentSessionDetails();
      final studentEmail = sessionDetails['email'];

      if (studentEmail == null || studentEmail.isEmpty) {
        return;
      }

      // 🔥 Use API to get student's leave requests
      final result = await ApiService.getStudentLeaveRequests(studentEmail);

      if (result['success'] && result['data'] != null) {
        final requests = result['data'] as List;

        if (requests.isNotEmpty) {
          final latestRequest = requests.first;
          setState(() {
            requestStatus = latestRequest['status'] ?? "pending";
            savedRequestData = latestRequest;
          });
          // Save this as the latest request locally
          await _saveRequestToPrefs(latestRequest);
          return;
        }
      }
    } catch (e) {
      print("Error fetching latest leave request: $e");
    }

    // If nothing found, clear state
    setState(() {
      requestStatus = null;
      savedRequestData = null;
    });
  }

  Future<void> _saveRequestToPrefs(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonData = jsonEncode(data);
    await prefs.setString('leave_request_data', jsonData);
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;
    if (_fromDate == null || _toDate == null) {
      _showSnackBar('Please select from and to dates', isError: true);
      return;
    }

    // Validate maximum 2 continuous days
    int duration = _toDate!.difference(_fromDate!).inDays + 1;
    if (duration > 2) {
      _showSnackBar(
        'Leave application is limited to maximum 2 continuous days',
        isError: true,
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    _submitController.forward();

    try {
      final sessionDetails = await _getStudentSessionDetails();
      final studentEmail = sessionDetails['email'];
      final studentDepartment = sessionDetails['department'];
      final studentName = sessionDetails['name'];
      final studentYear = sessionDetails['year'];
      final studentSection = sessionDetails['section'];

      String? imageBase64;
      if (_proofImage != null) {
        final bytes = await _proofImage!.readAsBytes();
        imageBase64 = base64Encode(bytes);
      }

      final requestData = {
        "studentEmail": studentEmail,
        "studentName": studentName,
        "year": studentYear,
        "section": studentSection,
        "from": _fromAddress ?? '',
        "to": _toAddress ?? '',
        "subject": subjectController.text.trim(),
        "content": contentController.text.trim(),
        "reason": contentController.text.trim(),
        "leaveType": _selectedLeaveType,
        "fromDate": _fromDate!.toIso8601String(),
        "toDate": _toDate!.toIso8601String(),
        "duration": _toDate!.difference(_fromDate!).inDays + 1,
        "image": imageBase64 ?? "",
        "createdAt": DateTime.now().toIso8601String(),
        "department": studentDepartment,
        // ignore: equal_keys_in_map
        "year": sessionDetails['year'] ?? '',
        // ignore: equal_keys_in_map
        "section": sessionDetails['section'] ?? '',
        'staffStatus': 'pending',
        'hodStatus': 'pending',
      };

      // 🔥 NEW: Use API instead of MongoDB
      final result = await ApiService.submitLeaveRequest(
        studentName: studentName!,
        studentEmail: studentEmail!,
        from: _fromAddress ?? '',
        to: _toAddress ?? '',
        subject: subjectController.text.trim(),
        content: contentController.text.trim(),
        reason: contentController.text.trim(),
        leaveType: _selectedLeaveType,
        fromDate: _fromDate!.toIso8601String(),
        toDate: _toDate!.toIso8601String(),
        duration: duration,
        department: studentDepartment!,
        year: studentYear!,
        section: studentSection!,
        image: imageBase64,
      );

      if (!result['success']) {
        throw Exception(result['message'] ?? 'Failed to submit leave request');
      }

      await _saveRequestToPrefs(requestData);

      setState(() {
        _isSubmitting = false;
      });

      // Reload the request status to show the newly submitted request
      await _loadRequestStatus();

      HapticFeedback.heavyImpact();
      // show animation-only dialog and auto-close when complete
      _showRequestSubmittedDialog(requestData);
      _showSnackBar('Leave request submitted successfully!', isError: false);

      return;
    } catch (e) {
      // Handle submission errors
      setState(() {
        _isSubmitting = false;
      });
      _showSnackBar('Failed to submit leave request: $e', isError: true);
    }
  }

  void _showRequestSubmittedDialog(Map<String, dynamic> data) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => Dialog(
            backgroundColor: Colors.transparent,
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 320),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.shade100.withOpacity(0.3),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SuccessAnimation(
                      size: 140,
                      fullScreenConfetti: true,
                      onCompleted: () {
                        Future.delayed(const Duration(milliseconds: 300), () {
                          if (Navigator.of(context).canPop())
                            Navigator.of(context).pop();
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isStatus = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child:
              isStatus
                  ? Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.orange.shade300),
                    ),
                    child: Text(
                      value,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  )
                  : Text(
                    value,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
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

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> _selectDate(bool isFromDate) async {
    DateTime now = DateTime.now();
    DateTime firstDate = now.add(
      const Duration(days: 1),
    ); // Default to tomorrow

    // If after 12:30 PM, disable tomorrow and allow from day after tomorrow
    if (now.hour > 12 || (now.hour == 12 && now.minute >= 30)) {
      firstDate = now.add(const Duration(days: 2)); // Day after tomorrow
    }

    DateTime lastDate = now.add(const Duration(days: 365));

    if (!isFromDate && _fromDate != null) {
      // For to date, limit to maximum 2 continuous days (so lastDate is fromDate + 1 day)
      lastDate = _fromDate!.add(const Duration(days: 1));
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate:
          isFromDate
              ? (_fromDate ?? firstDate)
              : (_toDate ?? (_fromDate ?? firstDate)),
      firstDate: firstDate,
      lastDate: lastDate,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF667EEA),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF2C3E50),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isFromDate) {
          _fromDate = picked;
          fromDateController.text = _formatDate(picked);
          // If to date is before from date or more than 1 day after, clear it
          if (_toDate != null &&
              (_toDate!.isBefore(picked) ||
                  _toDate!.difference(picked).inDays > 1)) {
            _toDate = null;
            toDateController.clear();
          }
        } else {
          if (_fromDate != null && picked.isBefore(_fromDate!)) {
            _showSnackBar('To date cannot be before from date', isError: true);
            return;
          }
          if (_fromDate != null && picked.difference(_fromDate!).inDays > 1) {
            _showSnackBar(
              'Leave application is limited to maximum 2 continuous days',
              isError: true,
            );
            return;
          }
          _toDate = picked;
          toDateController.text = _formatDate(picked);
        }
      });
    }
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 1024,
        maxHeight: 1024,
      );

      if (image != null) {
        setState(() {
          _proofImage = File(image.path);
        });
        _showSnackBar('Medical certificate/proof attached', isError: false);
      }
    } catch (e) {
      _showSnackBar('Failed to pick image: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF667EEA),
              Color(0xFF764BA2),
              Color(0xFFF093FB),
              Color(0xFFF5576C),
            ],
            stops: [0.0, 0.3, 0.7, 1.0],
          ),
        ),
        child: SafeArea(
          child: AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return FadeTransition(
                opacity: _fadeAnimation,
                child: Transform.translate(
                  offset: Offset(0, _slideAnimation.value),
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: Column(
                      children: [
                        _buildHeader(),
                        Expanded(
                          child: Container(
                            margin: const EdgeInsets.only(top: 20),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(30),
                                topRight: Radius.circular(30),
                              ),
                            ),
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(24),
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildFormTitle(),
                                    const SizedBox(height: 24),
                                    if (expanded && savedRequestData != null)
                                      _buildRequestStatus(),
                                    if (!expanded ||
                                        savedRequestData == null) ...[
                                      _buildLeaveTypeDropdown(),
                                      const SizedBox(height: 20),
                                      _buildDateSelectors(),
                                      const SizedBox(height: 20),
                                      _buildAddressFields(),
                                      const SizedBox(height: 20),
                                      _buildSubjectField(),
                                      const SizedBox(height: 20),
                                      _buildContentField(),
                                      const SizedBox(height: 20),
                                      _buildImagePicker(),
                                      const SizedBox(height: 30),
                                      _buildSubmitButton(),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.3)),
              ),
              child: const Icon(
                Icons.arrow_back_ios_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Leave Request',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Submit your leave application',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormTitle() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF667EEA).withOpacity(0.1),
            const Color(0xFF764BA2).withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF667EEA).withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF667EEA).withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.assignment_outlined,
              color: Color(0xFF667EEA),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Leave Application Form',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2C3E50),
                  ),
                ),
                Text(
                  'Fill in all required details accurately',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaveTypeDropdown() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: DropdownButtonFormField<String>(
        value: _selectedLeaveType,
        decoration: const InputDecoration(
          labelText: 'Leave Type',
          prefixIcon: Icon(Icons.category_outlined, color: Color(0xFF667EEA)),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          labelStyle: TextStyle(
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w600,
          ),
        ),
        items:
            _leaveTypes.map((String type) {
              return DropdownMenuItem<String>(
                value: type,
                child: Text(
                  type,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF2C3E50),
                  ),
                ),
              );
            }).toList(),
        onChanged: (String? newValue) {
          setState(() {
            _selectedLeaveType = newValue!;
            leaveTypeController.text = newValue;
          });
        },
        validator: (value) => value == null ? 'Please select leave type' : null,
      ),
    );
  }

  Widget _buildDateSelectors() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => _selectDate(true),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_outlined,
                        color: Color(0xFF667EEA),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'From Date',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _fromDate != null ? _formatDate(_fromDate) : 'Select date',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color:
                          _fromDate != null
                              ? const Color(0xFF2C3E50)
                              : Colors.grey[400],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: GestureDetector(
            onTap: () => _selectDate(false),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.event_outlined,
                        color: Color(0xFF667EEA),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'To Date',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _toDate != null ? _formatDate(_toDate) : 'Select date',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color:
                          _toDate != null
                              ? const Color(0xFF2C3E50)
                              : Colors.grey[400],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAddressFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              const Icon(Icons.location_on_outlined, color: Color(0xFF667EEA)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _fromAddress != null && _fromAddress!.isNotEmpty
                      ? _fromAddress!
                      : 'Loading your details...',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2C3E50),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              const Icon(Icons.person_outline, color: Color(0xFF667EEA)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _toAddress != null && _toAddress!.isNotEmpty
                      ? _toAddress!
                      : 'Loading recipient...',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2C3E50),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSubjectField() {
    return _buildStyledTextField(
      label: 'Subject',
      controller: subjectController,
      icon: Icons.subject_outlined,
      validator: (v) => v!.isEmpty ? 'Enter subject' : null,
    );
  }

  Widget _buildContentField() {
    return _buildStyledTextField(
      label: 'Reason for Leave',
      controller: contentController,
      icon: Icons.edit_note_outlined,
      maxLines: 4,
      validator: (v) => v!.isEmpty ? 'Enter your reason for leave' : null,
    );
  }

  Widget _buildImagePicker() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              _proofImage != null
                  ? const Color(0xFF10B981)
                  : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (_proofImage != null
                          ? const Color(0xFF10B981)
                          : const Color(0xFF667EEA))
                      .withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _proofImage != null
                      ? Icons.check_circle_outline
                      : Icons.attach_file_outlined,
                  color:
                      _proofImage != null
                          ? const Color(0xFF10B981)
                          : const Color(0xFF667EEA),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _proofImage != null
                          ? 'Document Attached'
                          : 'Attach Medical Certificate/Proof',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color:
                            _proofImage != null
                                ? const Color(0xFF10B981)
                                : const Color(0xFF2C3E50),
                      ),
                    ),
                    Text(
                      _proofImage != null
                          ? 'Tap to change document'
                          : 'Optional - Add supporting document',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _pickImage,
                icon: Icon(
                  _proofImage != null
                      ? Icons.edit
                      : Icons.add_photo_alternate_outlined,
                  color: const Color(0xFF667EEA),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return AnimatedBuilder(
      animation: _submitController,
      builder: (context, child) {
        return Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [const Color(0xFF667EEA), const Color(0xFF764BA2)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF667EEA).withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: _isSubmitting ? null : _submitRequest,
              child: Container(
                alignment: Alignment.center,
                child:
                    _isSubmitting
                        ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Submitting...',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        )
                        : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.send_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Submit Leave Request',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRequestStatus() {
    if (savedRequestData == null) return const SizedBox.shrink();

    final data = savedRequestData!;
    final status = data['status'] ?? 'pending';
    final statusColor = _getStatusColor(status);
    final statusIcon = _getStatusIcon(status);
    final createdAt =
        data['createdAt'] != null
            ? _formatDateFromString(data['createdAt'])
            : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Status Banner
          Container(
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.12),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(statusIcon, color: statusColor, size: 32),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        status == 'pending'
                            ? 'Your request is being reviewed.'
                            : status == 'accepted' || status == 'approved'
                            ? 'Your leave has been approved.'
                            : 'Your leave request was rejected.',
                        style: TextStyle(
                          color: statusColor.withOpacity(0.8),
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Details Card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.category_outlined,
                      color: Colors.blueGrey[400],
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      data['leaveType'] ?? '-',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.calendar_today_outlined,
                      color: Colors.blueGrey[400],
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${data['duration'] ?? data['numberOfDays'] ?? '-'} days',
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Icon(
                      Icons.date_range,
                      color: Colors.blueGrey[400],
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'From: ',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      _formatDateFromString(data['fromDate']),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 18),
                    Text(
                      'To: ',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      _formatDateFromString(data['toDate']),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Icon(
                      Icons.subject_outlined,
                      color: Colors.blueGrey[400],
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        data['subject'] ?? '-',
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 15,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Icon(
                      Icons.person_outline,
                      color: Colors.blueGrey[400],
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Requested on: ',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      createdAt,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Divider(color: Colors.grey[300], thickness: 1),
                const SizedBox(height: 10),
                Text(
                  'Reason:',
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey[50],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    data['content'] ?? '-',
                    style: const TextStyle(
                      fontSize: 15,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateFromString(String? dateString) {
    if (dateString == null) return '';
    try {
      final date = DateTime.parse(dateString);
      return _formatDate(date);
    } catch (e) {
      return dateString;
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

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
      case 'accepted':
        return Icons.check_circle_outline;
      case 'rejected':
        return Icons.cancel_outlined;
      case 'pending':
      default:
        return Icons.schedule_outlined;
    }
  }

  Widget _buildStyledTextField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    String? Function(String?)? validator,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Color(0xFF2C3E50),
        ),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: const Color(0xFF667EEA)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          labelStyle: const TextStyle(
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w600,
          ),
        ),
        validator: validator,
      ),
    );
  }
}
