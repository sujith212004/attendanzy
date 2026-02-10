import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:ui';

/// Cinematic Ultra-Smooth Splash Animation
///
/// Features buttery-smooth 60fps animations with:
/// - Fluid morphing transitions
/// - Cinematic easing curves
/// - Realistic depth & lighting
/// - Organic micro-movements

class MinimalSplashAnimation extends StatefulWidget {
  final VoidCallback onComplete;
  final Duration duration;

  const MinimalSplashAnimation({
    Key? key,
    required this.onComplete,
    this.duration = const Duration(milliseconds: 4500),
  }) : super(key: key);

  @override
  State<MinimalSplashAnimation> createState() => _MinimalSplashAnimationState();
}

class _MinimalSplashAnimationState extends State<MinimalSplashAnimation>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _flowController;
  late AnimationController _glowController;

  final List<_FloatingOrb> _orbs = [];

  @override
  void initState() {
    super.initState();

    final random = math.Random(42);

    // Create organic floating orbs
    for (int i = 0; i < 5; i++) {
      _orbs.add(
        _FloatingOrb(
          baseX: random.nextDouble() * 0.8 + 0.1,
          baseY: random.nextDouble() * 0.8 + 0.1,
          size: random.nextDouble() * 120 + 80,
          color: _getOrbColor(i),
          phaseOffset: random.nextDouble() * math.pi * 2,
          speed: random.nextDouble() * 0.3 + 0.2,
        ),
      );
    }

    _mainController = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _flowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat(reverse: true);

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();

    _mainController.forward().then((_) {
      if (mounted) widget.onComplete();
    });
  }

  Color _getOrbColor(int index) {
    const colors = [
      Color(0xFF8B5CF6), // Purple
      Color(0xFF06B6D4), // Cyan
      Color(0xFFF472B6), // Pink
      Color(0xFF10B981), // Green
      Color(0xFFF59E0B), // Amber
    ];
    return colors[index % colors.length];
  }

  @override
  void dispose() {
    _mainController.dispose();
    _flowController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  // Ultra-smooth clamping
  double _clamp(double v) => v <= 0.0 ? 0.0 : (v >= 1.0 ? 1.0 : v);

  // Quintic ease in-out for buttery smoothness
  double _easeInOutQuint(double x) {
    x = _clamp(x);
    return x < 0.5 ? 16 * x * x * x * x * x : 1 - math.pow(-2 * x + 2, 5) / 2;
  }

  // Smooth step (Hermite interpolation)
  double _smoothStep(double x) {
    x = _clamp(x);
    return x * x * (3.0 - 2.0 * x);
  }

  // Ken Perlin's smoother step
  double _smootherStep(double x) {
    x = _clamp(x);
    return x * x * x * (x * (x * 6.0 - 15.0) + 10.0);
  }

  // Soft elastic for gentle bounce
  double _softElastic(double x) {
    x = _clamp(x);
    if (x == 0 || x == 1) return x;
    return math.pow(2, -8 * x) *
            math.sin((x * 10 - 0.75) * ((2 * math.pi) / 3)) +
        1;
  }

  // Cinematic ease out
  double _cinematicOut(double x) {
    x = _clamp(x);
    return 1 - math.pow(1 - x, 4).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.white,
      body: AnimatedBuilder(
        animation: Listenable.merge([
          _mainController,
          _flowController,
          _glowController,
        ]),
        builder: (context, child) {
          final progress = _clamp(_mainController.value);
          final flow = _clamp(_flowController.value);
          final glow = _clamp(_glowController.value);

          return Container(
            width: size.width,
            height: size.height,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFFFFFFFE),
                  Color.lerp(
                    const Color(0xFFFAF5FF),
                    const Color(0xFFF0FDFA),
                    _smoothStep(flow),
                  )!,
                  const Color(0xFFFFFFFE),
                ],
              ),
            ),
            child: Stack(
              children: [
                // Ambient floating orbs
                _buildAmbientOrbs(progress, flow, size),

                // Soft light bloom
                _buildLightBloom(progress, flow, glow, size),

                // Feature cards
                _buildFeatureCards(progress, flow, size),

                // Central logo
                _buildLogo(progress, flow, glow),

                // App branding
                _buildBranding(progress, flow, size),

                // Smooth fade out
                _buildFadeOut(progress),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAmbientOrbs(double progress, double flow, Size size) {
    if (progress > 0.88) return const SizedBox.shrink();

    final fadeOut = _clamp(1.0 - (progress - 0.7) / 0.18);
    final opacity = _smoothStep(fadeOut) * 0.4;

    return Stack(
      children:
          _orbs.map((orb) {
            final time = flow * math.pi * 2 + orb.phaseOffset;
            final x = orb.baseX + math.sin(time * orb.speed) * 0.08;
            final y = orb.baseY + math.cos(time * orb.speed * 0.7) * 0.06;
            final scale = 1.0 + math.sin(time * 0.5) * 0.15;

            return Positioned(
              left: x * size.width - orb.size / 2,
              top: y * size.height - orb.size / 2,
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
                child: Container(
                  width: orb.size * scale,
                  height: orb.size * scale,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: orb.color.withOpacity(opacity),
                  ),
                ),
              ),
            );
          }).toList(),
    );
  }

  Widget _buildLightBloom(
    double progress,
    double flow,
    double glow,
    Size size,
  ) {
    if (progress > 0.85) return const SizedBox.shrink();

    final fadeOut = _clamp(1.0 - (progress - 0.6) / 0.25);
    final opacity = _smoothStep(fadeOut) * 0.25;
    final pulse = 1.0 + math.sin(glow * math.pi * 2) * 0.1;

    return Center(
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
        child: Container(
          width: 300 * pulse,
          height: 300 * pulse,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                const Color(0xFF8B5CF6).withOpacity(opacity),
                const Color(0xFF06B6D4).withOpacity(opacity * 0.5),
                Colors.transparent,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureCards(double progress, double flow, Size size) {
    if (progress > 0.70) return const SizedBox.shrink();

    final cardPhase = _clamp(progress / 0.65);

    final features = [
      _Feature(Icons.article_rounded, const Color(0xFF7C3AED), 'OD', -135.0),
      _Feature(
        Icons.event_available_rounded,
        const Color(0xFF0891B2),
        'Leave',
        -45.0,
      ),
      _Feature(
        Icons.fingerprint_rounded,
        const Color(0xFFDC2626),
        'Mark',
        135.0,
      ),
      _Feature(Icons.dashboard_rounded, const Color(0xFF059669), 'Table', 45.0),
    ];

    return Stack(
      alignment: Alignment.center,
      children: List.generate(features.length, (i) {
        final feature = features[i];

        // Staggered timing for each card
        final stagger = i * 0.06;
        final cardProg = _clamp((cardPhase - stagger) / (1.0 - stagger));

        // Smooth entrance and exit
        final entrancePhase = _clamp(cardProg / 0.35);
        final exitPhase = _clamp((cardProg - 0.65) / 0.35);

        final smoothEntrance = _easeInOutQuint(entrancePhase);
        final smoothExit = _smootherStep(exitPhase);

        // Distance animation
        final startDist = 280.0;
        final distanceMultiplier = 1.0 - smoothEntrance + (smoothExit * 0.8);
        final currentDist = startDist * distanceMultiplier;

        final angleRad = feature.angle * (math.pi / 180);
        final xPos = math.cos(angleRad) * currentDist;
        final yPos = math.sin(angleRad) * currentDist;

        // Scale with soft elastic on entrance
        double scale;
        if (cardProg < 0.35) {
          scale = _softElastic(entrancePhase);
        } else if (cardProg < 0.65) {
          scale = 1.0;
        } else {
          scale = 1.0 - (smoothExit * 0.6);
        }

        // Opacity with cinematic fade
        double opacity;
        if (cardProg < 0.25) {
          opacity = _cinematicOut(_clamp(cardProg / 0.25));
        } else if (cardProg < 0.60) {
          opacity = 1.0;
        } else {
          opacity = 1.0 - _smootherStep(exitPhase);
        }

        // Organic floating motion
        final time = flow * math.pi * 2;
        final floatY = math.sin(time + i * 1.5) * 10 * (1.0 - smoothEntrance);
        final floatX = math.cos(time * 0.8 + i) * 6 * (1.0 - smoothEntrance);

        // Subtle rotation
        final rotation = (1.0 - smoothEntrance) * (i.isEven ? 0.05 : -0.05);

        return Positioned(
          left: size.width / 2 + xPos + floatX - 46,
          top: size.height / 2 + yPos + floatY - 46,
          child: Transform.rotate(
            angle: rotation,
            child: Transform.scale(
              scale: scale,
              child: Opacity(
                opacity: _clamp(opacity),
                child: _buildCard(feature, flow),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildCard(_Feature feature, double flow) {
    return Container(
      width: 92,
      height: 92,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          // Soft ambient shadow
          BoxShadow(
            color: feature.color.withOpacity(0.12),
            blurRadius: 50,
            spreadRadius: -10,
            offset: const Offset(0, 25),
          ),
          // Medium shadow for depth
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
          // Contact shadow
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            // Gradient background
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.white, feature.color.withOpacity(0.04)],
                ),
              ),
            ),
            // Top shine
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 46,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withOpacity(0.95),
                      Colors.white.withOpacity(0.0),
                    ],
                  ),
                ),
              ),
            ),
            // Icon container
            Center(
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      feature.color,
                      Color.lerp(feature.color, Colors.black, 0.15)!,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: feature.color.withOpacity(0.45),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Icon(feature.icon, size: 28, color: Colors.white),
              ),
            ),
            // Subtle border
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.9),
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogo(double progress, double flow, double glow) {
    if (progress < 0.50) return const SizedBox.shrink();

    final logoPhase = _clamp((progress - 0.50) / 0.38);

    // Ultra-smooth entrance
    final entrancePhase = _clamp(logoPhase / 0.4);
    final smoothEntrance = _easeInOutQuint(entrancePhase);

    // Gentle elastic settle
    double scale;
    if (logoPhase < 0.4) {
      scale = _softElastic(entrancePhase) * 1.0;
    } else {
      scale = 1.0;
    }

    // Smooth breathing
    final breathe = 1.0 + math.sin(flow * math.pi * 2) * 0.008 * smoothEntrance;

    // Cinematic fade in
    final opacity = _cinematicOut(_clamp(logoPhase / 0.3));

    // Shimmer rotation
    final shimmerAngle = glow * math.pi * 2;

    return Center(
      child: Transform.scale(
        scale: scale * breathe,
        child: Opacity(
          opacity: _clamp(opacity),
          child: Container(
            width: 165,
            height: 165,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                // Colored glow
                BoxShadow(
                  color: const Color(0xFF8B5CF6).withOpacity(0.18 * opacity),
                  blurRadius: 100,
                  spreadRadius: 25,
                ),
                BoxShadow(
                  color: const Color(0xFF06B6D4).withOpacity(0.12 * opacity),
                  blurRadius: 120,
                  spreadRadius: 35,
                ),
                // Realistic shadows
                BoxShadow(
                  color: Colors.black.withOpacity(0.07),
                  blurRadius: 60,
                  offset: const Offset(0, 30),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 25,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Animated shimmer ring
                Transform.rotate(
                  angle: shimmerAngle,
                  child: Container(
                    width: 163,
                    height: 163,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: SweepGradient(
                        colors: [
                          Colors.transparent,
                          const Color(0xFF8B5CF6).withOpacity(0.2),
                          const Color(0xFF06B6D4).withOpacity(0.2),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.25, 0.75, 1.0],
                      ),
                    ),
                  ),
                ),
                // Inner container
                Container(
                  width: 145,
                  height: 145,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(color: Colors.white, width: 4),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF8B5CF6).withOpacity(0.1),
                        blurRadius: 15,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/icon/icon.png',
                      width: 137,
                      height: 137,
                      fit: BoxFit.cover,
                      errorBuilder:
                          (_, __, ___) => Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFF7C3AED), Color(0xFF06B6D4)],
                              ),
                            ),
                            child: const Center(
                              child: Text(
                                'A',
                                style: TextStyle(
                                  fontSize: 68,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                    ),
                  ),
                ),
                // Top highlight
                Positioned(
                  top: 12,
                  child: Container(
                    width: 50,
                    height: 16,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0.7),
                          Colors.transparent,
                        ],
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
  }

  Widget _buildBranding(double progress, double flow, Size size) {
    if (progress < 0.58) return const SizedBox.shrink();

    final brandPhase = _clamp((progress - 0.58) / 0.30);
    final smoothBrand = _easeInOutQuint(brandPhase);

    final opacity = _cinematicOut(_clamp(brandPhase / 0.4));
    final slideY = 40.0 * (1.0 - smoothBrand);

    return Positioned(
      bottom: size.height * 0.14,
      left: 0,
      right: 0,
      child: Transform.translate(
        offset: Offset(0, slideY),
        child: Opacity(
          opacity: _clamp(opacity),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // App name with depth shadow
              Stack(
                alignment: Alignment.center,
                children: [
                  // Shadow layer
                  Text(
                    'Attendanzy',
                    style: TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.w800,
                      color: Colors.black.withOpacity(0.04),
                      letterSpacing: -1.5,
                    ),
                  ),
                  // Main gradient text
                  ShaderMask(
                    shaderCallback:
                        (bounds) => const LinearGradient(
                          colors: [
                            Color(0xFF5B21B6),
                            Color(0xFF7C3AED),
                            Color(0xFF0891B2),
                          ],
                        ).createShader(bounds),
                    child: const Text(
                      'Attendanzy',
                      style: TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -1.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              // Tagline pill
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF7C3AED), Color(0xFF06B6D4)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF7C3AED).withOpacity(0.5),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Smart Attendance Management',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF374151),
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFadeOut(double progress) {
    if (progress < 0.94) return const SizedBox.shrink();

    final fadePhase = _clamp((progress - 0.94) / 0.06);
    final opacity = _smootherStep(fadePhase);

    return Container(color: Colors.white.withOpacity(_clamp(opacity)));
  }
}

class _Feature {
  final IconData icon;
  final Color color;
  final String label;
  final double angle;

  _Feature(this.icon, this.color, this.label, this.angle);
}

class _FloatingOrb {
  final double baseX;
  final double baseY;
  final double size;
  final Color color;
  final double phaseOffset;
  final double speed;

  _FloatingOrb({
    required this.baseX,
    required this.baseY,
    required this.size,
    required this.color,
    required this.phaseOffset,
    required this.speed,
  });
}
