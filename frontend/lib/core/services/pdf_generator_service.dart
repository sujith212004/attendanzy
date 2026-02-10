import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// PDF Generator Service for Attendanzy
class PdfGeneratorService {
  // Colors
  static const PdfColor primaryBlue = PdfColor.fromInt(0xFF0066CC);
  static const PdfColor darkGray = PdfColor.fromInt(0xFF333333);
  static const PdfColor mediumGray = PdfColor.fromInt(0xFF666666);
  static const PdfColor lightGray = PdfColor.fromInt(0xFFF5F7FA);
  static const PdfColor cardBg = PdfColor.fromInt(0xFFFFFFFF);
  static const PdfColor successGreen = PdfColor.fromInt(0xFF10B981);
  static const PdfColor warningAmber = PdfColor.fromInt(0xFFF59E0B);
  static const PdfColor errorRed = PdfColor.fromInt(0xFFEF4444);

  /// Load college logo from assets
  static Future<pw.MemoryImage?> _loadLogo() async {
    try {
      final logoData = await rootBundle.load('assets/image/logo.jpg');
      return pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (e) {
      print('Error loading college logo: $e');
      return null;
    }
  }

  /// Generate Leave Request PDF
  static Future<void> generateLeaveRequestPdf({
    required Map<String, dynamic> request,
    required String studentEmail,
  }) async {
    final pdf = pw.Document();
    final logoImage = await _loadLogo();
    final now = DateTime.now();
    final dateStr =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';

    // Text styles
    final headerStyle = pw.TextStyle(
      fontSize: 18,
      fontWeight: pw.FontWeight.bold,
      color: primaryBlue,
    );
    final subheaderStyle = pw.TextStyle(
      fontSize: 14,
      fontWeight: pw.FontWeight.bold,
    );
    final bodyStyle = const pw.TextStyle(fontSize: 11, lineSpacing: 1.5);
    final labelStyle = pw.TextStyle(
      fontSize: 11,
      fontWeight: pw.FontWeight.bold,
    );
    final smallStyle = pw.TextStyle(
      fontSize: 9,
      color: mediumGray,
      fontStyle: pw.FontStyle.italic,
    );

    // Parse dates
    final fromDate = _formatDate(request['fromDate']);
    final toDate = _formatDate(request['toDate']);
    final duration =
        (request['duration'] is int)
            ? request['duration']
            : int.tryParse(request['duration']?.toString() ?? '0') ?? 0;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return pw.Stack(
            children: [
              // Logo Watermark - centered and subtle
              if (logoImage != null)
                pw.Positioned.fill(
                  child: pw.Center(
                    child: pw.Opacity(
                      opacity: 0.05,
                      child: pw.Image(logoImage, width: 320, height: 320),
                    ),
                  ),
                ),
              // Main content
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Header with logo
                  _buildHeader(logoImage, headerStyle),
                  pw.SizedBox(height: 24),

                  // Title
                  pw.Center(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 10,
                      ),
                      decoration: pw.BoxDecoration(
                        color: primaryBlue,
                        borderRadius: pw.BorderRadius.circular(20),
                      ),
                      child: pw.Text(
                        'LEAVE REQUEST APPLICATION',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 20),

                  // Date aligned right
                  pw.Align(
                    alignment: pw.Alignment.centerRight,
                    child: pw.Text('Date: $dateStr', style: bodyStyle),
                  ),
                  pw.SizedBox(height: 16),

                  // TO Section
                  _buildSectionLabel('TO', labelStyle),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'The Head of Department, ${request['department'] ?? 'Department'}',
                    style: bodyStyle,
                  ),
                  pw.Text(
                    'Agni College of Technology, Chennai - 603103',
                    style: bodyStyle,
                  ),
                  pw.SizedBox(height: 12),

                  // FROM Section
                  _buildSectionLabel('FROM', labelStyle),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    '${request['studentName'] ?? 'N/A'}',
                    style: bodyStyle,
                  ),
                  pw.Text(
                    '${request['studentEmail'] ?? studentEmail}',
                    style: bodyStyle,
                  ),
                  pw.Text(
                    'Year: ${request['year'] ?? 'N/A'}, Section: ${request['section'] ?? 'N/A'}',
                    style: bodyStyle,
                  ),
                  pw.SizedBox(height: 12),

                  // Subject Section
                  _buildSectionLabel('SUBJECT', labelStyle),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Application for ${request['leaveType'] ?? 'Leave'}',
                    style: subheaderStyle,
                  ),
                  pw.SizedBox(height: 12),

                  // Details Section
                  _buildDetailRow(
                    'Leave Type',
                    request['leaveType'] ?? 'N/A',
                    labelStyle,
                    bodyStyle,
                  ),
                  _buildDetailRow('From Date', fromDate, labelStyle, bodyStyle),
                  _buildDetailRow('To Date', toDate, labelStyle, bodyStyle),
                  _buildDetailRow(
                    'Duration',
                    '$duration day(s)',
                    labelStyle,
                    bodyStyle,
                  ),
                  pw.SizedBox(height: 12),

                  // Reason Section
                  _buildSectionLabel('REASON', labelStyle),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    request['reason'] ?? 'No reason provided',
                    style: bodyStyle,
                  ),
                  pw.SizedBox(height: 16),

                  // Status Badge
                  pw.Center(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      decoration: pw.BoxDecoration(
                        color: _getStatusColor(request['status'] ?? 'Pending'),
                        borderRadius: pw.BorderRadius.circular(20),
                      ),
                      child: pw.Row(
                        mainAxisSize: pw.MainAxisSize.min,
                        children: [
                          pw.Text(
                            'STATUS: ',
                            style: pw.TextStyle(
                              fontSize: 11,
                              color: PdfColors.white,
                            ),
                          ),
                          pw.Text(
                            (request['status'] ?? 'Pending')
                                .toString()
                                .toUpperCase(),
                            style: pw.TextStyle(
                              fontSize: 12,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  pw.Spacer(),

                  // Footer
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(vertical: 12),
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(
                        top: pw.BorderSide(color: primaryBlue, width: 1),
                      ),
                    ),
                    child: pw.Center(
                      child: pw.Column(
                        children: [
                          pw.Text(
                            'This is a system-generated document from Attendanzy',
                            style: smallStyle,
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            'Agni College of Technology | Chennai - 603103',
                            style: pw.TextStyle(fontSize: 8, color: mediumGray),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name:
          'Leave_Request_${request['studentName']?.toString().replaceAll(' ', '_') ?? 'Student'}.pdf',
    );
  }

  /// Generate OD Request PDF
  static Future<void> generateODRequestPdf({
    required Map<String, dynamic> request,
    required String studentEmail,
  }) async {
    final pdf = pw.Document();
    final logoImage = await _loadLogo();
    final now = DateTime.now();

    // Get submitted date
    String dateStr =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
    if (request['timestamp'] != null) {
      try {
        final date = DateTime.parse(request['timestamp'].toString());
        dateStr =
            '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
      } catch (_) {}
    } else if (request['createdAt'] != null) {
      try {
        final date = DateTime.parse(request['createdAt'].toString());
        dateStr =
            '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
      } catch (_) {}
    }

    // Text styles
    final headerStyle = pw.TextStyle(
      fontSize: 18,
      fontWeight: pw.FontWeight.bold,
      color: primaryBlue,
    );
    final subheaderStyle = pw.TextStyle(
      fontSize: 14,
      fontWeight: pw.FontWeight.bold,
    );
    final bodyStyle = const pw.TextStyle(fontSize: 11, lineSpacing: 1.5);
    final labelStyle = pw.TextStyle(
      fontSize: 11,
      fontWeight: pw.FontWeight.bold,
    );
    final smallStyle = pw.TextStyle(
      fontSize: 9,
      color: mediumGray,
      fontStyle: pw.FontStyle.italic,
    );

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return pw.Stack(
            children: [
              // Logo Watermark - centered and subtle
              if (logoImage != null)
                pw.Positioned.fill(
                  child: pw.Center(
                    child: pw.Opacity(
                      opacity: 0.05,
                      child: pw.Image(logoImage, width: 320, height: 320),
                    ),
                  ),
                ),
              // Main content
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Header with logo
                  _buildHeader(logoImage, headerStyle),
                  pw.SizedBox(height: 24),

                  // Title
                  pw.Center(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 10,
                      ),
                      decoration: pw.BoxDecoration(
                        color: primaryBlue,
                        borderRadius: pw.BorderRadius.circular(20),
                      ),
                      child: pw.Text(
                        'ON DUTY (OD) REQUEST',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 20),

                  // Date aligned right
                  pw.Align(
                    alignment: pw.Alignment.centerRight,
                    child: pw.Text('Date: $dateStr', style: bodyStyle),
                  ),
                  pw.SizedBox(height: 16),

                  // TO Section
                  _buildSectionLabel('TO', labelStyle),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'The Head of Department, ${request['department'] ?? 'Department'}',
                    style: bodyStyle,
                  ),
                  pw.Text(
                    'Agni College of Technology, Chennai - 603103',
                    style: bodyStyle,
                  ),
                  pw.SizedBox(height: 12),

                  // FROM Section
                  _buildSectionLabel('FROM', labelStyle),
                  pw.SizedBox(height: 4),
                  pw.Text('${request['from'] ?? 'N/A'}', style: bodyStyle),
                  pw.Text(studentEmail, style: bodyStyle),
                  pw.SizedBox(height: 12),

                  // Subject Section
                  _buildSectionLabel('SUBJECT', labelStyle),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    request['subject'] ?? 'OD Request',
                    style: subheaderStyle,
                  ),
                  pw.SizedBox(height: 12),

                  // Details/Content Section
                  _buildSectionLabel('DETAILS', labelStyle),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    request['content'] ??
                        request['subject'] ??
                        'Request for On-Duty Permission',
                    style: bodyStyle,
                  ),
                  pw.SizedBox(height: 16),

                  // Status Badge
                  pw.Center(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      decoration: pw.BoxDecoration(
                        color: _getStatusColor(request['status'] ?? 'Pending'),
                        borderRadius: pw.BorderRadius.circular(20),
                      ),
                      child: pw.Row(
                        mainAxisSize: pw.MainAxisSize.min,
                        children: [
                          pw.Text(
                            'STATUS: ',
                            style: pw.TextStyle(
                              fontSize: 11,
                              color: PdfColors.white,
                            ),
                          ),
                          pw.Text(
                            (request['status'] ?? 'Pending')
                                .toString()
                                .toUpperCase(),
                            style: pw.TextStyle(
                              fontSize: 12,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  pw.Spacer(),

                  // Footer
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(vertical: 12),
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(
                        top: pw.BorderSide(color: primaryBlue, width: 1),
                      ),
                    ),
                    child: pw.Center(
                      child: pw.Column(
                        children: [
                          pw.Text(
                            'This is a system-generated document from Attendanzy',
                            style: smallStyle,
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            'Agni College of Technology | Chennai - 603103',
                            style: pw.TextStyle(fontSize: 8, color: mediumGray),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name:
          'OD_Request_${request['from']?.toString().replaceAll(' ', '_') ?? 'Student'}.pdf',
    );
  }

  /// Build header with logo - Professional Center aligned
  static pw.Widget _buildHeader(
    pw.MemoryImage? logoImage,
    pw.TextStyle headerStyle,
  ) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.only(bottom: 15),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: primaryBlue, width: 2.5),
        ),
      ),
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          if (logoImage != null)
            pw.Container(
              width: 70,
              height: 70,
              child: pw.Image(logoImage, fit: pw.BoxFit.contain),
            ),
          pw.SizedBox(height: 10),
          pw.Text(
            'AGNI COLLEGE OF TECHNOLOGY',
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
              color: primaryBlue,
              letterSpacing: 1.2,
            ),
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 4),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 3),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromInt(0xFFFFF3CD),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Text(
              'An AUTONOMOUS Institution',
              style: pw.TextStyle(
                fontSize: 10,
                color: PdfColor.fromInt(0xFF856404),
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            'Affiliated to Anna University | Chennai - 603103',
            style: pw.TextStyle(
              fontSize: 10,
              color: mediumGray,
              letterSpacing: 0.3,
            ),
            textAlign: pw.TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Build section label
  static pw.Widget _buildSectionLabel(String label, pw.TextStyle labelStyle) {
    return pw.Text(
      label,
      style: pw.TextStyle(
        fontSize: 10,
        fontWeight: pw.FontWeight.bold,
        color: primaryBlue,
      ),
    );
  }

  /// Build info card for To/From sections
  static pw.Widget _buildInfoCard(
    String title,
    String content,
    pw.TextStyle bodyStyle,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: lightGray,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: PdfColor.fromInt(0xFFE0E0E0), width: 0.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: pw.BoxDecoration(
              color: primaryBlue,
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Text(
              title,
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(content, style: bodyStyle),
        ],
      ),
    );
  }

  /// Get status color
  static PdfColor _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
      case 'accepted':
        return successGreen;
      case 'rejected':
        return errorRed;
      case 'pending':
      default:
        return warningAmber;
    }
  }

  /// Build a row-aligned detail item
  static pw.Widget _buildDetailRow(
    String label,
    String value,
    pw.TextStyle labelStyle,
    pw.TextStyle valueStyle,
  ) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(width: 100, child: pw.Text(label, style: labelStyle)),
          pw.Text(': ', style: labelStyle),
          pw.Expanded(child: pw.Text(value, style: valueStyle)),
        ],
      ),
    );
  }

  /// Format date helper
  static String _formatDate(dynamic date) {
    if (date == null) return 'N/A';
    try {
      DateTime parsedDate;
      if (date is String) {
        parsedDate = DateTime.parse(date);
      } else if (date is DateTime) {
        parsedDate = date;
      } else {
        return 'N/A';
      }
      return '${parsedDate.day.toString().padLeft(2, '0')}/${parsedDate.month.toString().padLeft(2, '0')}/${parsedDate.year}';
    } catch (e) {
      return 'N/A';
    }
  }
}
