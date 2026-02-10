import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:mongo_dart/mongo_dart.dart' as mongo;
import 'dart:async';
import 'services/pdf_generator_service.dart';
import 'config/local_config.dart';

class ODRequestDetailPage extends StatefulWidget {
  final Map<String, dynamic> requestData;

  const ODRequestDetailPage({super.key, required this.requestData});

  @override
  ODRequestDetailPageState createState() => ODRequestDetailPageState();
}

class ODRequestDetailPageState extends State<ODRequestDetailPage> {
  ODRequestDetailPageState();

  bool isExpanded = false;
  Timer? _midnightTimer;
  late final Map<String, dynamic> _requestData;

  // Removed duplicate build method to resolve the conflict.

  @override
  void initState() {
    super.initState();
    _initializeRequestData();
    _scheduleMidnightUpdate();
  }

  void _initializeRequestData() {
    String sanitizeValue(dynamic value) {
      if (value == null) return '';
      final str = value.toString().trim();
      return str.isEmpty ? '' : str;
    }

    // Create a new map with proper data validation
    _requestData = {
      'from': sanitizeValue(widget.requestData['from']),
      'to': sanitizeValue(widget.requestData['to']),
      'date': sanitizeValue(widget.requestData['date']),
      'time': sanitizeValue(widget.requestData['time']),
      'reason': sanitizeValue(widget.requestData['reason']),
      'content': sanitizeValue(widget.requestData['content']),
      'subject': sanitizeValue(widget.requestData['subject']),
      'department': sanitizeValue(widget.requestData['department']),
      'status': sanitizeValue(widget.requestData['status']).toLowerCase(),
      'timestamp': sanitizeValue(widget.requestData['timestamp']),
    };
  }

  @override
  void dispose() {
    _midnightTimer?.cancel();
    super.dispose();
  }

  void _scheduleMidnightUpdate() {
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    final timeUntilMidnight = nextMidnight.difference(now);

    _midnightTimer = Timer(timeUntilMidnight, () {
      // Check if the request is accepted/rejected and older than today
      final requestDate = DateTime.parse(
        widget.requestData['timestamp'].toString(),
      );
      final status = widget.requestData['status']?.toString().toLowerCase();

      if ((status == 'accepted' || status == 'rejected') &&
          requestDate.isBefore(DateTime(now.year, now.month, now.day))) {
        if (mounted) {
          Navigator.of(context).pop(); // Close the detail page
        }
      }

      // Schedule the next update
      _scheduleMidnightUpdate();
    });
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'accepted':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // Helper method to extract student name from 'from' address
  String _extractStudentName(String? fromAddress) {
    if (fromAddress == null || fromAddress.isEmpty) return '';
    // Assuming the name is the first line or before the first comma
    final parts = fromAddress.split('\n').first.split(',');
    return parts[0].trim();
  }

  Future<void> _downloadPdf(BuildContext context) async {
    try {
      await PdfGeneratorService.generateODRequestPdf(
        request: _requestData,
        studentEmail: _requestData['from'] ?? '',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error downloading OD request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _editRequest(BuildContext context) {
    // Navigate to edit page or show edit dialog
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final TextEditingController subjectController = TextEditingController(
          text: _requestData['subject'],
        );
        final TextEditingController contentController = TextEditingController(
          text: _requestData['content'],
        );
        final TextEditingController fromController = TextEditingController(
          text: _requestData['from'],
        );
        final TextEditingController toController = TextEditingController(
          text: _requestData['to'],
        );

        return AlertDialog(
          title: const Text('Edit OD Request'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: fromController,
                    decoration: const InputDecoration(
                      labelText: 'From',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: toController,
                    decoration: const InputDecoration(
                      labelText: 'To',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: subjectController,
                    decoration: const InputDecoration(
                      labelText: 'Subject',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: contentController,
                    decoration: const InputDecoration(
                      labelText: 'Content',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 5,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                _updateRequestInDatabase(
                  fromController.text.trim(),
                  toController.text.trim(),
                  subjectController.text.trim(),
                  contentController.text.trim(),
                );
                Navigator.of(context).pop();
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _deleteRequest(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Request'),
          content: const Text(
            'Are you sure you want to delete this OD request? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                _deleteRequestFromDatabase();
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).pop(); // Close detail page
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _updateRequestInDatabase(
    String from,
    String to,
    String subject,
    String content,
  ) async {
    try {
      final mongoUri = LocalConfig.mongoUri;
      const collectionName = "od_requests";

      final db = await mongo.Db.create(mongoUri);
      await db.open();
      final collection = db.collection(collectionName);

      // Find the request by student email and timestamp to update it
      final filter = {
        'studentEmail':
            _requestData['studentEmail'] ?? widget.requestData['studentEmail'],
        'createdAt':
            _requestData['timestamp'] ??
            widget.requestData['timestamp'] ??
            widget.requestData['createdAt'],
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
          _requestData['from'] = from;
          _requestData['to'] = to;
          _requestData['subject'] = subject;
          _requestData['content'] = content;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update request. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating request: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteRequestFromDatabase() async {
    try {
      final mongoUri = LocalConfig.mongoUri;
      const collectionName = "od_requests";

      final db = await mongo.Db.create(mongoUri);
      await db.open();
      final collection = db.collection(collectionName);

      // Find the request by student email and timestamp to delete it
      final filter = {
        'studentEmail':
            _requestData['studentEmail'] ?? widget.requestData['studentEmail'],
        'createdAt':
            _requestData['timestamp'] ??
            widget.requestData['timestamp'] ??
            widget.requestData['createdAt'],
      };

      final result = await collection.deleteOne(filter);
      await db.close();

      if (result.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request deleted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete request. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting request: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isAccepted =
        _requestData['status'].toString().toLowerCase() == 'accepted';
    final size = MediaQuery.of(context).size;

    return WillPopScope(
      onWillPop: () async => false,
      child: Dialog(
        backgroundColor: Colors.white,
        elevation: 0,
        insetPadding: EdgeInsets.zero,
        child: Container(
          width: double.infinity,
          constraints: BoxConstraints(
            maxWidth: size.width,
            maxHeight: size.height,
          ),
          decoration: const BoxDecoration(color: Colors.white),
          child: Column(
            children: [
              // Header with back button, title and status
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
                      'OD Request Details',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    // Three-dot menu
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, size: 20),
                      onSelected: (String value) {
                        if (value == 'edit') {
                          _editRequest(context);
                        } else if (value == 'delete') {
                          _deleteRequest(context);
                        }
                      },
                      itemBuilder:
                          (BuildContext context) => <PopupMenuEntry<String>>[
                            const PopupMenuItem<String>(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.edit,
                                    size: 18,
                                    color: Colors.blue,
                                  ),
                                  SizedBox(width: 8),
                                  Text('Edit'),
                                ],
                              ),
                            ),
                            const PopupMenuItem<String>(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.delete,
                                    size: 18,
                                    color: Colors.red,
                                  ),
                                  SizedBox(width: 8),
                                  Text('Delete'),
                                ],
                              ),
                            ),
                          ],
                    ),
                    const SizedBox(width: 8),
                    // Status badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getStatusColor(
                          _requestData['status'],
                        ).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _getStatusColor(_requestData['status']),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        _requestData['status'].toString().toUpperCase(),
                        style: TextStyle(
                          color: _getStatusColor(_requestData['status']),
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Letter content in scrollable area
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 20,
                  ),
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
                        const Center(
                          child: Column(
                            children: [
                              Text(
                                'ON-DUTY REQUEST LETTER',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 4),
                              Divider(thickness: 1),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Date
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            'Date: ${_requestData['date'] ?? 'Not Specified'}',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // From section
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'From:',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _requestData['from'] ?? 'Not Specified',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // To section
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'To:',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _requestData['to'] ?? 'Not Specified',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Subject
                        Text(
                          'Subject: ${_requestData['subject'] ?? 'Request for On-Duty Permission'}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Letter content
                        const Text(
                          'Respected Sir/Madam,',
                          style: TextStyle(fontSize: 13),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _requestData['content'] ?? 'No content provided',
                          style: const TextStyle(fontSize: 13, height: 1.5),
                        ),
                        const SizedBox(height: 20),

                        // Thank you
                        const Center(
                          child: Text(
                            'Thank you for your consideration.',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Download button for accepted requests
              if (isAccepted)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(color: Colors.white),
                  child: Center(
                    child: SizedBox(
                      width: double.infinity,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: ElevatedButton.icon(
                          icon: const Icon(
                            Icons.picture_as_pdf,
                            color: Colors.white,
                            size: 18,
                          ),
                          label: const Text(
                            'Download OD Request Letter',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onPressed: () => _downloadPdf(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
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
  }
}
