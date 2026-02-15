import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:ui';

/// Vibrant Kinetic ERP Splash Animation
///
/// Features:
/// - "Pearlescent White" Background (Subtle multicolored aura)
/// - Vibrant Gradient Modules (Blue, Red, Orange, Green, Purple)
/// - "Breathing" Kinetic Nodes (Pulse animation)
/// - "Trail" Data Packets (High speed feel)
class MinimalSplashAnimation extends StatefulWidget {
  final VoidCallback onComplete;
  final Duration duration;

  const MinimalSplashAnimation({
    Key? key,
    required this.onComplete,
    this.duration = const Duration(seconds: 6),
  }) : super(key: key);

  @override
  State<MinimalSplashAnimation> createState() => _MinimalSplashAnimationState();
}

class _MinimalSplashAnimationState extends State<MinimalSplashAnimation>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _pulseController;
  late AnimationController _orbitController;

  @override
  void initState() {
    super.initState();

    _mainController = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _orbitController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat();

    _mainController.forward().then((_) {
      if (mounted) widget.onComplete();
    });
  }

  @override
  void dispose() {
    _mainController.dispose();
    _pulseController.dispose();
    _orbitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.white,
      body: AnimatedBuilder(
        animation: Listenable.merge([
          _mainController,
          _pulseController,
          _orbitController,
        ]),
        builder: (context, child) {
          final progress = _mainController.value;
          final pulse = _pulseController.value;
          final orbit = _orbitController.value;

          return Stack(
            fit: StackFit.expand,
            children: [
              // 1. Pearlescent Background (Subtle moving colors)
              _buildPearlescentBackground(orbit),

              // 2. Kinetic Ecosystem (Vibrant Nodes)
              _buildVibrantEcosystem(progress, orbit, pulse, size),

              // 3. Center Hub (Logo)
              _buildCentralHub(progress, pulse),

              // 4. Professional Branding
              _buildBranding(progress, size),

              // 5. Clean Exit
              if (progress > 0.94) _buildFadeOut(progress),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPearlescentBackground(double time) {
    // Subtle multicolored gradients moving slowly
    return Stack(
      children: [
        Container(color: Colors.white),
        Positioned(
          top: -100,
          left: -100,
          child: _AuraSpot(color: Colors.blue.withOpacity(0.08), size: 400),
        ),
        Positioned(
          bottom: -100,
          right: -100,
          child: _AuraSpot(color: Colors.purple.withOpacity(0.08), size: 400),
        ),
        Align(
          alignment: Alignment(
            math.sin(time * 2 * math.pi),
            math.cos(time * 2 * math.pi),
          ),
          child: _AuraSpot(color: Colors.teal.withOpacity(0.05), size: 600),
        ),
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
          child: Container(color: Colors.white.withOpacity(0.4)),
        ),
      ],
    );
  }

  Widget _buildVibrantEcosystem(
    double progress,
    double orbit,
    double pulse,
    Size size,
  ) {
    if (progress > 0.85) return const SizedBox.shrink();

    // Vibrant Modules
    final modules = [
      _Module("ATTENDANCE", Icons.qr_code_scanner, [
        const Color(0xFF3B82F6),
        const Color(0xFF2563EB),
      ]), // Blue
      _Module("EXAMS", Icons.quiz_outlined, [
        const Color(0xFFEF4444),
        const Color(0xFFDC2626),
      ]), // Red
      _Module("LIBRARY", Icons.menu_book_rounded, [
        const Color(0xFFF59E0B),
        const Color(0xFFD97706),
      ]), // Amber
      _Module("FINANCE", Icons.account_balance_wallet_outlined, [
        const Color(0xFF10B981),
        const Color(0xFF059669),
      ]), // Emerald
      _Module("TRANSPORT", Icons.directions_bus_filled_outlined, [
        const Color(0xFF8B5CF6),
        const Color(0xFF7C3AED),
      ]), // Violet
      _Module("HOSTEL", Icons.apartment_rounded, [
        const Color(0xFFEC4899),
        const Color(0xFFDB2777),
      ]), // Pink
    ];

    final radius = size.width * 0.38; // Slightly larger spread
    final center = Offset(size.width / 2, size.height / 2 - 50);

    return Stack(
      children: [
        // Connecting Lines & Trail Packets
        CustomPaint(
          size: size,
          painter: _KineticConnectivityPainter(
            modules: modules.length,
            rotation: orbit,
            radius: radius,
            center: center,
            progress: progress,
          ),
        ),

        // Orbiting Vibrant Nodes
        ...List.generate(modules.length, (index) {
          final angle =
              (2 * math.pi * index / modules.length) + (orbit * 2 * math.pi);
          final x = center.dx + radius * math.cos(angle);
          final y = center.dy + radius * math.sin(angle);

          final entrance = Curves.easeOutBack.transform(
            ((progress - 0.2) * 2).clamp(0.0, 1.0),
          );
          // Pulse breathing effect
          final breathe = 1.0 + (math.sin(pulse * math.pi * 2 + index) * 0.05);
          final scale = entrance.clamp(0.0, 1.0) * breathe;

          return Positioned(
            left: x - 30, // Center the 60px widget
            top: y - 30,
            child: Transform.scale(
              scale: scale,
              child: _VibrantNode(module: modules[index]),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildCentralHub(double progress, double pulse) {
    if (progress > 0.8) return const SizedBox.shrink();

    final entrance = Curves.easeOutBack.transform(
      (progress * 2.0).clamp(0.0, 1.0),
    );
    final breathe = 1.0 + (math.sin(pulse * math.pi * 2) * 0.02);
    final scale = entrance * breathe;

    return Center(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 100),
        child: Transform.scale(
          scale: scale,
          child: Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 40,
                  spreadRadius: 10,
                ),
                BoxShadow(
                  color: Colors.blue.withOpacity(0.1),
                  blurRadius: 20,
                  spreadRadius: -5,
                ),
              ],
            ),
            padding: const EdgeInsets.all(22),
            child: ClipOval(
              child: Image.asset('assets/icon/icon.png', fit: BoxFit.cover),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBranding(double progress, Size size) {
    if (progress < 0.2) return const SizedBox.shrink();

    final entrance = Curves.easeOutCubic.transform(
      ((progress - 0.2) * 1.5).clamp(0.0, 1.0),
    );
    final exit = ((progress - 0.94) * 10).clamp(0.0, 1.0);
    final opacity = (entrance * (1.0 - exit)).clamp(0.0, 1.0);

    return Positioned(
      bottom: size.height * 0.1,
      left: 0,
      right: 0,
      child: Opacity(
        opacity: opacity,
        child: Column(
          children: [
            ShaderMask(
              shaderCallback:
                  (bounds) => const LinearGradient(
                    colors: [
                      Color(0xFF1E3A8A),
                      Color(0xFF2563EB),
                      Color(0xFF1E3A8A),
                    ],
                  ).createShader(bounds),
              child: const Text(
                "ATTENDANZY",
                style: TextStyle(
                  fontSize: 38,
                  fontWeight: FontWeight.w900,
                  color: Colors.white, // Masked
                  letterSpacing: -1.0,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                "THE CAMPUS ECOSYSTEM",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF64748B),
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFadeOut(double progress) {
    return Container(
      color: Colors.white.withOpacity(
        ((progress - 0.94) / 0.06).clamp(0.0, 1.0),
      ),
    );
  }
}

// --- Components & Painters ---

class _Module {
  final String label;
  final IconData icon;
  final List<Color> gradient;
  _Module(this.label, this.icon, this.gradient);
}

class _AuraSpot extends StatelessWidget {
  final Color color;
  final double size;
  const _AuraSpot({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withOpacity(0)],
          stops: const [0.2, 1.0],
        ),
      ),
    );
  }
}

class _VibrantNode extends StatelessWidget {
  final _Module module;
  const _VibrantNode({required this.module});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: module.gradient,
            ),
            boxShadow: [
              BoxShadow(
                color: module.gradient.first.withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Icon(module.icon, color: Colors.white, size: 28),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            module.label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: module.gradient.last, // Match branding color
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _KineticConnectivityPainter extends CustomPainter {
  final int modules;
  final double rotation, radius, progress;
  final Offset center;

  _KineticConnectivityPainter({
    required this.modules,
    required this.rotation,
    required this.radius,
    required this.center,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint =
        Paint()
          ..color = const Color(0xFFCBD5E1) // Slate 300
          ..strokeWidth =
              1.5 // Thicker
          ..style = PaintingStyle.stroke;

    for (int i = 0; i < modules; i++) {
      final angle = (2 * math.pi * i / modules) + (rotation * 2 * math.pi);
      final endX = center.dx + radius * math.cos(angle);
      final endY = center.dy + radius * math.sin(angle);
      final endPoint = Offset(endX, endY);

      // Draw connecting line
      if (progress > 0.3) {
        final lineProgress = ((progress - 0.3) * 2).clamp(0.0, 1.0);
        final currentEnd = Offset.lerp(center, endPoint, lineProgress)!;
        canvas.drawLine(center, currentEnd, linePaint);
      }

      // Draw Kinetic Data Trail
      if (progress > 0.4) {
        final dataT = (rotation * 3 + i * 0.4) % 1.0; // Loop 0-1
        final pos = Offset.lerp(center, endPoint, dataT)!;

        // Trail Effect
        for (int j = 0; j < 5; j++) {
          final trailPos =
              Offset.lerp(
                center,
                endPoint,
                (dataT - j * 0.02).clamp(0.0, 1.0),
              )!;
          final trailPaint =
              Paint()
                ..color = const Color(0xFF3B82F6).withOpacity(1.0 - j * 0.2)
                ..style = PaintingStyle.fill;
          canvas.drawCircle(trailPos, 3.0 - j * 0.5, trailPaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
