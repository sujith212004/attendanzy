import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter_attendence_app/widgets/success_animation.dart';
import 'services/api_service.dart';
import 'config/local_config.dart';

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
  String? selectedYear;
  String? selectedSection;

  File? _proofImage;
  bool _isSubmitting = false;

  Future<Map<String, String>> _getStudentSessionDetails() async {
    final prefs = await SharedPreferences.getInstance();

    final email = prefs.getString('email') ?? '';
    final department = prefs.getString('department') ?? '';
    final year = prefs.getString('year') ?? '';
    final section = prefs.getString('sec') ?? '';

    // Return a map containing both values
    return {
      'email': email,
      'department': department,
      'year': year,
      'section': section,
    };
  }

  String? requestStatus; // "pending", "accepted", "rejected"
  bool expanded = false;
  Map<String, dynamic>? savedRequestData;

  // MongoDB config
  final String mongoUri = LocalConfig.mongoUri;
  final String collectionName = "od_requests";

  // Use this as your user identifier (replace with actual user id/email in production)
  String get userIdentifier => fromAddressController.text.trim();

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadRequestStatus();
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

      // 🔥 NEW: Use API instead of MongoDB
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
          // Save this as the latest request locally
          await _saveRequestToPrefs(latestRequest);
          return;
        }
      }
    } catch (e) {
      print("Error fetching latest OD request: $e");
    }

    // If nothing found, clear state
    setState(() {
      requestStatus = null;
      savedRequestData = null;
      fromAddressController.clear();
      toAddressController.clear();
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

      // 🔥 NEW: Use API instead of MongoDB
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

      // Clear form for next request
      fromAddressController.clear();
      toAddressController.clear();
      subjectController.clear();
      contentController.clear();

      setState(() {
        expanded = false;
        _isSubmitting = false;
        _proofImage = null;
        // Don't clear savedRequestData and requestStatus - we'll reload them
      });

      // Reload the request status to show the newly submitted request
      await _loadRequestStatus();

      HapticFeedback.heavyImpact();
      _showRequestSubmittedDialog(requestData);
      _showSnackBar(
        'Request submitted successfully! You can submit another request.',
        isSuccess: true,
      );
    } catch (e) {
      setState(() {
        _isSubmitting = false;
      });
      _submitController.reverse();
      _showSnackBar('Failed to submit request: $e', isError: true);
    }
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
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isError
                    ? Icons.error_outline
                    : isSuccess
                    ? Icons.check_circle_outline
                    : Icons.info_outline,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
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
    // If accepted, show the accepted card and not the form or letter view
    if (requestStatus == "accepted") {
      setState(() {
        expanded = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your OD request has been accepted!')),
      );
    } else if (requestStatus == "rejected") {
      setState(() {
        expanded = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your OD request has been rejected.')),
      );
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
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 8),
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

  @override
  Widget build(BuildContext context) {
    // Always allow students to submit new OD requests
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildProfessionalAppBar(),
      body: _buildNewRequestForm(),
    );
  }

  PreferredSizeWidget _buildProfessionalAppBar() {
    return AppBar(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.event_available_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'OD Request',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 20,
              color: Color(0xFF1A202C),
            ),
          ),
        ],
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
        if (savedRequestData != null)
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF667EEA).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.refresh_rounded,
                  color: Color(0xFF667EEA),
                  size: 20,
                ),
              ),
              tooltip: "Refresh Status",
              onPressed: _refreshStatus,
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
    );
  }

  Widget _buildLetterCard(
    ThemeData theme, {
    bool forceAccepted = false,
    bool disableTap = false,
  }) {
    final data =
        savedRequestData ??
        {
          "from": fromAddressController.text,
          "to": toAddressController.text,
          "subject": subjectController.text,
          "content": contentController.text,
          "image": "",
          "createdAt": DateTime.now().toIso8601String(),
          "status": requestStatus ?? "pending",
        };

    final isAccepted = forceAccepted || data["status"] == "accepted";

    return GestureDetector(
      onTap:
          disableTap
              ? null
              : () {
                if (isAccepted) {
                  setState(() => expanded = true);
                }
              },
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 440),
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.blue.shade100, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.shade100.withOpacity(0.18),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "OD Request",
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.blue[900],
                fontSize: 22,
                letterSpacing: 0.7,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "To: ${data["to"] ?? ""}",
              style: theme.textTheme.bodyLarge?.copyWith(
                color: Colors.blueGrey[900],
                fontSize: 16.5,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "From: ${data["from"] ?? ""}",
              style: theme.textTheme.bodyLarge?.copyWith(
                color: Colors.blueGrey[900],
                fontSize: 16.5,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "Subject: ${data["subject"] ?? ""}",
              style: theme.textTheme.bodyLarge?.copyWith(
                color: Colors.blueGrey[900],
                fontSize: 16.5,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              data["content"] ?? "",
              style: theme.textTheme.bodyLarge?.copyWith(
                color: Colors.blueGrey[900],
                fontSize: 15.5,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Icon(
                  data["status"] == "pending"
                      ? Icons.hourglass_top
                      : data["status"] == "accepted"
                      ? Icons.check_circle
                      : Icons.cancel,
                  color:
                      data["status"] == "pending"
                          ? Colors.orange[700]
                          : data["status"] == "accepted"
                          ? Colors.green[700]
                          : Colors.red[700],
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  "Status: ${data["status"] ?? "pending"}",
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.blueGrey[900],
                    fontWeight: FontWeight.bold,
                    fontSize: 15.5,
                  ),
                ),
                if (isAccepted) ...[
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.download, size: 18),
                    label: const Text("Download"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      textStyle: const TextStyle(fontSize: 14),
                    ),
                    onPressed: () => _downloadPdf(data),
                  ),
                ],
              ],
            ),
            if (isAccepted)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text(
                  "Your OD request has been accepted. Download your letter below.",
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.blue[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfessionalLetter(ThemeData theme, Map<String, dynamic> data) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.shade50.withOpacity(0.18),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.blue.shade100, width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title at top left, close at top right
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  "OD Request",
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[900],
                    fontSize: 22,
                    letterSpacing: 0.7,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(
                    Icons.close,
                    color: Colors.blue.shade700,
                    size: 28,
                  ),
                  tooltip: "Back",
                  onPressed: () => setState(() => expanded = false),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              "Date: ${DateTime.now().toLocal().toString().split(' ')[0]}",
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 18),
            Text(
              "To,\n${data["to"] ?? ""}",
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.blueGrey[900],
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              "From,\n${data["from"] ?? ""}",
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.blueGrey[900],
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              "Subject: ${data["subject"] ?? ""}",
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.blue[900],
                fontSize: 16.5,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              "Respected Sir/Madam,",
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                fontSize: 15.5,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              data["content"] ?? "",
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 15.5,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              "Thank you.",
              style: theme.textTheme.bodyMedium?.copyWith(fontSize: 15.5),
            ),
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                "Signature: _______________",
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: Colors.grey[700],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Divider(color: Colors.grey.shade300, thickness: 1.1),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  data["status"] == "pending"
                      ? Icons.hourglass_top
                      : data["status"] == "accepted"
                      ? Icons.check_circle
                      : Icons.cancel,
                  color:
                      data["status"] == "pending"
                          ? Colors.orange[700]
                          : data["status"] == "accepted"
                          ? Colors.green[700]
                          : Colors.red[700],
                  size: 22,
                ),
                const SizedBox(width: 8),
                Text(
                  data["status"] == "accepted"
                      ? "Status: Accepted"
                      : data["status"] == "rejected"
                      ? "Status: Rejected"
                      : "Status: Waiting for verification",
                  style: theme.textTheme.titleMedium?.copyWith(
                    color:
                        data["status"] == "accepted"
                            ? Colors.green[800]
                            : data["status"] == "rejected"
                            ? Colors.red[800]
                            : Colors.orange[800],
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (data["status"] == "accepted") ...[
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.download, size: 18),
                    label: const Text("Download"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      textStyle: const TextStyle(fontSize: 14),
                    ),
                    onPressed: () => _downloadPdf(data),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _modernTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.white.withOpacity(0.8),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
        border: Border.all(
          color: Colors.blue.shade100.withOpacity(0.5),
          width: 1.5,
        ),
      ),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.blue.shade700),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.blue.shade100, width: 1.2),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.blue.shade700, width: 2),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
        maxLines: maxLines,
        validator: validator,
        style: const TextStyle(fontSize: 16),
      ),
    );
  }

  Widget _buildAcceptedRequestScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildProfessionalAppBar(),
      body: Center(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: Offset(0, _slideAnimation.value),
                end: Offset.zero,
              ).animate(_animationController),
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: _buildAcceptedCard(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExistingRequestView() {
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: Offset(0, _slideAnimation.value),
              end: Offset.zero,
            ).animate(_animationController),
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 500),
                child:
                    expanded
                        ? _buildProfessionalLetter(
                          Theme.of(context),
                          savedRequestData!,
                        )
                        : _buildRequestStatusCard(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNewRequestForm() {
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: Offset(0, _slideAnimation.value),
              end: Offset.zero,
            ).animate(_animationController),
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 500),
                child: _buildModernRequestForm(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAcceptedCard() {
    final data = savedRequestData!;
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF10B981), Color(0xFF059669)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withOpacity(0.4),
            blurRadius: 25,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              color: Colors.white,
              size: 48,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Request Accepted!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Your OD request has been approved',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.9),
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _downloadPdf(data),
                borderRadius: BorderRadius.circular(16),
                child: const Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.download_rounded,
                        color: Color(0xFF10B981),
                        size: 24,
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Download OD Letter',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestStatusCard() {
    final data = savedRequestData!;
    final status = data['status'] ?? 'pending';
    final isRejected = status == 'rejected';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color:
              isRejected
                  ? const Color(0xFFEF4444).withOpacity(0.3)
                  : const Color(0xFF667EEA).withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color:
                      isRejected
                          ? const Color(0xFFEF4444).withOpacity(0.1)
                          : const Color(0xFFF59E0B).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isRejected
                      ? Icons.cancel_rounded
                      : Icons.hourglass_top_rounded,
                  color:
                      isRejected
                          ? const Color(0xFFEF4444)
                          : const Color(0xFFF59E0B),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isRejected ? 'Request Rejected' : 'Request Pending',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color:
                            isRejected
                                ? const Color(0xFFEF4444)
                                : const Color(0xFFF59E0B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isRejected
                          ? 'Your request was not approved'
                          : 'Waiting for approval from HOD',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildDetailRow('Subject', data['subject'] ?? ''),
          const SizedBox(height: 12),
          _buildDetailRow('To', data['to'] ?? ''),
          const SizedBox(height: 12),
          _buildDetailRow('From', data['from'] ?? ''),
          const SizedBox(height: 20),
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
    );
  }

  Widget _buildModernRequestForm() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Color(0xFFF8FAFC)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF667EEA).withOpacity(0.1),
            blurRadius: 25,
            offset: const Offset(0, 12),
          ),
        ],
        border: Border.all(
          color: const Color(0xFF667EEA).withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF667EEA).withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.event_available_rounded,
                  color: Colors.white,
                  size: 48,
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Center(
              child: Text(
                'Request On Duty',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A202C),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Fill the details below to request OD from your HOD',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 32),

            // Form Fields
            FutureBuilder<Map<String, String>>(
              future: _getStudentSessionDetails(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final details = snapshot.data!;
                final prefs = SharedPreferences.getInstance();
                return FutureBuilder<SharedPreferences>(
                  future: prefs,
                  builder: (context, prefsSnap) {
                    if (!prefsSnap.hasData) return const SizedBox();
                    final name = prefsSnap.data!.getString('name') ?? '';
                    final dept = details['department'] ?? '';
                    final year = details['year'] ?? '';
                    final sec = details['section'] ?? '';
                    final fromText = '$name\n$dept\n$year-$sec';
                    final toText = 'HOD\n$dept';
                    fromAddressController.text = fromText;
                    toAddressController.text = toText;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'From: $fromText',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'To: $toText',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 16),
                      ],
                    );
                  },
                );
              },
            ),
            _buildModernTextField(
              controller: subjectController,
              label: 'Subject',
              icon: Icons.subject_rounded,
              validator: (v) => v!.isEmpty ? 'Enter subject' : null,
            ),
            const SizedBox(height: 16),
            _buildModernTextField(
              controller: contentController,
              label: 'Reason for OD',
              icon: Icons.edit_note_rounded,
              maxLines: 4,
              validator: (v) => v!.isEmpty ? 'Enter your reason' : null,
            ),
            const SizedBox(height: 24),

            // File Upload Section
            const Text(
              'Upload Supporting Document (Required)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151),
              ),
            ),
            const SizedBox(height: 12),
            _buildFileUploadSection(),
            const SizedBox(height: 32),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF667EEA).withOpacity(0.4),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _isSubmitting ? null : _submitRequest,
                    borderRadius: BorderRadius.circular(16),
                    child: Center(
                      child:
                          _isSubmitting
                              ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                              : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.send_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  SizedBox(width: 12),
                                  Text(
                                    'Submit Request',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              controller.text.isNotEmpty
                  ? const Color(0xFF667EEA).withOpacity(0.3)
                  : Colors.grey.shade300,
          width: 1.5,
        ),
      ),
      child: TextFormField(
        controller: controller,
        onChanged: (value) => setState(() {}),
        decoration: InputDecoration(
          prefixIcon: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF667EEA).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: const Color(0xFF667EEA), size: 20),
          ),
          labelText: label,
          hintText: "Enter $label",
          labelStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF4A5568),
          ),
          hintStyle: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 20,
          ),
        ),
        maxLines: maxLines,
        validator: validator,
      ),
    );
  }

  Widget _buildFileUploadSection() {
    return _proofImage == null
        ? Container(
          width: double.infinity,
          height: 120,
          decoration: BoxDecoration(
            color: const Color(0xFF667EEA).withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF667EEA).withOpacity(0.3),
              width: 2,
              style: BorderStyle.solid,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _pickImage,
              borderRadius: BorderRadius.circular(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF667EEA).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.cloud_upload_rounded,
                      color: Color(0xFF667EEA),
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Tap to upload document',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF667EEA),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Supports JPG, PNG formats',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ),
        )
        : Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF10B981).withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(_proofImage!, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Document uploaded',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF10B981),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Image selected successfully',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    _proofImage = null;
                  });
                  HapticFeedback.lightImpact();
                },
                icon: const Icon(
                  Icons.delete_rounded,
                  color: Color(0xFFEF4444),
                ),
              ),
            ],
          ),
        );
  }
}
