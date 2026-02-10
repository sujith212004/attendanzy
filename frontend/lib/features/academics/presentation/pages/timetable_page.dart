import 'package:flutter/material.dart';
import 'package:mongo_dart/mongo_dart.dart' as mongo;
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/config/local_config.dart';

class TimetablePage extends StatefulWidget {
  const TimetablePage({super.key});

  @override
  _TimetablePageState createState() => _TimetablePageState();
}

class _TimetablePageState extends State<TimetablePage> {
  final String mongoUri = LocalConfig.mongoUri;
  final String timetableCollection = "timetable";

  List<dynamic>? selectedDayTimetable;
  bool isLoading = true;
  String? today;
  String? selectedDay;

  @override
  void initState() {
    super.initState();
    today = getTodayName();
    loadSelectedDay();
  }

  Future<void> loadSelectedDay() async {
    final prefs = await SharedPreferences.getInstance();
    final savedDay = prefs.getString('selectedDay');
    if (savedDay != null) {
      setState(() {
        selectedDay = savedDay;
      });
      print("🔍 Loaded saved day: $savedDay");
    } else {
      setState(() {
        selectedDay = today;
      });
      print("🔍 No saved day found. Defaulting to today: $today");
    }
    fetchTimetableForSelectedDay();
  }

  Future<void> saveSelectedDay(String day) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selectedDay', day);
    print("✅ Saved selected day: $day");
  }

  Future<void> fetchTimetableForSelectedDay() async {
    try {
      setState(() {
        isLoading = true;
      });

      final prefs = await SharedPreferences.getInstance();
      final department = prefs.getString('department') ?? '';
      final year = prefs.getString('year') ?? '';
      final section = prefs.getString('section') ?? '';

      var db = await mongo.Db.create(mongoUri);
      await db.open();
      print("✅ Connected to MongoDB");

      var collection = db.collection(timetableCollection);

      print(
        "🔍 Fetching timetable for: $selectedDay, $department, $year, $section",
      );

      var result = await collection.findOne({
        "department": department,
        "year": year,
        "section": section,
      });

      if (result != null) {
        if (result["time_table"] != null &&
            result["time_table"][selectedDay] != null) {
          setState(() {
            selectedDayTimetable = result["time_table"][selectedDay];
          });
          print("✅ Timetable fetched successfully for $selectedDay.");
        } else {
          print("⚠️ Timetable data not found for $selectedDay.");
          setState(() {
            selectedDayTimetable = [];
          });
        }
      } else {
        print("⚠️ Timetable data not found in the database.");
        setState(() {
          selectedDayTimetable = [];
        });
      }

      await db.close();
    } catch (e) {
      print("⚠️ Error fetching timetable data: $e");
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  String getTodayName() {
    List<String> days = [
      "Monday",
      "Tuesday",
      "Wednesday",
      "Thursday",
      "Friday",
      "Saturday",
      "Sunday",
    ];
    final weekday = DateTime.now().weekday;
    return days[weekday - 1];
  }

  void showDaySelectionDialog() {
    final days = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"];

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
              maxWidth: MediaQuery.of(context).size.width * 0.9,
            ),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 30,
                    offset: const Offset(0, 15),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.calendar_month_outlined,
                              color: Colors.white,
                              size: 30,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            "Select Day",
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "Choose a day to view timetable",
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.8),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Days List
                    ...days.asMap().entries.map((entry) {
                      final day = entry.value;
                      final isSelected = selectedDay == day;
                      final isToday = today == day;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              Navigator.pop(context);
                              setState(() {
                                selectedDay = day;
                              });
                              saveSelectedDay(day);
                              fetchTimetableForSelectedDay();
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                gradient:
                                    isSelected
                                        ? const LinearGradient(
                                          colors: [
                                            Color(0xFF667EEA),
                                            Color(0xFF764BA2),
                                          ],
                                        )
                                        : LinearGradient(
                                          colors: [
                                            const Color(0xFFF8FAFC),
                                            Colors.white,
                                          ],
                                        ),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color:
                                      isSelected
                                          ? Colors.transparent
                                          : isToday
                                          ? const Color(0xFF48BB78)
                                          : const Color(0xFFE2E8F0),
                                  width: isToday ? 2 : 1,
                                ),
                                boxShadow:
                                    isSelected
                                        ? [
                                          BoxShadow(
                                            color: const Color(
                                              0xFF667EEA,
                                            ).withOpacity(0.3),
                                            blurRadius: 12,
                                            offset: const Offset(0, 6),
                                          ),
                                        ]
                                        : [],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color:
                                          isSelected
                                              ? Colors.white.withOpacity(0.2)
                                              : isToday
                                              ? const Color(
                                                0xFF48BB78,
                                              ).withOpacity(0.1)
                                              : const Color(
                                                0xFF667EEA,
                                              ).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Center(
                                      child: Text(
                                        day.substring(0, 3).toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color:
                                              isSelected
                                                  ? Colors.white
                                                  : isToday
                                                  ? const Color(0xFF48BB78)
                                                  : const Color(0xFF667EEA),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          day,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color:
                                                isSelected
                                                    ? Colors.white
                                                    : const Color(0xFF1E293B),
                                          ),
                                        ),
                                        if (isToday)
                                          Text(
                                            "Today",
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              color:
                                                  isSelected
                                                      ? Colors.white
                                                          .withOpacity(0.8)
                                                      : const Color(0xFF48BB78),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  if (isSelected)
                                    Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.check,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),

                    const SizedBox(height: 12),

                    // Close Button
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => Navigator.pop(context),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFFE2E8F0),
                              width: 1,
                            ),
                          ),
                          child: const Text(
                            'Cancel',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ),
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

  Widget buildLoadingAnimation() {
    return Container(
      color: const Color(0xFFF5F7FA),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF667EEA).withOpacity(0.1),
                    const Color(0xFF764BA2).withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(25),
                border: Border.all(
                  color: const Color(0xFF667EEA).withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Center(
                child: LoadingAnimationWidget.staggeredDotsWave(
                  color: const Color(0xFF667EEA),
                  size: 40,
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Loading Timetable...',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Fetching your class schedule',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'My Timetable',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 22,
                color: Color(0xFF1A202C),
                letterSpacing: -0.5,
              ),
            ),
            Text(
              selectedDay != null ? '$selectedDay Schedule' : 'Class Schedule',
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF718096),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        centerTitle: false,
        backgroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        toolbarHeight: 85,
        leadingWidth: 70,
        leading: Container(
          margin: const EdgeInsets.only(left: 20, top: 12, bottom: 12),
          child: Center(
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF667EEA).withOpacity(0.1),
                    const Color(0xFF764BA2).withOpacity(0.1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFF667EEA).withOpacity(0.2),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF667EEA).withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => Navigator.of(context).pop(),
                  borderRadius: BorderRadius.circular(14),
                  child: const Center(
                    child: Icon(
                      Icons.arrow_back_ios_new,
                      color: Color(0xFF667EEA),
                      size: 18,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 20, top: 12, bottom: 12),
            child: Center(
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF667EEA).withOpacity(0.1),
                      const Color(0xFF764BA2).withOpacity(0.1),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFF667EEA).withOpacity(0.2),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF667EEA).withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: showDaySelectionDialog,
                    borderRadius: BorderRadius.circular(14),
                    child: const Center(
                      child: Icon(
                        Icons.calendar_today_outlined,
                        color: Color(0xFF667EEA),
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ),
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
                  const Color(0xFF667EEA).withOpacity(0.3),
                  const Color(0xFF764BA2).withOpacity(0.3),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ),
      body:
          isLoading
              ? buildLoadingAnimation()
              : RefreshIndicator(
                onRefresh: fetchTimetableForSelectedDay,
                color: const Color(0xFF667EEA),
                backgroundColor: Colors.white,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Content Section Header
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF667EEA),
                                    Color(0xFF764BA2),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF667EEA,
                                    ).withOpacity(0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.schedule_outlined,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    selectedDay != null
                                        ? "$selectedDay's Schedule"
                                        : "Today's Schedule",
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Content Section
                      if (selectedDayTimetable == null ||
                          selectedDayTimetable!.isEmpty)
                        _buildEmptyState()
                      else
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ...selectedDayTimetable!.asMap().entries.map((
                              entry,
                            ) {
                              return buildModernPeriodCard(
                                entry.value,
                                entry.key,
                              );
                            }),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
    );
  }

  Widget buildModernPeriodCard(Map<String, dynamic> period, int index) {
    final isCompleted = isPeriodCompleted(period['time']);
    final isCurrentPeriod = isCurrentlyRunning(period['time']);

    // Define sophisticated color schemes for different states
    final ColorScheme colorScheme = _getColorScheme(
      isCompleted,
      isCurrentPeriod,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: colorScheme.cardGradient,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colorScheme.borderColor,
          width: isCurrentPeriod ? 2.5 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadowColor,
            blurRadius: isCurrentPeriod ? 20 : 12,
            offset: Offset(0, isCurrentPeriod ? 8 : 4),
            spreadRadius: isCurrentPeriod ? 2 : 1,
          ),
        ],
      ),
      child: Stack(
        children: [
          // Animated background pattern
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.1),
                    Colors.transparent,
                    colorScheme.accentColor.withOpacity(0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),

          // Status indicator with sophisticated design
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                gradient: colorScheme.statusGradient,
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(24),
                  bottomLeft: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.accentColor.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(colorScheme.statusIcon, size: 14, color: Colors.white),
                  const SizedBox(width: 6),
                  Text(
                    colorScheme.statusText,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Enhanced Period Header
                Row(
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        gradient: colorScheme.numberGradient,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: colorScheme.accentColor.withOpacity(0.3),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.accentColor.withOpacity(0.2),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          // Inner glow effect
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                gradient: RadialGradient(
                                  colors: [
                                    Colors.white.withOpacity(0.3),
                                    Colors.transparent,
                                  ],
                                  center: const Alignment(-0.5, -0.5),
                                ),
                              ),
                            ),
                          ),
                          Center(
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: colorScheme.accentColor,
                                shadows: [
                                  Shadow(
                                    color: Colors.white.withOpacity(0.8),
                                    offset: const Offset(0, 1),
                                    blurRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            period['subject'] ?? 'Subject',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: colorScheme.textColor,
                              letterSpacing: -0.3,
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              gradient: colorScheme.periodLabelGradient,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: colorScheme.accentColor.withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              'Period ${period['period']}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: colorScheme.accentColor,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Enhanced Class Details
                _buildEnhancedDetailRow(
                  Icons.access_time_outlined,
                  'Time',
                  period['time'] ?? 'N/A',
                  colorScheme,
                ),

                const SizedBox(height: 16),

                _buildEnhancedDetailRow(
                  Icons.person_outline,
                  'Instructor',
                  period['staff_name'] ?? 'N/A',
                  colorScheme,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedDetailRow(
    IconData icon,
    String label,
    String value,
    ColorScheme colorScheme,
  ) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            gradient: colorScheme.iconGradient,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: colorScheme.accentColor.withOpacity(0.2),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: colorScheme.accentColor.withOpacity(0.1),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(icon, size: 20, color: colorScheme.accentColor),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.subtitleColor,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.textColor,
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  ColorScheme _getColorScheme(bool isCompleted, bool isCurrentPeriod) {
    if (isCurrentPeriod) {
      // Live/Current class - Vibrant blue scheme
      return ColorScheme(
        cardGradient: LinearGradient(
          colors: [
            const Color(0xFFEFF6FF), // Light blue
            const Color(0xFFDBEAFE), // Slightly darker blue
            Colors.white,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        statusGradient: const LinearGradient(
          colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        numberGradient: LinearGradient(
          colors: [
            const Color(0xFF3B82F6).withOpacity(0.15),
            const Color(0xFF1D4ED8).withOpacity(0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        iconGradient: LinearGradient(
          colors: [
            const Color(0xFF3B82F6).withOpacity(0.1),
            const Color(0xFF1D4ED8).withOpacity(0.05),
          ],
        ),
        periodLabelGradient: LinearGradient(
          colors: [
            const Color(0xFF3B82F6).withOpacity(0.15),
            const Color(0xFF1D4ED8).withOpacity(0.1),
          ],
        ),
        borderColor: const Color(0xFF3B82F6),
        shadowColor: const Color(0xFF3B82F6).withOpacity(0.25),
        accentColor: const Color(0xFF1D4ED8),
        textColor: const Color(0xFF1E3A8A),
        subtitleColor: const Color(0xFF1E40AF),
        statusIcon: Icons.play_circle_filled,
        statusText: 'LIVE NOW',
      );
    } else if (isCompleted) {
      // Completed class - Professional green scheme
      return ColorScheme(
        cardGradient: LinearGradient(
          colors: [
            const Color(0xFFF0FDF4), // Light green
            const Color(0xFFDCFCE7), // Slightly darker green
            Colors.white,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        statusGradient: const LinearGradient(
          colors: [Color(0xFF10B981), Color(0xFF059669)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        numberGradient: LinearGradient(
          colors: [
            const Color(0xFF10B981).withOpacity(0.15),
            const Color(0xFF059669).withOpacity(0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        iconGradient: LinearGradient(
          colors: [
            const Color(0xFF10B981).withOpacity(0.1),
            const Color(0xFF059669).withOpacity(0.05),
          ],
        ),
        periodLabelGradient: LinearGradient(
          colors: [
            const Color(0xFF10B981).withOpacity(0.15),
            const Color(0xFF059669).withOpacity(0.1),
          ],
        ),
        borderColor: const Color(0xFF10B981),
        shadowColor: const Color(0xFF10B981).withOpacity(0.15),
        accentColor: const Color(0xFF059669),
        textColor: const Color(0xFF065F46),
        subtitleColor: const Color(0xFF047857),
        statusIcon: Icons.check_circle,
        statusText: 'COMPLETED',
      );
    } else {
      // Upcoming class - Purple scheme
      return ColorScheme(
        cardGradient: LinearGradient(
          colors: [
            const Color(0xFFFAF5FF), // Light purple
            const Color(0xFFF3E8FF), // Slightly darker purple
            Colors.white,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        statusGradient: const LinearGradient(
          colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        numberGradient: LinearGradient(
          colors: [
            const Color(0xFF8B5CF6).withOpacity(0.15),
            const Color(0xFF7C3AED).withOpacity(0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        iconGradient: LinearGradient(
          colors: [
            const Color(0xFF8B5CF6).withOpacity(0.1),
            const Color(0xFF7C3AED).withOpacity(0.05),
          ],
        ),
        periodLabelGradient: LinearGradient(
          colors: [
            const Color(0xFF8B5CF6).withOpacity(0.15),
            const Color(0xFF7C3AED).withOpacity(0.1),
          ],
        ),
        borderColor: const Color(0xFF8B5CF6),
        shadowColor: const Color(0xFF8B5CF6).withOpacity(0.2),
        accentColor: const Color(0xFF7C3AED),
        textColor: const Color(0xFF581C87),
        subtitleColor: const Color(0xFF6B21A8),
        statusIcon: Icons.schedule,
        statusText: 'UPCOMING',
      );
    }
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
      ),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF667EEA).withOpacity(0.1),
                  const Color(0xFF764BA2).withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF667EEA).withOpacity(0.2),
                width: 1,
              ),
            ),
            child: const Icon(
              Icons.event_busy_outlined,
              size: 40,
              color: Color(0xFF667EEA),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No Classes Today',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            selectedDay != null
                ? 'No timetable data available for $selectedDay'
                : 'No classes scheduled for today',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: showDaySelectionDialog,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF667EEA).withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      color: Colors.white,
                      size: 18,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Select Different Day',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool isCurrentlyRunning(String time) {
    try {
      final normalizedTime = time.replaceAll('.', ':');
      final times = normalizedTime.split("-");
      final startTime = times[0].trim();
      final endTime = times[1].trim();

      final now = TimeOfDay.now();
      final start = parseTimeOfDay(startTime);
      final end = parseTimeOfDay(endTime);

      final nowMinutes = now.hour * 60 + now.minute;
      final startMinutes = start.hour * 60 + start.minute;
      final endMinutes = end.hour * 60 + end.minute;

      return nowMinutes >= startMinutes && nowMinutes < endMinutes;
    } catch (e) {
      return false;
    }
  }

  bool isPeriodCompleted(String time) {
    try {
      final normalizedTime = time.replaceAll('.', ':');
      final times = normalizedTime.split("-");
      final endTime = times[1].trim();

      final now = TimeOfDay.now();
      final end = parseTimeOfDay(endTime);

      return now.hour > end.hour ||
          (now.hour == end.hour && now.minute >= end.minute);
    } catch (e) {
      print("⚠️ Error parsing time: $time, Error: $e");
      return false;
    }
  }

  TimeOfDay parseTimeOfDay(String time) {
    final match = RegExp(r'(\d+):(\d+)(am|pm)').firstMatch(time.toLowerCase());
    if (match == null) {
      throw FormatException("Invalid time format: $time");
    }

    final hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    final period = match.group(3)!;

    final isPM = period == 'pm';
    final normalizedHour =
        (isPM && hour != 12) ? hour + 12 : (hour == 12 && !isPM ? 0 : hour);

    return TimeOfDay(hour: normalizedHour, minute: minute);
  }
}

class ColorScheme {
  final LinearGradient cardGradient;
  final LinearGradient statusGradient;
  final LinearGradient numberGradient;
  final LinearGradient iconGradient;
  final LinearGradient periodLabelGradient;
  final Color borderColor;
  final Color shadowColor;
  final Color accentColor;
  final Color textColor;
  final Color subtitleColor;
  final IconData statusIcon;
  final String statusText;

  ColorScheme({
    required this.cardGradient,
    required this.statusGradient,
    required this.numberGradient,
    required this.iconGradient,
    required this.periodLabelGradient,
    required this.borderColor,
    required this.shadowColor,
    required this.accentColor,
    required this.textColor,
    required this.subtitleColor,
    required this.statusIcon,
    required this.statusText,
  });
}
