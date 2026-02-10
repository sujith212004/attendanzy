// ✂ keep all your imports as they are
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'homepage.dart';
import 'services/api_service.dart';
import 'firebase_api.dart';

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

  // Animation Controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _scaleController;
  late AnimationController _buttonController;
  late AnimationController _errorController;

  // Animations
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _buttonScaleAnimation;
  late Animation<double> _errorShakeAnimation;

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
    _initializeAnimations();
    _checkLoginStatus();
    _startEntryAnimation();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _buttonController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _errorController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );
    _buttonScaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _buttonController, curve: Curves.easeInOut),
    );
    _errorShakeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _errorController, curve: Curves.elasticOut),
    );
  }

  void _startEntryAnimation() async {
    await Future.delayed(const Duration(milliseconds: 300));
    _fadeController.forward();
    await Future.delayed(const Duration(milliseconds: 200));
    _slideController.forward();
    await Future.delayed(const Duration(milliseconds: 100));
    _scaleController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _scaleController.dispose();
    _buttonController.dispose();
    _errorController.dispose();
    super.dispose();
  }

  Future<void> debugSharedPreferences(String location) async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('email');
    final name = prefs.getString('name');
    final role = prefs.getString('role');
    final isStaff = prefs.getBool('isStaff');
    final year = prefs.getString("year");
    final sec = prefs.getString("sec");

    print(
      'DEBUG [$location]: email=$email, name=$name, role=$role, isStaff=$isStaff, year=$year, sec=$sec',
    );
  }

  Future<void> _checkLoginStatus() async {
    await debugSharedPreferences('_checkLoginStatus start');
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

  // --- UPDATED LOGIN ---
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

    print(
      'Login attempt: email=$email, role=$selectedRole, department=$selectedDepartment',
    );

    if (email.isNotEmpty && password.isNotEmpty) {
      try {
        // 🔥 NEW: Use API instead of MongoDB
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
          print('User found: $user');

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

          // ✅ Store year & section for USER
          if (selectedRole == 'user') {
            final year = user['year'] ?? '';
            final section = user['sec'] ?? '';
            await prefs.setString('year', year);
            await prefs.setString('sec', section);
            print('DEBUG [Login]: Stored USER year=$year, sec=$section');
          }

          // ✅ Store year & section for STAFF
          if (selectedRole == 'staff') {
            final year = user['year'] ?? '';
            final section = user['sec'] ?? '';
            await prefs.setString('year', year);
            await prefs.setString('sec', section);
            // Store staffName and inchargeName for forwarding
            final staffName = user['name'] ?? user['Name'] ?? '';
            final inchargeName = user['inchargeName'] ?? user['incharge'] ?? '';
            await prefs.setString('staffName', staffName);
            await prefs.setString('inchargeName', inchargeName);
            print(
              'DEBUG [Login]: Stored STAFF year=$year, sec=$section, staffName=$staffName, inchargeName=$inchargeName',
            );
          }

          await debugSharedPreferences('After saving to SharedPreferences');

          // Update FCM token for push notifications
          final userEmail = user["email"] ?? user["College Email"] ?? '';
          if (userEmail.isNotEmpty) {
            FirebaseApi().updateTokenForUser(userEmail).catchError((e) {
              print('Error updating FCM token: $e');
            });
          }

          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder:
                  (context, animation, _) => HomePage(
                    name: user["name"] ?? user["Name"] ?? '',
                    email: user["email"] ?? user["College Email"] ?? '',
                    profile: user,
                    isStaff: selectedRole == 'staff' || selectedRole == 'hod',
                    role: selectedRole,
                  ),
              transitionsBuilder: (context, animation, _, child) {
                return FadeTransition(opacity: animation, child: child);
              },
              transitionDuration: const Duration(milliseconds: 300),
            ),
          );
        } else {
          HapticFeedback.mediumImpact();
          _errorController.forward().then((_) => _errorController.reverse());
          setState(() {
            _errorMessage =
                result['message'] ??
                'Invalid credentials. Please check your email, password, role, and department.';
          });
        }
      } catch (e) {
        HapticFeedback.mediumImpact();
        _errorController.forward().then((_) => _errorController.reverse());
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to connect to the server.';
        });
        print('Login Error: $e');
      }
    } else {
      HapticFeedback.mediumImpact();
      _errorController.forward().then((_) => _errorController.reverse());
      setState(() {
        _isLoading = false;
        _errorMessage = 'Please fill in all fields.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
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
          child: AnimatedBuilder(
            animation: _fadeAnimation,
            builder: (context, child) {
              return FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: _buildFullPageLogin(),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildFullPageLogin() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Column(
                children: [
                  // Top section with logo and welcome
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ScaleTransition(
                          scale: _scaleAnimation,
                          child: _buildTopSection(),
                        ),
                      ],
                    ),
                  ),

                  // Main form section
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white,
                            Color(0xFFFAFBFF),
                            Colors.white,
                          ],
                          stops: [0.0, 0.5, 1.0],
                        ),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(32),
                          topRight: Radius.circular(32),
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
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildFormHeader(),
                            const SizedBox(height: 32),
                            _buildLoginForm(),
                          ],
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
    );
  }

  Widget _buildTopSection() {
    return Column(
      children: [
        // App logo with animated container
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.25),
                Colors.white.withOpacity(0.15),
              ],
            ),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: Colors.white.withOpacity(0.2),
                blurRadius: 30,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: const Icon(
            Icons.school_rounded,
            size: 50,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 24),

        // App name and tagline
        ShaderMask(
          shaderCallback:
              (bounds) => const LinearGradient(
                colors: [Colors.white, Color(0xFFE6F3FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ).createShader(bounds),
          child: const Text(
            'Attendanzy',
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -1,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Smart Attendance Management System',
          style: TextStyle(
            fontSize: 16,
            color: Colors.white.withOpacity(0.9),
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildFormHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Welcome Back!',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1a202c),
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Sign in to access your dashboard',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildLoginForm() {
    return Column(
      children: [
        _buildEnhancedTextField(
          controller: _emailController,
          hintText: 'College Email',
          icon: Icons.email_rounded,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 20),
        _buildEnhancedPasswordField(),
        const SizedBox(height: 20),
        _buildEnhancedDropdown(
          value: _selectedRoleIndex,
          items: _roles,
          label: 'Select Your Role',
          icon: Icons.person_rounded,
          onChanged: (value) {
            setState(() => _selectedRoleIndex = value);
            HapticFeedback.selectionClick();
          },
        ),
        const SizedBox(height: 20),
        _buildEnhancedDropdown(
          value: _selectedDepartmentIndex,
          items: _departments,
          label: 'Select Department',
          icon: Icons.school_rounded,
          onChanged: (value) {
            setState(() => _selectedDepartmentIndex = value);
            HapticFeedback.selectionClick();
          },
        ),
        const SizedBox(height: 20),
        _buildEnhancedErrorMessage(),
        const SizedBox(height: 32),
        _buildEnhancedLoginButton(),
        const SizedBox(height: 24),
        _buildFooterText(),
      ],
    );
  }

  Widget _buildEnhancedTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFF8FAFC),
            const Color(0xFFFFFFFF),
            const Color(0xFFF8FAFC),
          ],
          stops: [0.0, 0.5, 1.0],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: const Color(0xFF667eea).withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Color(0xFF1a202c),
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(
            color: Colors.grey[500],
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF667eea).withOpacity(0.1),
                  const Color(0xFF764ba2).withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFF667eea).withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Icon(icon, color: const Color(0xFF667eea), size: 20),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 20,
          ),
        ),
        onChanged: (value) => HapticFeedback.selectionClick(),
      ),
    );
  }

  Widget _buildEnhancedPasswordField() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFF8FAFC),
            const Color(0xFFFFFFFF),
            const Color(0xFFF8FAFC),
          ],
          stops: [0.0, 0.5, 1.0],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: const Color(0xFF667eea).withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: TextField(
        controller: _passwordController,
        obscureText: !_isPasswordVisible,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Color(0xFF1a202c),
        ),
        decoration: InputDecoration(
          hintText: 'Password',
          hintStyle: TextStyle(
            color: Colors.grey[500],
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF667eea).withOpacity(0.1),
                  const Color(0xFF764ba2).withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFF667eea).withOpacity(0.2),
                width: 1,
              ),
            ),
            child: const Icon(
              Icons.lock_outline_rounded,
              color: Color(0xFF667eea),
              size: 20,
            ),
          ),
          suffixIcon: IconButton(
            icon: Icon(
              _isPasswordVisible
                  ? Icons.visibility_rounded
                  : Icons.visibility_off_rounded,
              color: const Color(0xFF64748B),
              size: 20,
            ),
            onPressed: () {
              setState(() => _isPasswordVisible = !_isPasswordVisible);
              HapticFeedback.lightImpact();
            },
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 20,
          ),
        ),
        onChanged: (value) => HapticFeedback.selectionClick(),
      ),
    );
  }

  Widget _buildEnhancedDropdown({
    required int value,
    required List<String> items,
    required String label,
    required IconData icon,
    required ValueChanged<int> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFF8FAFC),
            const Color(0xFFFFFFFF),
            const Color(0xFFF8FAFC),
          ],
          stops: [0.0, 0.5, 1.0],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: const Color(0xFF667eea).withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<int>(
            value: value,
            hint: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF667eea).withOpacity(0.1),
                        const Color(0xFF764ba2).withOpacity(0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF667eea).withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Icon(icon, color: const Color(0xFF667eea), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontWeight: FontWeight.w400,
                      fontSize: 16,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Color(0xFF1a202c),
            ),
            icon: const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Color(0xFF667eea),
              size: 24,
            ),
            borderRadius: BorderRadius.circular(8),
            dropdownColor: Colors.white,
            selectedItemBuilder: (BuildContext context) {
              return items.map<Widget>((String item) {
                return Container(
                  alignment: Alignment.centerLeft,
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Row(
                    children: [
                      Icon(icon, color: const Color(0xFF667eea), size: 18),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          item,
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                            color: Color(0xFF1a202c),
                            height: 1.3,
                          ),
                          softWrap: true,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList();
            },
            items: List.generate(
              items.length,
              (index) => DropdownMenuItem<int>(
                value: index,
                child: Container(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(icon, color: const Color(0xFF64748B), size: 18),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          items[index],
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                            height: 1.3,
                          ),
                          softWrap: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            onChanged: (newValue) {
              if (newValue != null) {
                onChanged(newValue);
              }
            },
            isExpanded: true,
          ),
        ),
      ),
    );
  }

  Widget _buildEnhancedErrorMessage() {
    if (_errorMessage.isEmpty) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _errorShakeAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(
            8 * _errorShakeAnimation.value * (1 - _errorShakeAnimation.value),
            0,
          ),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFECACA), width: 1),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: Color(0xFFDC2626),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _errorMessage,
                    style: const TextStyle(
                      color: Color(0xFFDC2626),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
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

  Widget _buildEnhancedLoginButton() {
    return AnimatedBuilder(
      animation: _buttonScaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _buttonScaleAnimation.value,
          child: Container(
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors:
                    _isLoading
                        ? [const Color(0xFF9CA3AF), const Color(0xFF6B7280)]
                        : [
                          const Color(0xFF667eea),
                          const Color(0xFF764ba2),
                          const Color(0xFFf093fb),
                        ],
                stops: _isLoading ? null : [0.0, 0.5, 1.0],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                if (!_isLoading)
                  BoxShadow(
                    color: const Color(0xFF667eea).withOpacity(0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                if (!_isLoading)
                  BoxShadow(
                    color: const Color(0xFF764ba2).withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 4),
                  ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap:
                    _isLoading
                        ? null
                        : () {
                          _buttonController.forward().then((_) {
                            _buttonController.reverse();
                            _login();
                          });
                        },
                child: Center(
                  child:
                      _isLoading
                          ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                          : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.login_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Sign in as ${_roles[_selectedRoleIndex]}',
                                style: const TextStyle(
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
          ),
        );
      },
    );
  }

  Widget _buildFooterText() {
    return Center(
      child: Text(
        'Secure login powered by Attendanzy',
        style: TextStyle(
          fontSize: 14,
          color: Colors.grey[500],
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
