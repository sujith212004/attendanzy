import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import '../../../../core/services/api_service.dart';

class ResetPasswordPage extends StatefulWidget {
  final String email;
  final String role;

  const ResetPasswordPage({super.key, required this.email, required this.role});

  @override
  _ResetPasswordPageState createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  String _errorMessage = '';
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  // Colors - Professional Slate & Indigo Palette
  static const Color primaryBlue = Color(0xFF4F46E5);
  static const Color surfaceColor = Color(0xFFFFFFFF);
  static const Color backgroundColor = Color(0xFFF8FAFC);
  static const Color textDark = Color(0xFF0F172A);
  static const Color textMuted = Color(0xFF64748B);

  void _resetPassword() async {
    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() => _errorMessage = 'Passwords do not match');
      HapticFeedback.heavyImpact();
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final result = await ApiService.resetPassword(
        email: widget.email,
        role: widget.role,
        otp: _otpController.text.trim(),
        newPassword: _passwordController.text.trim(),
      );

      setState(() => _isLoading = false);

      if (result['success']) {
        HapticFeedback.mediumImpact();
        if (mounted) {
          _showStatusSnackBar('Password reset successfully!', true);
          Navigator.popUntil(context, (route) => route.isFirst);
        }
      } else {
        setState(() => _errorMessage = result['message'] ?? 'Invalid code or password');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Service unavailable. Try again later.';
      });
    }
  }

  void _showStatusSnackBar(String message, bool isSuccess) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.w500)),
        backgroundColor: isSuccess ? const Color(0xFF10B981) : const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: CustomScrollView(
        slivers: [
          // 1. Modern Slim AppBar
          SliverAppBar(
            expandedHeight: 0,
            backgroundColor: backgroundColor,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.chevron_left_rounded, color: textDark, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
            pinned: true,
          ),

          // 2. Form Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  // Headline Section
                  const Text(
                    "Reset Password",
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: textDark,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(fontSize: 15, color: textMuted, height: 1.5),
                      children: [
                        const TextSpan(text: "We've sent a 6-digit verification code to "),
                        TextSpan(
                          text: widget.email,
                          style: const TextStyle(color: primaryBlue, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Fields Section
                  _buildInputLabel("Verification Code"),
                  _buildModernField(
                    controller: _otpController,
                    hint: "000000",
                    icon: Icons.numbers_rounded,
                    isOtp: true,
                  ),
                  const SizedBox(height: 24),

                  _buildInputLabel("New Password"),
                  _buildModernField(
                    controller: _passwordController,
                    hint: "••••••••",
                    icon: Icons.lock_outline_rounded,
                    isPassword: true,
                    isVisible: _isPasswordVisible,
                    onToggle: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                  ),
                  const SizedBox(height: 24),

                  _buildInputLabel("Confirm Password"),
                  _buildModernField(
                    controller: _confirmPasswordController,
                    hint: "••••••••",
                    icon: Icons.shield_outlined,
                    isPassword: true,
                    isVisible: _isConfirmPasswordVisible,
                    onToggle: () => setState(() => _isConfirmPasswordVisible = !_isConfirmPasswordVisible),
                  ),

                  if (_errorMessage.isNotEmpty) _buildErrorContainer(),

                  const SizedBox(height: 48),

                  // Action Button
                  _buildSubmitButton(),
                  
                  const SizedBox(height: 24),
                  Center(
                    child: TextButton(
                      onPressed: () { /* Resend logic */ },
                      child: const Text(
                        "Resend Code",
                        style: TextStyle(color: textMuted, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        label,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textDark),
      ),
    );
  }

  Widget _buildModernField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    bool isVisible = false,
    bool isOtp = false,
    VoidCallback? onToggle,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword && !isVisible,
        keyboardType: isOtp ? TextInputType.number : TextInputType.text,
        inputFormatters: isOtp ? [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)] : [],
        style: const TextStyle(fontWeight: FontWeight.w600, color: textDark),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: textMuted.withOpacity(0.4)),
          prefixIcon: Icon(icon, color: primaryBlue, size: 22),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(isVisible ? Icons.visibility_off : Icons.visibility, color: textMuted, size: 20),
                  onPressed: onToggle,
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: primaryBlue, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
        ),
      ),
    );
  }

  Widget _buildErrorContainer() {
    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFEE2E2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMessage,
              style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _resetPassword,
        style: ElevatedButton.styleFrom(
          backgroundColor: textDark,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
            : const Text(
                "Update Password",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
      ),
    );
  }
}