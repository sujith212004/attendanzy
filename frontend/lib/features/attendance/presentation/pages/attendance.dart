import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AttendanceSelectionPage extends StatefulWidget {
  const AttendanceSelectionPage({super.key});
  @override
  State<AttendanceSelectionPage> createState() =>
      _AttendanceSelectionPageState();
}

class _AttendanceSelectionPageState extends State<AttendanceSelectionPage>
    with TickerProviderStateMixin {
  String? _department; // Fetched from SharedPreferences
  String? _selectedYear;
  String? _selectedSection;
  bool _isLoading = true;

  late AnimationController _animationController;
  late AnimationController _buttonController;
  late AnimationController _cardController;
  late AnimationController _progressController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _cardSlideAnimation;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _getDepartment();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _buttonController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _cardController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _progressController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _slideAnimation = Tween<double>(begin: 80.0, end: 0.0).animate(
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

    _cardSlideAnimation = Tween<double>(begin: 100.0, end: 0.0).animate(
      CurvedAnimation(parent: _cardController, curve: Curves.easeOutBack),
    );

    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _buttonController.dispose();
    _cardController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  Future<void> _getDepartment() async {
    _progressController.forward();

    final prefs = await SharedPreferences.getInstance();
    await Future.delayed(const Duration(milliseconds: 800)); // Smooth loading

    if (mounted) {
      setState(() {
        _department = prefs.getString('department') ?? '';
        _isLoading = false;
      });
      _animationController.forward();
      await Future.delayed(const Duration(milliseconds: 300));
      _cardController.forward();
      HapticFeedback.lightImpact();
    }
  }

  void _onSelectionChanged() {
    HapticFeedback.selectionClick();
    _cardController.reset();
    _cardController.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: _isLoading ? _buildLoadingState() : _buildMainContent(),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF667eea),
            Color(0xFF764ba2),
            Color(0xFFf093fb),
            Color(0xFFf5576c),
            Color(0xFF4facfe),
            Color(0xFF00f2fe),
          ],
          stops: [0.0, 0.2, 0.4, 0.6, 0.8, 1.0],
        ),
      ),
      child: AnimatedBuilder(
        animation: _progressController,
        builder: (context, child) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Enhanced loading animation
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Outer progress ring
                      SizedBox(
                        width: 80,
                        height: 80,
                        child: CircularProgressIndicator(
                          value: _progressAnimation.value,
                          strokeWidth: 4,
                          backgroundColor: Colors.white.withOpacity(0.2),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      ),
                      // Center icon with pulse animation
                      Transform.scale(
                        scale: 1.0 + (0.1 * _progressAnimation.value),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.white, const Color(0xFFF0F8FF)],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.white.withOpacity(0.3),
                                blurRadius: 15,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.school_rounded,
                            color: Color(0xFF667eea),
                            size: 24,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                // Animated text
                TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 1500),
                  tween: Tween(begin: 0.0, end: 1.0),
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, 20 * (1 - value)),
                        child: Column(
                          children: [
                            const Text(
                              'Setting up Attendance',
                              style: TextStyle(
                                fontSize: 20,
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Preparing your class selection...',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.8),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMainContent() {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF667eea),
                Color(0xFF764ba2),
                Color(0xFFf093fb),
                Color(0xFFf5576c),
                Color(0xFF4facfe),
                Color(0xFF00f2fe),
              ],
              stops: [0.0, 0.2, 0.4, 0.6, 0.8, 1.0],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: _buildProfessionalHeader(),
                ),
                Expanded(
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Transform.translate(
                      offset: Offset(0, _slideAnimation.value),
                      child: _buildSelectionContent(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfessionalHeader() {
    return Container(
      margin: const EdgeInsets.all(20),
      child: Stack(
        children: [
          // Background with glass morphism effect
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.2),
                  Colors.white.withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: [
                // Enhanced back button
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.pop(context);
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(12),
                        child: Icon(
                          Icons.arrow_back_ios_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                // Enhanced title section
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.analytics_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Attendance Setup',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Configure your class details for seamless attendance tracking',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.9),
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Subtle animated particles for background effect
          ...List.generate(3, (index) {
            return Positioned(
              top: 20 + (index * 15.0),
              right: 20 + (index * 25.0),
              child: AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return Opacity(
                    opacity: 0.1 + (0.2 * _animationController.value),
                    child: Container(
                      width: 6 + (index * 2.0),
                      height: 6 + (index * 2.0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                },
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSelectionContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          if (_department != null && _department!.isNotEmpty) ...[
            ScaleTransition(
              scale: _scaleAnimation,
              child: _buildDepartmentCard(),
            ),
            const SizedBox(height: 24),
          ],
          ScaleTransition(scale: _scaleAnimation, child: _buildSelectionCard()),
          const Spacer(),
          ScaleTransition(
            scale: _scaleAnimation,
            child: _buildProfessionalNextButton(),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildDepartmentCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, const Color(0xFFF8FAFC), Colors.white],
          stops: [0.0, 0.5, 1.0],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: const Color(0xFF667eea).withOpacity(0.1),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF667eea).withOpacity(0.2),
                  const Color(0xFF764ba2).withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF667eea).withOpacity(0.3),
                width: 1,
              ),
            ),
            child: const Icon(
              Icons.business_rounded,
              color: Color(0xFF667eea),
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Department',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _department!,
                  style: const TextStyle(
                    fontSize: 18,
                    color: Color(0xFF1A202C),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, const Color(0xFFF8FAFC), Colors.white],
          stops: [0.0, 0.5, 1.0],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: const Color(0xFF667eea).withOpacity(0.1),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF667eea).withOpacity(0.2),
                      const Color(0xFF764ba2).withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF667eea).withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: const Icon(
                  Icons.class_rounded,
                  color: Color(0xFF667eea),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Class Details',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A202C),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ProfessionalDropdown(
            label: 'Academic Year',
            hintText: 'Select Year',
            icon: Icons.calendar_today_rounded,
            items: const ['1st Year', '2nd Year', '3rd Year', '4th Year'],
            value: _selectedYear,
            onChanged: (value) {
              setState(() => _selectedYear = value);
              HapticFeedback.selectionClick();
            },
          ),
          const SizedBox(height: 20),
          ProfessionalDropdown(
            label: 'Section',
            hintText: 'Select Section',
            icon: Icons.group_rounded,
            items: const ['A', 'B', 'C', 'NULL'],
            value: _selectedSection,
            onChanged: (value) {
              setState(() => _selectedSection = value);
              HapticFeedback.selectionClick();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildProfessionalNextButton() {
    final isEnabled =
        _department != null &&
        _department!.isNotEmpty &&
        _selectedYear != null &&
        _selectedSection != null;

    return AnimatedBuilder(
      animation: _buttonController,
      builder: (context, child) {
        return TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 500),
          tween: Tween<double>(begin: 0.0, end: isEnabled ? 1.0 : 0.0),
          curve: Curves.elasticOut,
          builder: (context, enabledValue, child) {
            return Transform.scale(
              scale:
                  (0.95 + (0.05 * enabledValue)) -
                  (_buttonController.value * 0.05),
              child: Container(
                width: double.infinity,
                height: 64,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors:
                        isEnabled
                            ? [
                              const Color(0xFF667eea),
                              const Color(0xFF764ba2),
                              const Color(0xFF667eea),
                            ]
                            : [
                              Colors.grey.withOpacity(0.3),
                              Colors.grey.withOpacity(0.2),
                              Colors.grey.withOpacity(0.15),
                            ],
                    stops: [0.0, 0.5, 1.0],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    if (isEnabled)
                      BoxShadow(
                        color: const Color(0xFF667eea).withOpacity(0.4),
                        blurRadius: 25,
                        offset: const Offset(0, 10),
                      ),
                    if (isEnabled)
                      BoxShadow(
                        color: const Color(0xFF764ba2).withOpacity(0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap:
                        isEnabled
                            ? () async {
                              _buttonController.forward().then((_) {
                                _buttonController.reverse();
                              });
                              HapticFeedback.heavyImpact();

                              Navigator.pushNamed(
                                context,
                                '/attendancemark',
                                arguments: {
                                  'department': _department,
                                  'year': _selectedYear,
                                  'section': _selectedSection,
                                },
                              );
                            }
                            : null,
                    child: Stack(
                      children: [
                        // Animated shimmer effect
                        if (isEnabled)
                          Positioned.fill(
                            child: AnimatedBuilder(
                              animation: _progressAnimation,
                              builder: (context, child) {
                                return Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(20),
                                    gradient: LinearGradient(
                                      begin: Alignment(
                                        -1.0 + (_progressAnimation.value * 3),
                                        0,
                                      ),
                                      end: Alignment(
                                        1.0 + (_progressAnimation.value * 3),
                                        0,
                                      ),
                                      colors: [
                                        Colors.transparent,
                                        Colors.white.withOpacity(0.15),
                                        Colors.transparent,
                                      ],
                                      stops: const [0.0, 0.5, 1.0],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),

                        // Button content
                        Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Enhanced icon with pulse animation
                              TweenAnimationBuilder<double>(
                                duration: const Duration(milliseconds: 600),
                                tween: Tween<double>(
                                  begin: 0.0,
                                  end: isEnabled ? 1.0 : 0.0,
                                ),
                                builder: (context, value, child) {
                                  return Transform.scale(
                                    scale: 0.8 + (0.3 * value),
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.white.withOpacity(0.25),
                                            Colors.white.withOpacity(0.15),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Colors.white.withOpacity(0.3),
                                          width: 1,
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.rocket_launch_rounded,
                                        color:
                                            isEnabled
                                                ? Colors.white
                                                : Colors.grey.withOpacity(0.6),
                                        size: 20,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(width: 16),

                              // Enhanced text
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Continue to Attendance',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color:
                                          isEnabled
                                              ? Colors.white
                                              : Colors.grey.withOpacity(0.6),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  if (isEnabled)
                                    Text(
                                      'Start marking attendance',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.white.withOpacity(0.8),
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                ],
                              ),

                              const SizedBox(width: 16),

                              // Animated arrow
                              TweenAnimationBuilder<double>(
                                duration: const Duration(milliseconds: 400),
                                tween: Tween<double>(
                                  begin: 0.0,
                                  end: isEnabled ? 1.0 : 0.0,
                                ),
                                builder: (context, value, child) {
                                  return Transform.translate(
                                    offset: Offset(value * 5, 0),
                                    child: Icon(
                                      Icons.arrow_forward_rounded,
                                      color:
                                          isEnabled
                                              ? Colors.white
                                              : Colors.grey.withOpacity(0.6),
                                      size: 24,
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),

                        // Success indicator
                        if (isEnabled)
                          Positioned(
                            right: 16,
                            top: 8,
                            child: AnimatedBuilder(
                              animation: _cardController,
                              builder: (context, child) {
                                return Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.green.withOpacity(0.9),
                                        const Color(
                                          0xFF4CAF50,
                                        ).withOpacity(0.8),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.green.withOpacity(0.3),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                );
                              },
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
      },
    );
  }
}

class ProfessionalDropdown extends StatefulWidget {
  final String label;
  final String hintText;
  final IconData icon;
  final List<String> items;
  final String? value;
  final ValueChanged<String?> onChanged;
  final bool enabled;

  const ProfessionalDropdown({
    super.key,
    required this.label,
    required this.hintText,
    required this.icon,
    required this.items,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  State<ProfessionalDropdown> createState() => _ProfessionalDropdownState();
}

class _ProfessionalDropdownState extends State<ProfessionalDropdown>
    with SingleTickerProviderStateMixin {
  late AnimationController _hoverController;
  late Animation<double> _scaleAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _hoverController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.02,
    ).animate(CurvedAnimation(parent: _hoverController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _hoverController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _hoverController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Enhanced label with icon
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors:
                            widget.enabled
                                ? [
                                  const Color(0xFF667eea).withOpacity(0.2),
                                  const Color(0xFF764ba2).withOpacity(0.1),
                                ]
                                : [
                                  Colors.grey.withOpacity(0.1),
                                  Colors.grey.withOpacity(0.05),
                                ],
                      ),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color:
                            widget.enabled
                                ? const Color(0xFF667eea).withOpacity(0.3)
                                : Colors.grey.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      widget.icon,
                      size: 16,
                      color:
                          widget.enabled
                              ? const Color(0xFF667eea)
                              : Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    widget.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color:
                          widget.enabled
                              ? const Color(0xFF374151)
                              : Colors.grey,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Enhanced dropdown container
              MouseRegion(
                onEnter: (_) {
                  if (widget.enabled) {
                    setState(() => _isHovered = true);
                    _hoverController.forward();
                  }
                },
                onExit: (_) {
                  setState(() => _isHovered = false);
                  _hoverController.reverse();
                },
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors:
                          widget.enabled
                              ? [
                                const Color(0xFFF9FAFB),
                                const Color(0xFFF3F4F6),
                              ]
                              : [
                                const Color(0xFFF5F5F5),
                                const Color(0xFFEEEEEE),
                              ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color:
                          widget.value != null
                              ? const Color(0xFF667eea)
                              : widget.enabled
                              ? const Color(0xFFE5E7EB)
                              : Colors.grey.withOpacity(0.3),
                      width: widget.value != null ? 2.0 : 1.5,
                    ),
                    boxShadow: [
                      if (widget.value != null && widget.enabled)
                        BoxShadow(
                          color: const Color(0xFF667eea).withOpacity(0.15),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      if (_isHovered && widget.enabled)
                        BoxShadow(
                          color: const Color(0xFF667eea).withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      children: [
                        // Animated icon
                        TweenAnimationBuilder<double>(
                          duration: const Duration(milliseconds: 300),
                          tween: Tween<double>(
                            begin: 0.0,
                            end: widget.value != null ? 1.0 : 0.5,
                          ),
                          builder: (context, value, child) {
                            return Transform.scale(
                              scale: 1.0 + (0.1 * value),
                              child: Icon(
                                widget.icon,
                                size: 20,
                                color: Color.lerp(
                                  const Color(0xFF9CA3AF),
                                  const Color(0xFF667eea),
                                  value,
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 16),

                        // Enhanced dropdown
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: widget.value,
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                vertical: 18,
                              ),
                            ),
                            hint: Text(
                              widget.hintText,
                              style: TextStyle(
                                color:
                                    widget.enabled
                                        ? const Color(0xFF9CA3AF)
                                        : Colors.grey.withOpacity(0.6),
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            items:
                                widget.items
                                    .map(
                                      (String item) => DropdownMenuItem<String>(
                                        value: item,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 2,
                                            horizontal: 10,
                                          ),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                Colors.white.withOpacity(0.8),
                                                Colors.white.withOpacity(0.9),
                                              ],
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(
                                              color: Colors.grey.withOpacity(
                                                0.1,
                                              ),
                                            ),
                                          ),
                                          child: Text(
                                            item,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w500,
                                              color: Color(0xFF1F2937),
                                            ),
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                            onChanged:
                                widget.enabled
                                    ? (value) {
                                      HapticFeedback.selectionClick();
                                      widget.onChanged(value);
                                    }
                                    : null,
                            dropdownColor: Colors.white,
                            icon: AnimatedRotation(
                              turns: _isHovered ? 0.5 : 0.0,
                              duration: const Duration(milliseconds: 200),
                              child: Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color:
                                    widget.enabled
                                        ? const Color(0xFF6B7280)
                                        : Colors.grey.withOpacity(0.5),
                                size: 28,
                              ),
                            ),
                            style: TextStyle(
                              color:
                                  widget.enabled
                                      ? const Color(0xFF1F2937)
                                      : Colors.grey,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            menuMaxHeight: 300,
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
      },
    );
  }
}

// Legacy widget kept for backward compatibility if needed elsewhere
class CustomDropdown extends StatelessWidget {
  final String hintText;
  final List<String> items;
  final String? value;
  final ValueChanged<String?> onChanged;

  const CustomDropdown({
    super.key,
    required this.hintText,
    required this.items,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: DropdownButtonFormField<String>(
          value: value,
          decoration: const InputDecoration(border: InputBorder.none),
          hint: Text(hintText, style: const TextStyle(color: Colors.grey)),
          items:
              items
                  .map(
                    (String value) => DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    ),
                  )
                  .toList(),
          onChanged: onChanged,
          dropdownColor: Colors.white,
          style: const TextStyle(color: Colors.black),
        ),
      ),
    );
  }
}
