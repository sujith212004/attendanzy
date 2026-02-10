import 'package:flutter/material.dart';
import 'package:mongo_dart/mongo_dart.dart' as mongo;
import '../config/local_config.dart';

class DepartmentReport extends StatefulWidget {
  const DepartmentReport({super.key});

  @override
  State<DepartmentReport> createState() => _DepartmentReportState();
}

class _DepartmentReportState extends State<DepartmentReport>
    with TickerProviderStateMixin {
  final String mongoUri = LocalConfig.mongoUri;

  final String odCollection = "od_requests";
  final String leaveCollection = "leave_requests";

  Map<String, dynamic> reportData = {};
  Map<String, dynamic> filteredData = {};
  bool loading = true;

  // Dropdown values
  String? selectedYear;
  String? selectedSection;

  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Available options
  final List<String> years = ['1st Year', '2nd Year', '3rd Year', '4th Year'];
  final List<String> sections = ['A', 'B', 'C'];

  @override
  void initState() {
    super.initState();

    // Initialize animation controllers
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    // Initialize animations
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
    );

    _fetchWeeklyReport();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _fetchWeeklyReport() async {
    final db = await mongo.Db.create(mongoUri);
    await db.open();

    final odCol = db.collection(odCollection);
    final leaveCol = db.collection(leaveCollection);

    // 🔹 Get start and end of current week
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 7));

    // 🔹 Query OD & Leave requests created this week
    final odRequests =
        await odCol
            .find(
              mongo.where
                  .gte("createdAt", startOfWeek.toIso8601String())
                  .lt("createdAt", endOfWeek.toIso8601String()),
            )
            .toList();

    final leaveRequests =
        await leaveCol
            .find(
              mongo.where
                  .gte("createdAt", startOfWeek.toIso8601String())
                  .lt("createdAt", endOfWeek.toIso8601String()),
            )
            .toList();

    // 🔹 Combine and process
    final allRequests = [...odRequests, ...leaveRequests];
    final Map<String, Map<String, int>> result = {};

    for (var req in allRequests) {
      final year = req["year"] ?? "Unknown";
      final section = req["section"] ?? "-";
      final key = "$year-$section";

      result.putIfAbsent(
        key,
        () => {
          "total": 0,
          "od": 0,
          "leave": 0,
          "pending": 0,
          "staffAccepted": 0,
          "hodAccepted": 0,
          "rejected": 0,
        },
      );

      result[key]!["total"] = (result[key]!["total"] ?? 0) + 1;

      // Count OD vs Leave
      if (req.containsKey("leaveType")) {
        result[key]!["leave"] = (result[key]!["leave"] ?? 0) + 1;
      } else {
        result[key]!["od"] = (result[key]!["od"] ?? 0) + 1;
      }

      // Status handling
      final staff = req["staffStatus"] ?? "pending";
      final hod = req["hodStatus"] ?? "pending";

      if (staff == "pending" && hod == "pending") {
        result[key]!["pending"] = (result[key]!["pending"] ?? 0) + 1;
      }
      if (staff == "accepted") {
        result[key]!["staffAccepted"] =
            (result[key]!["staffAccepted"] ?? 0) + 1;
      }
      if (hod == "accepted") {
        result[key]!["hodAccepted"] = (result[key]!["hodAccepted"] ?? 0) + 1;
      }
      if (staff == "rejected" || hod == "rejected") {
        result[key]!["rejected"] = (result[key]!["rejected"] ?? 0) + 1;
      }
    }

    setState(() {
      reportData = result;
      filteredData = result;
      loading = false;
    });

    // Start animations after the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _fadeController.forward();
        _slideController.forward();
      }
    });

    await db.close();
  }

  void _filterData() {
    setState(() {
      if (selectedYear == null && selectedSection == null) {
        filteredData = reportData;
      } else {
        filteredData = Map.fromEntries(
          reportData.entries.where((entry) {
            final key = entry.key;
            final parts = key.split('-');
            final year = parts.isNotEmpty ? parts[0] : '';
            final section = parts.length > 1 ? parts[1] : '';

            bool yearMatch = selectedYear == null || year == selectedYear;
            bool sectionMatch =
                selectedSection == null || section == selectedSection;

            return yearMatch && sectionMatch;
          }),
        );
      }
    });

    // Restart animations for filtered data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _fadeController.reset();
        _slideController.reset();
        _fadeController.forward();
        _slideController.forward();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
              const SizedBox(height: 16),
              Text(
                'Loading Department Report...',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          "Department Report",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Filter Section
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withValues(alpha: 0.1),
                  spreadRadius: 2,
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Filter Options',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildDropdown('Year', selectedYear, years, (
                        value,
                      ) {
                        setState(() {
                          selectedYear = value;
                        });
                        _filterData();
                      }, Icons.calendar_today),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildDropdown(
                        'Section',
                        selectedSection,
                        sections,
                        (value) {
                          setState(() {
                            selectedSection = value;
                          });
                          _filterData();
                        },
                        Icons.group,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Clear filters button
                if (selectedYear != null || selectedSection != null)
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        selectedYear = null;
                        selectedSection = null;
                      });
                      _filterData();
                    },
                    icon: const Icon(Icons.clear, size: 18),
                    label: const Text('Clear Filters'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.blue[700],
                    ),
                  ),
              ],
            ),
          ),

          // Results Section
          Expanded(
            child: AnimatedBuilder(
              animation: Listenable.merge([_fadeAnimation, _slideAnimation]),
              builder: (context, child) {
                return FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child:
                        filteredData.isEmpty
                            ? _buildEmptyState()
                            : ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              itemCount: filteredData.length,
                              itemBuilder: (context, index) {
                                final entry = filteredData.entries.elementAt(
                                  index,
                                );
                                final key = entry.key;
                                final stats = entry.value;
                                return _buildReportCard(key, stats, index);
                              },
                            ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown(
    String label,
    String? value,
    List<String> items,
    Function(String?) onChanged,
    IconData icon,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: Colors.grey[600]),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
            color: Colors.grey[50],
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              hint: Text('Select $label'),
              isExpanded: true,
              items: [
                DropdownMenuItem<String>(
                  value: null,
                  child: Text('All $label'),
                ),
                ...items.map(
                  (item) =>
                      DropdownMenuItem<String>(value: item, child: Text(item)),
                ),
              ],
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No data found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your filters',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildReportCard(String key, Map<String, int> stats, int index) {
    final parts = key.split('-');
    final year = parts.isNotEmpty ? parts[0] : '';
    final section = parts.length > 1 ? parts[1] : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: AnimatedBuilder(
        animation: _slideAnimation,
        builder: (context, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: Offset(0, 0.3 + (index * 0.1)),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(
                parent: _slideController,
                curve: Curves.easeOutCubic,
              ),
            ),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.white, Colors.blue[50]!],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.school,
                              color: Colors.blue[700],
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  year,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.blue[700],
                                  ),
                                ),
                                Text(
                                  'Section $section',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue[700],
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${stats['total']} Total',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),
                      const Divider(color: Colors.grey),
                      const SizedBox(height: 16),

                      // Stats Grid
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatItem(
                              'OD Requests',
                              stats['od'] ?? 0,
                              Icons.event_note,
                              Colors.orange,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatItem(
                              'Leave Requests',
                              stats['leave'] ?? 0,
                              Icons.event_available,
                              Colors.green,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: _buildStatItem(
                              'Pending',
                              stats['pending'] ?? 0,
                              Icons.schedule,
                              Colors.amber,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatItem(
                              'Accepted',
                              (stats['staffAccepted'] ?? 0) +
                                  (stats['hodAccepted'] ?? 0),
                              Icons.check_circle,
                              Colors.green,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatItem(
                              'Rejected',
                              stats['rejected'] ?? 0,
                              Icons.cancel,
                              Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatItem(String label, int value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            value.toString(),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
