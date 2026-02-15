import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/services/api_service.dart';
import 'reset_password_page.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  _ForgotPasswordPageState createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage>
    with TickerProviderStateMixin {
  final TextEditingController _emailController = TextEditingController();
  final List<String> _roles = ['User', 'Staff', 'HOD'];
  String _selectedRole = 'User';
  bool _isLoading = false;
  String _errorMessage = '';

  late AnimationController _orbController;
  late AnimationController _staggerController;
  final List<Animation<double>> _staggerAnimations = [];

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

    _initStaggerAnimations();

    // Start entrance animation after a slight delay
    Future.delayed(const Duration(milliseconds: 200), () {
      _staggerController.forward();
    });
  }

  void _initStaggerAnimations() {
    for (int i = 0; i < 4; i++) {
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
    _emailController.dispose();
    super.dispose();
  }

  void _sendOTP() async {
    if (_emailController.text.isEmpty) {
      setState(() => _errorMessage = 'Please enter your email address');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final result = await ApiService.forgotPassword(
        email: _emailController.text.trim(),
        role: _selectedRole.toLowerCase(),
      );

      setState(() => _isLoading = false);

      if (result['success']) {
        HapticFeedback.heavyImpact();
        if (mounted) {
          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder:
                  (_, a, __) => ResetPasswordPage(
                    email: _emailController.text.trim(),
                    role: _selectedRole.toLowerCase(),
                  ),
              transitionsBuilder:
                  (_, a, __, c) => FadeTransition(opacity: a, child: c),
            ),
          );
        }
      } else {
        HapticFeedback.mediumImpact();
        setState(() {
          _errorMessage = result['message'] ?? 'Failed to send OTP';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'An error occurred. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Color(0xFF0F172A),
              size: 18,
            ),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
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
                                    keyboardType: TextInputType.emailAddress,
                                  ),
                                  const SizedBox(height: 20),
                                  _buildModernDropdown(
                                    value: _selectedRole,
                                    items: _roles,
                                    hint: "Account Role",
                                    onChanged:
                                        (val) =>
                                            setState(() => _selectedRole = val),
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
                                  const SizedBox(height: 32),
                                  _buildSubmitButton(),
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
                        "SECURE RECOVERY",
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
    // Avoid range error if index exceeds animations length
    if (index >= _staggerAnimations.length) return child;

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
            Icons.lock_reset_rounded,
            color: Color(0xFF4F46E5),
            size: 42,
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          "Password Recovery",
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w900,
            color: Color(0xFF0F172A),
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Enter email to receive security code",
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
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.6)),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
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

  Widget _buildModernDropdown({
    required String value,
    required List<String> items,
    required String hint,
    required ValueChanged<String> onChanged,
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
        child: DropdownButton<String>(
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
          items:
              items.map((String item) {
                return DropdownMenuItem<String>(
                  value: item,
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: (value == item
                                      ? const Color(0xFF6366F1)
                                      : const Color(0xFFCBD5E1))
                                  .withOpacity(0.5),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                          color:
                              value == item
                                  ? const Color(0xFF6366F1)
                                  : const Color(0xFFCBD5E1),
                        ),
                      ),
                      const SizedBox(width: 12),

                      Expanded(
                        child: Text(
                          item,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color:
                                value == item
                                    ? const Color(0xFF4F46E5)
                                    : const Color(0xFF0F172A),
                            fontWeight:
                                value == item
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
          onChanged: (val) {
            if (val != null) onChanged(val);
          },
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return InkWell(
      onTap: _isLoading ? null : _sendOTP,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 56,
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
        alignment: Alignment.center,
        child:
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
                  "Send Reset Link",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
      ),
    );
  }
}
