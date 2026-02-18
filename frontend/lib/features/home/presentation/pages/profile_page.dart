import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import '../../../auth/presentation/pages/changepassword.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../main.dart';

class ProfilePage extends StatefulWidget {
  final String name;
  final String email;
  final String year;
  final String department;
  final String section;

  const ProfilePage({
    super.key,
    required this.name,
    required this.email,
    required this.year,
    required this.department,
    required this.section,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with TickerProviderStateMixin {
  bool _isLoggingOut = false;

  late AnimationController _orbController;
  late AnimationController _staggerController;
  late AnimationController _shimmerController;
  final List<Animation<double>> _staggerAnimations = [];

  @override
  void initState() {
    super.initState();

    _orbController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat(reverse: true);

    _staggerController = AnimationController(
      duration: const Duration(milliseconds: 1100),
      vsync: this,
    );

    _shimmerController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();

    // 6 staggered sections
    for (int i = 0; i < 6; i++) {
      _staggerAnimations.add(
        CurvedAnimation(
          parent: _staggerController,
          curve: Interval(
            0.08 * i,
            0.55 + (0.08 * i),
            curve: Curves.easeOutCubic,
          ),
        ),
      );
    }

    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _staggerController.forward();
    });
  }

  @override
  void dispose() {
    _orbController.dispose();
    _staggerController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    HapticFeedback.mediumImpact();
    setState(() => _isLoggingOut = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    myAppKey.currentState?.restartApp(false);
    navigatorKey.currentState?.pushNamedAndRemoveUntil(
      '/loginpage',
      (route) => false,
    );
  }

  String get _initials {
    final parts = widget.name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return widget.name.isNotEmpty ? widget.name[0].toUpperCase() : '?';
  }

  Widget _staggered(int index, Widget child) {
    return AnimatedBuilder(
      animation: _staggerController,
      builder: (context, child) {
        final anim = _staggerAnimations[index];
        return Transform.translate(
          offset: Offset(0, 40 * (1 - anim.value)),
          child: Opacity(opacity: anim.value.clamp(0.0, 1.0), child: child),
        );
      },
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Animated orbs
            _buildAnimatedOrbs(),

            SafeArea(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                child: Column(
                  children: [
                    _staggered(0, _buildTopBar(context)),
                    const SizedBox(height: 28),
                    _staggered(1, _buildAvatarHero()),
                    const SizedBox(height: 28),
                    _staggered(2, _buildStatsCard()),
                    const SizedBox(height: 16),
                    _staggered(3, _buildInfoCard()),
                    const SizedBox(height: 16),
                    _staggered(4, _buildSettingsCard(context)),
                    const SizedBox(height: 28),
                    _staggered(5, _buildSignOutButton()),
                    const SizedBox(height: 24),
                    Text(
                      'ATTENDANZY © 2026',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 11,
                        letterSpacing: 2.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Animated orbs ─────────────────────────────────────────────────────────

  Widget _buildAnimatedOrbs() {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _orbController,
        builder: (context, _) {
          return Stack(
            children: [
              Positioned(
                top: -100 + (_orbController.value * 60),
                right: -60,
                child: _Orb(
                  size: 420,
                  colors: [
                    const Color(0xFF7C3AED).withOpacity(0.30),
                    const Color(0xFFC4B5FD).withOpacity(0.12),
                    Colors.transparent,
                  ],
                ),
              ),
              Positioned(
                bottom: -80 - (_orbController.value * 50),
                left: -100,
                child: _Orb(
                  size: 480,
                  colors: [
                    const Color(0xFF0EA5E9).withOpacity(0.25),
                    const Color(0xFF38BDF8).withOpacity(0.12),
                    Colors.transparent,
                  ],
                ),
              ),
              Positioned(
                top: 60,
                left: -60 + (_orbController.value * 30),
                child: _Orb(
                  size: 300,
                  colors: [
                    const Color(0xFFFB7185).withOpacity(0.18),
                    Colors.transparent,
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Top bar ───────────────────────────────────────────────────────────────

  Widget _buildTopBar(BuildContext context) {
    return Row(
      children: [
        _GlassIconButton(
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.of(context).pop();
          },
          icon: Icons.arrow_back_ios_new_rounded,
        ),
        const Expanded(
          child: Text(
            'My Profile',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
              letterSpacing: -0.4,
            ),
          ),
        ),
        const SizedBox(width: 44),
      ],
    );
  }

  // ── Avatar hero ───────────────────────────────────────────────────────────

  Widget _buildAvatarHero() {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8B5CF6).withOpacity(0.22),
                    blurRadius: 36,
                    spreadRadius: 4,
                  ),
                ],
              ),
            ),
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFEDE9FE), Color(0xFFBAE6FD)],
                ),
                border: Border.all(color: Colors.white, width: 4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.10),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  _initials,
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF4F46E5),
                    letterSpacing: -1,
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 4,
              right: 4,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF22C55E).withOpacity(0.4),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 18),

        Text(
          widget.name,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: Color(0xFF0F172A),
            letterSpacing: -0.8,
            height: 1.1,
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 8),

        Text(
          widget.email,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 12),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF4F46E5).withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFF4F46E5).withOpacity(0.18),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: Color(0xFF22C55E),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 7),
              const Text(
                'Student · Active',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF4F46E5),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Stats glass card ──────────────────────────────────────────────────────

  Widget _buildStatsCard() {
    return _GlassCard(
      child: Row(
        children: [
          _buildStatItem(
            label: 'Department',
            value: widget.department,
            icon: Icons.school_rounded,
            color: const Color(0xFF6366F1),
          ),
          _buildVerticalDivider(),
          _buildStatItem(
            label: 'Year',
            value: widget.year,
            icon: Icons.calendar_month_rounded,
            color: const Color(0xFFEC4899),
          ),
          _buildVerticalDivider(),
          _buildStatItem(
            label: 'Section',
            value: widget.section,
            icon: Icons.groups_2_rounded,
            color: const Color(0xFF10B981),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
                letterSpacing: -0.3,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF94A3B8),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerticalDivider() {
    return Container(width: 1, height: 52, color: const Color(0xFFE2E8F0));
  }

  // ── Account info card ─────────────────────────────────────────────────────

  Widget _buildInfoCard() {
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel(
            label: 'Account Info',
            icon: Icons.person_outline_rounded,
          ),
          const SizedBox(height: 4),
          _DetailRow(
            icon: Icons.badge_rounded,
            label: 'Role',
            value: 'Student',
            iconColor: const Color(0xFF6366F1),
          ),
          const _RowDivider(),
          _DetailRow(
            icon: Icons.verified_rounded,
            label: 'Status',
            value: 'Active',
            iconColor: const Color(0xFF10B981),
            valueColor: const Color(0xFF10B981),
          ),
        ],
      ),
    );
  }

  // ── Settings card ─────────────────────────────────────────────────────────

  Widget _buildSettingsCard(BuildContext context) {
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel(label: 'Settings', icon: Icons.tune_rounded),
          const SizedBox(height: 4),
          _TappableRow(
            icon: Icons.lock_reset_rounded,
            label: 'Change Password',
            subtitle: 'Update your security credentials',
            iconColor: const Color(0xFF0EA5E9),
            onTap: () {
              HapticFeedback.selectionClick();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (_) =>
                          ChangePasswordPage(email: widget.email, role: 'user'),
                ),
              );
            },
          ),
          const _RowDivider(),
          _TappableRow(
            icon: Icons.notifications_active_outlined,
            label: 'Notifications',
            subtitle: 'Manage alerts & reminders',
            iconColor: const Color(0xFFF59E0B),
            onTap: () => HapticFeedback.selectionClick(),
          ),
        ],
      ),
    );
  }

  // ── Sign out button ───────────────────────────────────────────────────────

  Widget _buildSignOutButton() {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        return GestureDetector(
          onTap: _isLoggingOut ? null : _logout,
          child: Container(
            width: double.infinity,
            height: 56,
            clipBehavior: Clip.hardEdge,
            decoration: BoxDecoration(
              gradient:
                  _isLoggingOut
                      ? null
                      : const LinearGradient(
                        colors: [Color(0xFF1E293B), Color(0xFF020617)],
                      ),
              color: _isLoggingOut ? const Color(0xFFF1F5F9) : null,
              borderRadius: BorderRadius.circular(16),
              boxShadow:
                  _isLoggingOut
                      ? null
                      : [
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
                if (!_isLoggingOut)
                  Positioned.fill(
                    child: FractionallySizedBox(
                      widthFactor: 0.3,
                      child: Transform.translate(
                        offset: Offset(
                          -200 + (600 * _shimmerController.value),
                          0,
                        ),
                        child: Transform.rotate(
                          angle: 0.4,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  Colors.white.withOpacity(0.12),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                _isLoggingOut
                    ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF64748B),
                      ),
                    )
                    : const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.logout_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Sign Out',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── Shared Components ───────────────────────────────────────────────────────

class _Orb extends StatelessWidget {
  final double size;
  final List<Color> colors;
  const _Orb({required this.size, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: colors, radius: 0.65),
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  final VoidCallback onTap;
  final IconData icon;
  const _GlassIconButton({required this.onTap, required this.icon});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.6),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withOpacity(0.7),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF64748B).withOpacity(0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: const Color(0xFF0F172A), size: 18),
          ),
        ),
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.82),
                Colors.white.withOpacity(0.55),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withOpacity(0.65),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF64748B).withOpacity(0.09),
                blurRadius: 32,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final IconData icon;
  const _SectionLabel({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 15, color: const Color(0xFF94A3B8)),
          const SizedBox(width: 7),
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF94A3B8),
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();
  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      color: const Color(0xFFE2E8F0).withOpacity(0.8),
      indent: 46,
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color iconColor;
  final Color? valueColor;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.iconColor,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 17, color: iconColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF94A3B8),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    color: valueColor ?? const Color(0xFF0F172A),
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
}

class _TappableRow extends StatefulWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color iconColor;
  final VoidCallback onTap;

  const _TappableRow({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.iconColor,
    required this.onTap,
  });

  @override
  State<_TappableRow> createState() => _TappableRowState();
}

class _TappableRowState extends State<_TappableRow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color:
              _pressed
                  ? const Color(0xFF4F46E5).withOpacity(0.04)
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: widget.iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(widget.icon, size: 17, color: widget.iconColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.label,
                    style: const TextStyle(
                      fontSize: 15,
                      color: Color(0xFF0F172A),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF94A3B8),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.6),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
              ),
              child: const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF94A3B8),
                size: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
