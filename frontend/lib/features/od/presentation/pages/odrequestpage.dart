import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../../core/widgets/success_animation.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/config/local_config.dart';

class ODRequestPage extends StatefulWidget {
  const ODRequestPage({super.key});

  @override
  State<ODRequestPage> createState() => _ODRequestPageState();
}

class _ODRequestPageState extends State<ODRequestPage>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController fromAddressController = TextEditingController();
  final TextEditingController toAddressController = TextEditingController();
  final TextEditingController subjectController = TextEditingController();
  final TextEditingController contentController = TextEditingController();

  late AnimationController _animationController;
  late AnimationController _submitController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _scaleAnimation;

  File? _proofImage;
  bool _isSubmitting = false;

  String? requestStatus; // "pending", "accepted", "rejected"
  bool expanded = false;
  Map<String, dynamic>? savedRequestData;

  // Student details for UI
  String? _studentName;
  String? _studentDept;
  String? _studentYear;
  String? _studentSec;

  // MongoDB config
  final String mongoUri = LocalConfig.mongoUri;
  final String collectionName = "od_requests";

  // Use this as your user identifier
  String get userIdentifier => fromAddressController.text.trim();

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _fetchStudentDetails();
    _loadRequestStatus();
  }

  Future<void> _fetchStudentDetails() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _studentName = prefs.getString('name') ?? '';
      _studentDept = prefs.getString('department') ?? '';
      _studentYear = prefs.getString('year') ?? '';
      _studentSec = prefs.getString('sec') ?? '';

      // Populate controllers if not already set (e.g. by loaded request)
      if (fromAddressController.text.isEmpty) {
        fromAddressController.text =
            '$_studentName\n$_studentDept\n$_studentYear-$_studentSec';
      }
      if (toAddressController.text.isEmpty) {
        toAddressController.text = 'Head of Department, $_studentDept';
      }
    });
  }

  Future<Map<String, String>> _getStudentSessionDetails() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'email': prefs.getString('email') ?? '',
      'department': prefs.getString('department') ?? '',
      'year': prefs.getString('year') ?? '',
      'section': prefs.getString('sec') ?? '',
    };
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
    fromAddressController.dispose();
    toAddressController.dispose();
    subjectController.dispose();
    contentController.dispose();
    super.dispose();
  }

  Future<void> _loadRequestStatus() async {
    try {
      final sessionDetails = await _getStudentSessionDetails();
      final studentEmail = sessionDetails['email'];

      if (studentEmail == null || studentEmail.isEmpty) {
        return;
      }

      final result = await ApiService.getStudentODRequests(studentEmail);

      if (result['success'] && result['data'] != null) {
        final requests = result['data'] as List;

        if (requests.isNotEmpty) {
          final latestRequest = requests.first;
          setState(() {
            requestStatus = latestRequest['status'] ?? "pending";
            savedRequestData = latestRequest;
            fromAddressController.text = latestRequest['from'] ?? '';
            toAddressController.text = latestRequest['to'] ?? '';
            subjectController.text = latestRequest['subject'] ?? '';
            contentController.text = latestRequest['content'] ?? '';
          });
          await _saveRequestToPrefs(latestRequest);
          return;
        }
      }
    } catch (e) {
      print("Error fetching latest OD request: $e");
    }

    setState(() {
      requestStatus = null;
      savedRequestData = null;
      // Re-populate with default details if clearning
      _fetchStudentDetails();
      subjectController.clear();
      contentController.clear();
    });
  }

  Future<void> _saveRequestToPrefs(Map<String, dynamic> requestData) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('od_request', jsonEncode(requestData));
  }

  Future<void> _pickImage() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (picked != null) {
        setState(() {
          _proofImage = File(picked.path);
        });
        HapticFeedback.lightImpact();
        _showSnackBar('Image selected successfully', isSuccess: true);
      }
    } catch (e) {
      _showSnackBar('Failed to pick image: $e', isError: true);
    }
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) {
      _showSnackBar('Please fill all required fields', isError: true);
      return;
    }
    if (_proofImage == null) {
      _showSnackBar('Proof document is required', isError: true);
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    _submitController.forward();
    HapticFeedback.mediumImpact();

    try {
      final sessionDetails = await _getStudentSessionDetails();
      final studentEmail = sessionDetails['email'];
      final studentDepartment = sessionDetails['department'];
      final studentYear = sessionDetails['year'];
      final studentSection = sessionDetails['section'];

      String? imageBase64;
      if (_proofImage != null) {
        final bytes = await _proofImage!.readAsBytes();
        imageBase64 = base64Encode(bytes);
      }

      final prefs = await SharedPreferences.getInstance();
      final studentName = prefs.getString('name') ?? '';

      final result = await ApiService.submitODRequest(
        studentName: studentName,
        studentEmail: studentEmail!,
        from: fromAddressController.text.trim(),
        to: toAddressController.text.trim(),
        subject: subjectController.text.trim(),
        content: contentController.text.trim(),
        department: studentDepartment!,
        year: studentYear!,
        section: studentSection!,
        image: imageBase64,
      );

      if (!result['success']) {
        throw Exception(result['message'] ?? 'Failed to submit request');
      }

      final requestData = result['data'];

      // Clear form
      subjectController.clear();
      contentController.clear();
      setState(() {
        expanded = false;
        _isSubmitting = false;
        _proofImage = null;
      });

      await _loadRequestStatus();

      HapticFeedback.heavyImpact();
      _showRequestSubmittedDialog(requestData);
      _showSnackBar('Request submitted successfully!', isSuccess: true);
    } catch (e) {
      setState(() {
        _isSubmitting = false;
      });
      _submitController.reverse();
      _showSnackBar('Failed to submit request: $e', isError: true);
    }
  }

  Future<void> _downloadPdf(Map<String, dynamic> data) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(24),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'On Duty Request',
                  style: pw.TextStyle(
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 16),
                pw.Text(
                  'Date: ${DateTime.now().toLocal().toString().split(' ')[0]}',
                ),
                pw.SizedBox(height: 16),
                pw.Text('To,\n${data["to"] ?? ""}'),
                pw.SizedBox(height: 16),
                pw.Text('From,\n${data["from"] ?? ""}'),
                pw.SizedBox(height: 16),
                pw.Text(
                  'Subject: ${data["subject"] ?? ""}',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 16),
                pw.Text('Respected Sir/Madam,'),
                pw.SizedBox(height: 8),
                pw.Text(data["content"] ?? ""),
                pw.SizedBox(height: 16),
                pw.Text('Thank you.'),
                pw.SizedBox(height: 32),
                pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text('Signature: _______________'),
                ),
              ],
            ),
          );
        },
      ),
    );
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  Future<void> _refreshStatus() async {
    await _loadRequestStatus();
    if (requestStatus == "accepted") {
      setState(() {
        expanded = false;
      });
      _showSnackBar('Your OD request has been accepted!', isSuccess: true);
    } else if (requestStatus == "rejected") {
      setState(() {
        expanded = false;
      });
      _showSnackBar('Your OD request has been rejected.', isError: true);
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
                      onCompleted: () {
                        Future.delayed(const Duration(milliseconds: 300), () {
                          if (Navigator.of(context).canPop()) {
                            Navigator.of(context).pop();
                          }
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

  void _showSnackBar(
    String message, {
    bool isError = false,
    bool isSuccess = false,
  }) {
    if (!mounted) return;

    final color =
        isError
            ? const Color(0xFFEF4444)
            : isSuccess
            ? const Color(0xFF10B981)
            : const Color(0xFF667EEA);

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError
                  ? Icons.error_outline
                  : isSuccess
                  ? Icons.check_circle_outline
                  : Icons.info_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: Duration(seconds: isError ? 4 : 3),
      ),
    );
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

  String _formatTimestamp(String? timestamp, {String? fallback}) {
    String? value =
        (timestamp != null && timestamp.isNotEmpty && timestamp != 'null')
            ? timestamp
            : null;

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
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 20,
                                  offset: Offset(0, -5),
                                ),
                              ],
                            ),
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(24),
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (savedRequestData != null)
                                      expanded
                                          ? _buildProfessionalLetter()
                                          : _buildRequestStatusCard(),
                                    if (savedRequestData == null) ...[
                                      _buildFormTitle(),
                                      const SizedBox(height: 24),
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

  Widget _buildProfessionalLetter() {
    final data = savedRequestData!;
    final isAccepted = data['status'] == 'accepted';

    return Container(
      width: double.infinity,
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
        border: Border.all(color: Colors.blue.shade100.withOpacity(0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  "OD Request Letter",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[900],
                    fontSize: 20,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.close, color: Colors.grey[600]),
                  onPressed: () => setState(() => expanded = false),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 16),
            Text(
              "Date: ${DateTime.now().toLocal().toString().split(' ')[0]}",
              style: TextStyle(color: Colors.grey[700]),
            ),
            const SizedBox(height: 16),
            Text(
              "To,\n${data["to"] ?? ""}",
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF2C3E50),
                fontSize: 15,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "From,\n${data["from"] ?? ""}",
              style: const TextStyle(
                color: Color(0xFF2C3E50),
                fontSize: 15,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "Subject: ${data["subject"] ?? ""}",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.blue[900],
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "Respected Sir/Madam,",
              style: const TextStyle(color: Color(0xFF2C3E50), fontSize: 15),
            ),
            const SizedBox(height: 8),
            Text(
              data["content"] ?? "",
              style: const TextStyle(
                color: Color(0xFF2C3E50),
                fontSize: 15,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            const Align(
              alignment: Alignment.centerRight,
              child: Text("Signature: _______________"),
            ),
            if (isAccepted) ...[
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () => _downloadPdf(data),
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('Download Letter'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF667EEA),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ],
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
                  'OD Request',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Submit your on-duty application',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (savedRequestData != null)
            GestureDetector(
              onTap: _refreshStatus,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                ),
                child: const Icon(
                  Icons.refresh_rounded,
                  color: Colors.white,
                  size: 20,
                ),
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
                  'OD Application Form',
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
                  fromAddressController.text.isNotEmpty
                      ? fromAddressController.text
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
                  toAddressController.text.isNotEmpty
                      ? toAddressController.text
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
      label: 'Reason for OD',
      controller: contentController,
      icon: Icons.edit_note_outlined,
      maxLines: 4,
      validator: (v) => v!.isEmpty ? 'Enter your reason for OD' : null,
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
                          : 'Attach OD Proof',
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
                          : 'Required - Add supporting document',
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
          height: 60,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: [const Color(0xFF667EEA), const Color(0xFF764BA2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF667EEA).withOpacity(0.4),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: _isSubmitting ? null : _submitRequest,
              child: Container(
                alignment: Alignment.center,
                child:
                    _isSubmitting
                        ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            const Text(
                              'Sending Request...',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
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
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Submit OD Request',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
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

  Widget _buildStyledTextField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF667EEA).withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Color(0xFF2C3E50),
        ),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Container(
            padding: const EdgeInsets.all(12),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF667EEA).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: const Color(0xFF667EEA), size: 20),
            ),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          labelStyle: const TextStyle(
            color: Color(0xFF94A3B8),
            fontWeight: FontWeight.w600,
          ),
          floatingLabelStyle: const TextStyle(
            color: Color(0xFF667EEA),
            fontWeight: FontWeight.bold,
          ),
        ),
        validator: validator,
      ),
    );
  }

  Widget _buildRequestStatusCard() {
    final data = savedRequestData!;
    final status = data['status'] ?? 'pending';
    final statusColor = _getStatusColor(status);
    final timestamp = data['timestamp'] ?? data['createdAt'];
    final formattedDate = _formatTimestamp(
      timestamp?.toString(),
      fallback: data['createdAt']?.toString(),
    );

    return Container(
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
                  child: Icon(
                    status == 'pending'
                        ? Icons.hourglass_top_rounded
                        : status == 'accepted'
                        ? Icons.check_circle_rounded
                        : Icons.cancel_rounded,
                    color: statusColor,
                    size: 32,
                  ),
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
                            ? 'Your request is being reviewed'
                            : status == 'accepted'
                            ? 'Request approved'
                            : 'Request rejected',
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

          // Details
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              children: [
                _buildDetailRow('Subject', data['subject'] ?? ''),
                const SizedBox(height: 16),
                _buildDetailRow('Submitted', formattedDate),
                const SizedBox(height: 16),
                _buildDetailRow('From', data['from'] ?? ''),
                if (status == 'rejected' &&
                    data['rejectionReason'] != null) ...[
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFCA5A5)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Rejection Reason',
                          style: TextStyle(
                            color: Color(0xFFB91C1C),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          data['rejectionReason'],
                          style: const TextStyle(
                            color: Color(0xFF7F1D1D),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: () => setState(() => expanded = true),
                    icon: const Icon(Icons.visibility_rounded),
                    label: const Text('View Full Request'),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: const Color(0xFF667EEA).withOpacity(0.5),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
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
          child: Text(
            value,
            style: TextStyle(
              fontSize: 15,
              color: isStatus ? Colors.orange[700] : const Color(0xFF2C3E50),
              fontWeight: isStatus ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }
}
