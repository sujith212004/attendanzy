import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui';
import '../../../home/presentation/pages/homepage.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/services/firebase_api.dart';
import 'forgot_password_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String _errorMessage = '';
  bool _isPasswordVisible = false;
  bool _isLoading = false;

  late AnimationController _orbController;
  late AnimationController _staggerController;
  late AnimationController _shimmerController;

  final List<Animation<double>> _staggerAnimations = [];

  final List<String> _roles = ['User', 'Staff', 'HOD'];
  final List<String> _departments = [
    'Computer Science',
    'Mechanical Engineering',
    'Civil Engineering',
    'Electrical Engineering',
    'Electronics and Communication Engineering',
    'Information Technology',
  ];
  int _selectedRoleIndex = 0;
  int _selectedDepartmentIndex = 0;

  @override
  void initState() {
    super.initState();

    _orbController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat(reverse: true);

    _staggerController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _shimmerController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: false);

    _initStaggerAnimations();
    _checkLoginStatus();

    // Start entrance animation after a slight delay
    Future.delayed(const Duration(milliseconds: 200), () {
      _staggerController.forward();
    });
  }

  void _initStaggerAnimations() {
    // Create 5 staggered animations
    for (int i = 0; i < 5; i++) {
      _staggerAnimations.add(
        CurvedAnimation(
          parent: _staggerController,
          curve: Interval(0.1 * i, 0.6 + (0.1 * i), curve: Curves.easeOutCubic),
        ),
      );
    }
  }

  @override
  void dispose() {
    _orbController.dispose();
    _staggerController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  // ... _checkLoginStatus and _login methods remain the same ...

  // ... _login method implementation ...
  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('email');
    final name = prefs.getString('name');
    final role = prefs.getString('role') ?? '';
    final isStaff = prefs.getBool('isStaff') ?? false;

    if (email != null && name != null && role.isNotEmpty) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder:
              (context) => HomePage(
                name: name,
                email: email,
                profile: {},
                isStaff: isStaff,
                role: role,
              ),
        ),
      );
    }
  }

  void _login() async {
    setState(() {
      _errorMessage = '';
      _isLoading = true;
    });

    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();
    String selectedRole = _roles[_selectedRoleIndex].toLowerCase();
    String selectedDepartment = _departments[_selectedDepartmentIndex];

    HapticFeedback.lightImpact();

    if (email.isNotEmpty && password.isNotEmpty) {
      try {
        final result = await ApiService.login(
          email: email,
          password: password,
          role: selectedRole,
          department: selectedDepartment,
        );

        setState(() => _isLoading = false);

        if (result['success']) {
          HapticFeedback.heavyImpact();
          final user = result['profile'];
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(
            'email',
            user["email"] ?? user["College Email"] ?? '',
          );
          await prefs.setString('name', user["name"] ?? user["Name"] ?? '');
          await prefs.setBool(
            'isStaff',
            selectedRole == 'staff' || selectedRole == 'hod',
          );
          await prefs.setString('role', selectedRole);
          await prefs.setString('department', selectedDepartment);

          if (selectedRole == 'user') {
            await prefs.setString('year', user['year'] ?? '');
            await prefs.setString('sec', user['sec'] ?? '');
          } else if (selectedRole == 'staff') {
            await prefs.setString(
              'staffName',
              user['name'] ?? user['Name'] ?? '',
            );
          }

          final userEmail = user["email"] ?? user["College Email"] ?? '';
          if (userEmail.isNotEmpty) {
            FirebaseApi()
                .updateTokenForUser(userEmail)
                .catchError((e) => print(e));
          }

          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder:
                  (_, a, __) => HomePage(
                    name: user["name"] ?? user["Name"] ?? '',
                    email: user["email"] ?? user["College Email"] ?? '',
                    profile: user,
                    isStaff: selectedRole == 'staff' || selectedRole == 'hod',
                    role: selectedRole,
                  ),
              transitionsBuilder:
                  (_, a, __, c) => FadeTransition(opacity: a, child: c),
            ),
          );
        } else {
          HapticFeedback.mediumImpact();
          setState(() {
            _errorMessage = result['message'] ?? 'Invalid credentials.';
          });
        }
      } catch (e) {
        HapticFeedback.mediumImpact();
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to connect to the server.';
        });
      }
    } else {
      HapticFeedback.mediumImpact();
      setState(() {
        _isLoading = false;
        _errorMessage = 'Please fill in all fields.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        fit: StackFit.expand,
        children: [
          _buildAnimatedOrbs(),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 24,
                ),
                child: Column(
                  children: [
                    // 1. Header Entrance
                    _buildStaggeredItem(index: 0, child: _buildHeader()),
                    const SizedBox(height: 40),

                    // 2. Card Entrance
                    _buildStaggeredItem(
                      index: 1,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: RepaintBoundary(
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 40,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.white.withOpacity(0.8),
                                    Colors.white.withOpacity(0.5),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(28),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.6),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF64748B,
                                    ).withOpacity(0.1),
                                    blurRadius: 40,
                                    offset: const Offset(0, 15),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _buildModernInput(
                                    controller: _emailController,
                                    hint: "Email Address",
                                    icon: Icons.alternate_email_rounded,
                                  ),
                                  const SizedBox(height: 16),

                                  _buildModernPasswordInput(),

                                  const SizedBox(height: 12),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: GestureDetector(
                                      onTap:
                                          () => Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder:
                                                  (_) =>
                                                      const ForgotPasswordPage(),
                                            ),
                                          ),
                                      child: Text(
                                        "Recover Password",
                                        style: TextStyle(
                                          color: const Color(
                                            0xFF0F172A,
                                          ).withOpacity(0.6),
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 32),

                                  _buildModernDropdown(
                                    value: _selectedRoleIndex,
                                    items: _roles,
                                    hint: "Role",
                                    onChanged:
                                        (val) => setState(
                                          () => _selectedRoleIndex = val,
                                        ),
                                  ),
                                  const SizedBox(height: 16),

                                  _buildModernDropdown(
                                    value: _selectedDepartmentIndex,
                                    items: _departments,
                                    hint: "Department",
                                    onChanged:
                                        (val) => setState(
                                          () => _selectedDepartmentIndex = val,
                                        ),
                                  ),

                                  if (_errorMessage.isNotEmpty) ...[
                                    const SizedBox(height: 24),
                                    Text(
                                      _errorMessage,
                                      style: const TextStyle(
                                        color: Color(0xFFDC2626),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],

                                  const SizedBox(height: 40),
                                  _buildLoginButton(),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // 3. Footer Entrance
                    _buildStaggeredItem(
                      index: 2,
                      child: Text(
                        "ATTENDANZY © 2026",
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 11,
                          letterSpacing: 2.0,
                          fontWeight: FontWeight.bold,
                        ),
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

  Widget _buildStaggeredItem({required int index, required Widget child}) {
    return AnimatedBuilder(
      animation: _staggerController,
      builder: (context, child) {
        final animation = _staggerAnimations[index];
        return Transform.translate(
          offset: Offset(0, 50 * (1 - animation.value)),
          child: Opacity(opacity: animation.value, child: child),
        );
      },
      child: child,
    );
  }

  Widget _buildAnimatedOrbs() {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _orbController,
        builder: (context, child) {
          return Stack(
            children: [
              // Orb 1: Deep Royal Purple
              Positioned(
                top: -100 + (_orbController.value * 60),
                right: -60,
                child: Container(
                  width: 450,
                  height: 450,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF7C3AED).withOpacity(0.35),
                        const Color(0xFFC4B5FD).withOpacity(0.15),
                        Colors.transparent,
                      ],
                      radius: 0.65,
                    ),
                  ),
                ),
              ),
              // Orb 2: Rich Ocean Blue
              Positioned(
                bottom: -80 - (_orbController.value * 50),
                left: -100,
                child: Container(
                  width: 500,
                  height: 500,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF0EA5E9).withOpacity(0.3),
                        const Color(0xFF38BDF8).withOpacity(0.15),
                        Colors.transparent,
                      ],
                      radius: 0.65,
                    ),
                  ),
                ),
              ),
              // Orb 3: Elegant Rose Gold
              Positioned(
                top: 60,
                left: -60 + (_orbController.value * 30),
                child: Container(
                  width: 320,
                  height: 320,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFFFB7185).withOpacity(0.2),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF8B5CF6).withOpacity(0.2),
                blurRadius: 30,
                offset: const Offset(0, 15),
              ),
            ],
          ),
          child: const Icon(
            Icons.school_rounded,
            color: Color(0xFF4F46E5),
            size: 42,
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          "Welcome Back",
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w900,
            color: Color(0xFF0F172A),
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Sign in to your student dashboard",
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF64748B),
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }

  Widget _buildModernInput({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.6)),
      ),
      child: TextField(
        controller: controller,
        style: const TextStyle(
          fontSize: 15,
          color: Color(0xFF0F172A),
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: const Color(0xFF64748B),
            fontSize: 14,
            fontWeight: FontWeight.normal,
          ),
          prefixIcon: Icon(icon, color: const Color(0xFF64748B), size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 18,
          ),
        ),
      ),
    );
  }

  Widget _buildModernPasswordInput() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.6)),
      ),
      child: TextField(
        controller: _passwordController,
        obscureText: !_isPasswordVisible,
        style: const TextStyle(
          fontSize: 15,
          color: Color(0xFF0F172A),
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          hintText: "Password",
          hintStyle: TextStyle(
            color: const Color(0xFF64748B),
            fontSize: 14,
            fontWeight: FontWeight.normal,
          ),
          prefixIcon: const Icon(
            Icons.fingerprint_rounded,
            color: Color(0xFF64748B),
            size: 20,
          ),
          suffixIcon: IconButton(
            icon: Icon(
              _isPasswordVisible
                  ? Icons.visibility_rounded
                  : Icons.visibility_off_rounded,
              color: const Color(0xFF64748B),
              size: 18,
            ),
            onPressed:
                () => setState(() => _isPasswordVisible = !_isPasswordVisible),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 18,
          ),
        ),
      ),
    );
  }

  Widget _buildModernDropdown({
    required int value,
    required List<String> items,
    required String hint,
    required ValueChanged<int> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.6)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF64748B).withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: value,
          isExpanded: true,
          icon: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.expand_more_rounded,
              color: Color(0xFF64748B),
              size: 20,
            ),
          ),
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          items: List.generate(items.length, (index) {
            return DropdownMenuItem(
              value: index,
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (value == index
                                  ? const Color(0xFF6366F1)
                                  : const Color(0xFFCBD5E1))
                              .withOpacity(0.5),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                      color:
                          value == index
                              ? const Color(0xFF6366F1)
                              : const Color(0xFFCBD5E1),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    // Fix: Prevent overflow
                    child: Text(
                      items[index],
                      overflow: TextOverflow.ellipsis, // Handle long text
                      style: TextStyle(
                        color:
                            value == index
                                ? const Color(0xFF4F46E5)
                                : const Color(0xFF0F172A), // Highlight selected
                        fontWeight:
                            value == index ? FontWeight.bold : FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          onChanged: (val) {
            if (val != null) onChanged(val);
          },
        ),
      ),
    );
  }

  Widget _buildLoginButton() {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        return InkWell(
          onTap: _isLoading ? null : _login,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 56,
            clipBehavior: Clip.hardEdge,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E293B), Color(0xFF020617)],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1E293B).withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Shimmer Effect
                Positioned.fill(
                  child: FractionallySizedBox(
                    widthFactor: 0.3, // Width of the dazzle
                    child: Transform.translate(
                      offset: Offset(
                        -200 +
                            (600 *
                                _shimmerController.value), // Move across button
                        0,
                      ),
                      child: Transform.rotate(
                        angle: 0.4, // Tilt the shimmer
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                Colors.white.withOpacity(0.2), // The shine
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Button Content
                _isLoading
                    ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                    : const Text(
                      "Sign In",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
              ],
            ),
          ),
        );
      },
    );
  }
}
