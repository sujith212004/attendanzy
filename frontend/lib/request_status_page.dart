import 'package:flutter/material.dart';
import 'studentODstatespage.dart';
import 'student_leave_status_page.dart';

class RequestStatusPage extends StatefulWidget {
  final String studentEmail;
  const RequestStatusPage({Key? key, required this.studentEmail})
    : super(key: key);

  @override
  State<RequestStatusPage> createState() => _RequestStatusPageState();
}

class _RequestStatusPageState extends State<RequestStatusPage> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Request Status'),
        backgroundColor: const Color(0xFF667EEA),
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildTabButton('OD Status', 0),
                const SizedBox(width: 16),
                _buildTabButton('Leave Status', 1),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child:
                _selectedIndex == 0
                    ? StudentODStatusPage(studentEmail: widget.studentEmail)
                    : StudentLeaveStatusPage(studentEmail: widget.studentEmail),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, int index) {
    final bool isSelected = _selectedIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedIndex = index;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF667EEA) : Colors.grey[200],
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF374151),
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
