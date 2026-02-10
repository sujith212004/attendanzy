import 'package:flutter/material.dart';
import 'dart:math' as math;

/// WOW-style splash animation with enhanced reliability, flexibility, and optimization
///
/// Features:
/// - Multi-phase animation with anticipation, overshoot, and settle
/// - Configurable timing, particle counts, and visual effects
/// - Performance-optimized with RepaintBoundary
/// - Phase-based state management for debugging
/// - Magnetic curve paths with spiral motion
/// - Dynamic breathing and shake effects
///
/// Usage:
/// ```dart
/// WowSplashAnimation(
///   onComplete: () => Navigator.pushReplacement(...),
///   config: WowAnimationConfig(
///     totalDuration: Duration(milliseconds: 2800),
///     explosionParticleCount: 50,
///     tileStaggerDelay: 0.12,
///     ambientGlowIntensity: 0.4,
///   ),
/// )
/// ```

/// Animation phases for better debugging and control
enum AnimationPhase {
  idle,
  backgroundEntry,
  tilesFlying,
  tilesMerging,
  logoRevealing,
  logoBreathing,
  completed,
}

/// Configuration class for flexible animation parameters
class WowAnimationConfig {
  final Duration totalDuration;
  final Duration ambientCycleDuration;
  final Duration logoPulseDuration;

  // Timing breakpoints (0.0 - 1.0)
  final double tilesStartPoint;
  final double tilesFlyEndPoint;
  final double logoStartPoint;

  // Tile animation settings
  final double tileStaggerDelay;
  final double tileRotationMultiplier;
  final double tileMagneticCurvePower;
  final int tileTrailParticles;

  // Logo animation settings
  final double logoAnticipationScale;
  final double logoOvershootScale;
  final int explosionParticleCount;
  final int rippleWaveCount;

  // Visual settings
  final double ambientGlowIntensity;
  final double shadowBlurMultiplier;
  final bool enableParticleTrails;
  final bool enableBackgroundEffects;

  const WowAnimationConfig({
    this.totalDuration = const Duration(milliseconds: 1800),
    this.ambientCycleDuration = const Duration(milliseconds: 2000),
    this.logoPulseDuration = const Duration(milliseconds: 1200),
    this.tilesStartPoint = 0.05,
    this.tilesFlyEndPoint = 0.50,
    this.logoStartPoint = 0.55,
    this.tileStaggerDelay = 0.08,
    this.tileRotationMultiplier = 1.5,
    this.tileMagneticCurvePower = 1.4,
    this.tileTrailParticles = 4,
    this.logoAnticipationScale = 0.4,
    this.logoOvershootScale = 1.05,
    this.explosionParticleCount = 24,
    this.rippleWaveCount = 3,
    this.ambientGlowIntensity = 0.2,
    this.shadowBlurMultiplier = 0.8,
    this.enableParticleTrails = false,
    this.enableBackgroundEffects = true,
  });
}

class WowSplashAnimation extends StatefulWidget {
  final VoidCallback onComplete;
  final Duration duration;
  final WowAnimationConfig config;

  const WowSplashAnimation({
    Key? key,
    required this.onComplete,
    this.duration = const Duration(milliseconds: 2400),
    this.config = const WowAnimationConfig(),
  }) : super(key: key);

  @override
  State<WowSplashAnimation> createState() => _WowSplashAnimationState();
}

class _WowSplashAnimationState extends State<WowSplashAnimation>
    with TickerProviderStateMixin {
  late AnimationController _main;
  late AnimationController _ambient;
  late AnimationController _logo;
  late AnimationController _shake; // For micro-interactions

  late Animation<double> _progress;
  late Animation<double> _ambientAnimation;
  late Animation<double> _logoAnimation;
  late Animation<double> _shakeAnimation;

  AnimationPhase _currentPhase = AnimationPhase.idle;

  @override
  void initState() {
    super.initState();

    _main = AnimationController(
      vsync: this,
      duration: widget.config.totalDuration,
    );
    _ambient = AnimationController(
      vsync: this,
      duration: widget.config.ambientCycleDuration,
    )..repeat(reverse: true);
    _logo = AnimationController(
      vsync: this,
      duration: widget.config.logoPulseDuration,
    )..repeat(reverse: true);
    _shake = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _progress = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _main, curve: Curves.easeOutQuart));
    _ambientAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ambient, curve: Curves.easeInOutSine));
    _logoAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _logo, curve: Curves.easeInOut));
    _shakeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _shake, curve: Curves.elasticOut));

    // Track animation phases for debugging and optimization
    _main.addListener(_updatePhase);

    _main.forward().then((_) {
      if (mounted) {
        setState(() => _currentPhase = AnimationPhase.completed);
        widget.onComplete();
      }
    });
  }

  void _updatePhase() {
    if (!mounted) return;
    final progress = _progress.value;
    AnimationPhase newPhase = _currentPhase;

    if (progress < widget.config.tilesStartPoint) {
      newPhase = AnimationPhase.backgroundEntry;
    } else if (progress < widget.config.tilesFlyEndPoint) {
      newPhase = AnimationPhase.tilesFlying;
    } else if (progress < widget.config.logoStartPoint) {
      newPhase = AnimationPhase.tilesMerging;
    } else if (progress < 0.80) {
      newPhase = AnimationPhase.logoRevealing;
    } else {
      newPhase = AnimationPhase.logoBreathing;
    }

    if (newPhase != _currentPhase) {
      setState(() => _currentPhase = newPhase);
      // Trigger micro shake on phase transitions
      if (newPhase == AnimationPhase.logoRevealing) {
        _shake.forward(from: 0.0);
      }
    }
  }

  @override
  void dispose() {
    _main.removeListener(_updatePhase);
    _main.dispose();
    _ambient.dispose();
    _logo.dispose();
    _shake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: AnimatedBuilder(
          animation: Listenable.merge([_main, _ambient, _logo, _shake]),
          builder: (context, child) {
            return Stack(
              alignment: Alignment.center,
              children: [
                // Animated professional gradient background with depth
                AnimatedContainer(
                  duration: const Duration(milliseconds: 800),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color.lerp(
                          const Color(0xFFFDFDFF),
                          const Color(0xFFF5F0FF),
                          _progress.value,
                        )!,
                        Color.lerp(
                          const Color(0xFFFAF8FF),
                          const Color(0xFFEDE7FF),
                          _progress.value,
                        )!,
                        Color.lerp(
                          const Color(0xFFF0F9FF),
                          const Color(0xFFE8F8F8),
                          _progress.value,
                        )!,
                      ],
                    ),
                  ),
                ),

                // Animated radial glow effect
                Center(
                  child: Container(
                    width: 400 + (_ambientAnimation.value * 100),
                    height: 400 + (_ambientAnimation.value * 100),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(
                            0xFF7A3EEB,
                          ).withValues(alpha: 0.08 * (1 - _progress.value)),
                          const Color(
                            0xFF1FD6C8,
                          ).withValues(alpha: 0.05 * (1 - _progress.value)),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),

                // Phase 1: Bokeh particles background (optimized timing)
                if (_progress.value < 0.90)
                  CustomPaint(
                    size: Size.infinite,
                    painter: _BokehParticlesPainter(
                      progress: _progress.value,
                      ambient: _ambientAnimation.value,
                    ),
                  ),

                // Phase 2: Radial energy waves (quick burst)
                if (_progress.value < 0.35)
                  CustomPaint(
                    size: Size.infinite,
                    painter: _EnergyWavesPainter(
                      progress: (_progress.value / 0.35).clamp(0, 1),
                      ambient: _ambientAnimation.value,
                    ),
                  ),

                // Phase 3: Four feature tiles animation (faster timing)
                if (_progress.value > 0.03 && _progress.value < 0.55)
                  _buildFeatureTiles(),

                // Phase 4: Tiles merge to Attendanzy logo (earlier reveal)
                if (_progress.value > 0.52) _buildCentralLogo(),

                // Smooth exit fade (faster transition)
                Opacity(
                  opacity: ((_progress.value - 0.78) / 0.22).clamp(0, 1),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0.0),
                          Colors.white,
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildFeatureTiles() {
    final tileProgress = ((_progress.value - widget.config.tilesStartPoint) /
            (widget.config.tilesFlyEndPoint - widget.config.tilesStartPoint))
        .clamp(0, 1);

    // Four features with their positions and colors
    final features = [
      (
        title: 'OD Request',
        icon: Icons.file_present_rounded,
        color: const Color(0xFF7A3EEB),
        startPos: const Offset(-200, -200),
      ),
      (
        title: 'Leave Request',
        icon: Icons.event_available_rounded,
        color: const Color(0xFF1FD6C8),
        startPos: const Offset(200, -200),
      ),
      (
        title: 'Attendance',
        icon: Icons.check_circle_rounded,
        color: const Color(0xFFFF6B6B),
        startPos: const Offset(-200, 200),
      ),
      (
        title: 'Timetable',
        icon: Icons.schedule_rounded,
        color: const Color(0xFF57E19C),
        startPos: const Offset(200, 200),
      ),
    ];

    return Stack(
      alignment: Alignment.center,
      children:
          features.asMap().entries.map((entry) {
            final index = entry.key;
            final feature = entry.value;

            // Enhanced staggered animation with anticipation
            final delay = index * widget.config.tileStaggerDelay;
            final tileProg = ((tileProgress - delay) / (1 - delay)).clamp(0, 1);

            // Optimized multi-stage easing: smooth and fast
            double easedProg;
            if (tileProg < 0.1) {
              // Quick anticipation phase
              easedProg = Curves.easeOutQuad.transform(tileProg / 0.1) * -0.02;
            } else if (tileProg < 0.9) {
              // Main flight with smooth fast easing
              final mainProg = (tileProg - 0.1) / 0.8;
              easedProg = Curves.easeOutQuart.transform(mainProg);
            } else {
              // Quick settle phase
              final settleProg = (tileProg - 0.9) / 0.1;
              final smoothSettle = Curves.easeOutQuad.transform(settleProg);
              easedProg =
                  1.0 +
                  (math.sin(smoothSettle * math.pi) *
                      0.008 *
                      (1 - smoothSettle));
            }
            easedProg = easedProg.clamp(0.0, 1.1);

            // Calculate position with optimized spacing
            final gridPositions = [
              const Offset(-55, -55), // Top-left
              const Offset(55, -55), // Top-right
              const Offset(-55, 55), // Bottom-left
              const Offset(55, 55), // Bottom-right
            ];

            final targetPos = gridPositions[index];

            // Enhanced magnetic curve path with variable pull strength
            final magneticPull = math.pow(
              easedProg.clamp(0, 1),
              widget.config.tileMagneticCurvePower,
            );

            // Add gentle spiral motion for smooth feel
            final spiralAngle = (1 - magneticPull) * math.pi * 0.4;
            final spiralOffset = (1 - magneticPull) * 10;

            final curvedPos = Offset(
              feature.startPos.dx +
                  (targetPos.dx - feature.startPos.dx) * magneticPull +
                  (math.cos(spiralAngle + index * math.pi * 0.5) *
                      spiralOffset),
              feature.startPos.dy +
                  (targetPos.dy - feature.startPos.dy) * magneticPull +
                  (math.sin(spiralAngle + index * math.pi * 0.5) *
                      spiralOffset),
            );

            // Enhanced 3D rotation with configurable multiplier
            final rotation =
                (1 - easedProg.clamp(0, 1)) *
                math.pi *
                widget.config.tileRotationMultiplier;
            final perspectiveRotation =
                (1 - easedProg.clamp(0, 1)) * math.pi * 0.4;

            // Smooth combination effect during merge phase (faster)
            final mergeProgress = ((tileProg - 0.85) / 0.15).clamp(0.0, 1.0);
            final combinationScale =
                tileProg >= 0.85
                    ? 1.0 + (Curves.easeOutQuad.transform(mergeProgress) * 0.12)
                    : 1.0;
            final combinationGlow =
                tileProg >= 0.85
                    ? Curves.easeOutQuad.transform(mergeProgress) * 0.3
                    : 0.0;

            // Dynamic scale with subtle breathing effect and combination scale
            final breathingScale =
                1.0 + (math.sin(_logoAnimation.value * math.pi * 2) * 0.03);
            final scale =
                easedProg.clamp(0, 1) * breathingScale * combinationScale;

            return Positioned(
              left: MediaQuery.of(context).size.width / 2 + curvedPos.dx - 44,
              top: MediaQuery.of(context).size.height / 2 + curvedPos.dy - 44,
              child: RepaintBoundary(
                child: Transform(
                  transform:
                      Matrix4.identity()
                        ..setEntry(3, 2, 0.001)
                        ..rotateX(perspectiveRotation * 0.3)
                        ..rotateY(perspectiveRotation * 0.5)
                        ..rotateZ(rotation),
                  alignment: Alignment.center,
                  child: Transform.scale(
                    scale: scale,
                    child: Opacity(
                      opacity: tileProg.toDouble(),
                      child: Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          gradient: LinearGradient(
                            begin: Alignment(
                              -1.0 + (_ambientAnimation.value * 0.4),
                              -1.0,
                            ),
                            end: Alignment(
                              1.0 - (_ambientAnimation.value * 0.4),
                              1.0,
                            ),
                            colors: [
                              Color.lerp(
                                feature.color.withValues(alpha: 1.0),
                                Colors.white,
                                0.15,
                              )!,
                              Color.lerp(
                                feature.color,
                                Colors.white,
                                0.05,
                              )!.withValues(alpha: 0.95),
                              feature.color.withValues(alpha: 0.88),
                              feature.color.withValues(alpha: 0.75),
                              Color.lerp(
                                feature.color,
                                Colors.black,
                                0.18,
                              )!.withValues(alpha: 0.92),
                              Color.lerp(
                                feature.color,
                                Colors.black,
                                0.25,
                              )!.withValues(alpha: 0.85),
                            ],
                            stops: const [0.0, 0.2, 0.4, 0.6, 0.8, 1.0],
                          ),
                          boxShadow: [
                            // Combination glow effect during merge
                            if (combinationGlow > 0)
                              BoxShadow(
                                color: Colors.white.withValues(
                                  alpha: combinationGlow,
                                ),
                                blurRadius: 60 * combinationGlow,
                                spreadRadius: 30 * combinationGlow,
                              ),
                            // Main color shadow with animation and config multiplier
                            BoxShadow(
                              color: feature.color.withValues(
                                alpha:
                                    (0.45 + (_ambientAnimation.value * 0.1)) +
                                    (combinationGlow * 0.2),
                              ),
                              blurRadius:
                                  (28 + (_ambientAnimation.value * 5)) *
                                  widget.config.shadowBlurMultiplier,
                              spreadRadius: 3,
                              offset: Offset(
                                0,
                                5 + (_ambientAnimation.value * 2),
                              ),
                            ),
                            // Outer glow
                            BoxShadow(
                              color: feature.color.withValues(alpha: 0.25),
                              blurRadius:
                                  45 * widget.config.shadowBlurMultiplier,
                              spreadRadius: 10,
                            ),
                            // Depth shadow
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 12,
                              offset: const Offset(0, 3),
                            ),
                            // Ambient light
                            BoxShadow(
                              color: Colors.white.withValues(alpha: 0.5),
                              blurRadius: 8,
                              spreadRadius: -3,
                              offset: const Offset(-2, -2),
                            ),
                          ],
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.5),
                            width: 3,
                          ),
                        ),
                        child: Stack(
                          children: [
                            // Premium glass morphism base with enhanced depth
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(26),
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.white.withValues(alpha: 0.35),
                                    Colors.white.withValues(alpha: 0.22),
                                    Colors.white.withValues(alpha: 0.08),
                                    Colors.transparent,
                                    Colors.black.withValues(alpha: 0.12),
                                    Colors.black.withValues(alpha: 0.22),
                                  ],
                                  stops: const [0.0, 0.25, 0.45, 0.6, 0.8, 1.0],
                                ),
                              ),
                            ),
                            // Inner glow effect
                            Container(
                              margin: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(24),
                                gradient: RadialGradient(
                                  center: Alignment.topLeft,
                                  radius: 1.2,
                                  colors: [
                                    feature.color.withValues(alpha: 0.15),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                            // Subtle dot pattern texture for premium feel
                            ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: CustomPaint(
                                size: const Size(88, 88),
                                painter: _DotPatternPainter(
                                  color: Colors.white.withValues(alpha: 0.1),
                                  spacing: 7,
                                ),
                              ),
                            ),
                            // Top highlight bar for premium 3D effect
                            Positioned(
                              top: 0,
                              left: 0,
                              right: 0,
                              height: 32,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(24),
                                    topRight: Radius.circular(24),
                                  ),
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.white.withValues(alpha: 0.5),
                                      Colors.white.withValues(alpha: 0.3),
                                      Colors.white.withValues(alpha: 0.12),
                                      Colors.transparent,
                                    ],
                                    stops: const [0.0, 0.4, 0.7, 1.0],
                                  ),
                                ),
                              ),
                            ),
                            // Subtle inner border glow
                            Positioned(
                              top: 1,
                              left: 1,
                              right: 1,
                              bottom: 1,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(25),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.25),
                                    width: 1,
                                  ),
                                ),
                              ),
                            ),
                            // Animated shimmer sweep for premium effect
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(24),
                                  gradient: LinearGradient(
                                    begin: Alignment(
                                      -2.5 + (_ambientAnimation.value * 5),
                                      -1.0,
                                    ),
                                    end: Alignment(
                                      0.5 + (_ambientAnimation.value * 5),
                                      1.5,
                                    ),
                                    colors: [
                                      Colors.transparent,
                                      feature.color.withValues(alpha: 0.08),
                                      Colors.white.withValues(
                                        alpha:
                                            0.4 +
                                            (_ambientAnimation.value * 0.2),
                                      ),
                                      feature.color.withValues(alpha: 0.08),
                                      Colors.transparent,
                                    ],
                                    stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
                                  ),
                                ),
                              ),
                            ),
                            // Main content - Ultra-optimized to prevent overflow
                            Padding(
                              padding: const EdgeInsets.all(6.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Transform.scale(
                                    scale:
                                        1.0 +
                                        (math.sin(
                                              _logoAnimation.value *
                                                  math.pi *
                                                  2,
                                            ) *
                                            0.04),
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.25,
                                        ),
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.white.withValues(
                                              alpha: 0.5,
                                            ),
                                            blurRadius: 12,
                                            spreadRadius: 2,
                                          ),
                                          BoxShadow(
                                            color: feature.color.withValues(
                                              alpha: 0.3,
                                            ),
                                            blurRadius: 16,
                                            spreadRadius: 1,
                                          ),
                                        ],
                                      ),
                                      child: Icon(
                                        feature.icon,
                                        size: 24,
                                        color: Colors.white,
                                        shadows: [
                                          Shadow(
                                            blurRadius: 10,
                                            color: Colors.black.withValues(
                                              alpha: 0.35,
                                            ),
                                            offset: const Offset(0, 2),
                                          ),
                                          Shadow(
                                            blurRadius: 20,
                                            color: feature.color.withValues(
                                              alpha: 0.35,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Flexible(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 1.5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(
                                          alpha: 0.2,
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        feature.title,
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 8.5,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.3,
                                          height: 1.1,
                                          shadows: [
                                            Shadow(
                                              blurRadius: 6,
                                              color: Color(0x60000000),
                                              offset: Offset(0, 1),
                                            ),
                                            Shadow(
                                              blurRadius: 2,
                                              color: Color(0x80FFFFFF),
                                              offset: Offset(0, -0.5),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Enhanced badge indicator with smooth pulse
                            Positioned(
                              top: 6,
                              right: 6,
                              child: Transform.scale(
                                scale:
                                    1.0 +
                                    (math.sin(
                                          _logoAnimation.value * math.pi * 2 +
                                              index * 0.5,
                                        ) *
                                        0.06),
                                child: Container(
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    gradient: RadialGradient(
                                      colors: [
                                        Colors.white,
                                        Colors.white.withValues(alpha: 0.95),
                                        feature.color.withValues(alpha: 0.15),
                                      ],
                                      stops: const [0.0, 0.7, 1.0],
                                    ),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.white.withValues(
                                          alpha:
                                              0.65 +
                                              (_ambientAnimation.value * 0.15),
                                        ),
                                        blurRadius:
                                            10 + (_ambientAnimation.value * 3),
                                        spreadRadius: 2,
                                      ),
                                      BoxShadow(
                                        color: feature.color.withValues(
                                          alpha:
                                              0.45 +
                                              (_ambientAnimation.value * 0.1),
                                        ),
                                        blurRadius: 14,
                                        spreadRadius: 3,
                                      ),
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.1,
                                        ),
                                        blurRadius: 4,
                                        offset: const Offset(0, 1),
                                      ),
                                    ],
                                    border: Border.all(
                                      color: feature.color.withValues(
                                        alpha: 0.35,
                                      ),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${index + 1}',
                                      style: TextStyle(
                                        color: feature.color,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w900,
                                        height: 1.0,
                                        shadows: [
                                          Shadow(
                                            color: feature.color.withValues(
                                              alpha: 0.35,
                                            ),
                                            blurRadius: 5,
                                          ),
                                          const Shadow(
                                            color: Colors.white,
                                            blurRadius: 2,
                                          ),
                                        ],
                                      ),
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
                ),
              ),
            );
          }).toList(),
    );
  }

  Widget _buildCentralLogo() {
    final logoProg = ((_progress.value - widget.config.logoStartPoint) /
            (1.0 - widget.config.logoStartPoint))
        .clamp(0, 1);

    // Optimized smooth logo reveal animation
    double scale;
    double rotation;

    if (logoProg < 0.15) {
      // Phase 1: Quick anticipation
      final anticipationProg = logoProg / 0.15;
      scale =
          widget.config.logoAnticipationScale *
          Curves.easeOutQuad.transform(anticipationProg);
      rotation = math.pi * 0.4;
    } else if (logoProg < 0.65) {
      // Phase 2: Smooth fast reveal with gentle overshoot
      final revealProg = (logoProg - 0.15) / 0.5;
      final overshoot = Curves.easeOutCubic.transform(revealProg);
      scale =
          widget.config.logoAnticipationScale +
          (overshoot *
              (widget.config.logoOvershootScale -
                  widget.config.logoAnticipationScale));
      rotation = (1 - Curves.easeOutQuad.transform(revealProg)) * math.pi * 0.4;
    } else {
      // Phase 3: Quick settle and gentle breathe
      final breatheProg = (logoProg - 0.65) / 0.35;
      final settleScale =
          widget.config.logoOvershootScale +
          ((1.0 - widget.config.logoOvershootScale) *
              Curves.easeOutQuad.transform(breatheProg));
      // Subtle breathing animation
      final breathe = math.sin(_logoAnimation.value * math.pi * 2) * 0.015;
      scale = settleScale + (breathe * breatheProg);
      rotation = 0;
    }

    // Subtle shake effect on reveal
    final shakeOffset =
        _shakeAnimation.value * math.sin(_progress.value * math.pi * 12) * 1.0;

    return Transform.translate(
      offset: Offset(shakeOffset, shakeOffset * 0.5),
      child: Transform.rotate(
        angle: rotation,
        child: Transform.scale(
          scale: scale,
          child: Opacity(
            opacity: logoProg.toDouble(),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Enhanced outer radial glow with dramatic pulsing
                Container(
                  width:
                      380 +
                      (_ambientAnimation.value * 70) +
                      (shakeOffset.abs() * 15),
                  height:
                      380 +
                      (_ambientAnimation.value * 70) +
                      (shakeOffset.abs() * 15),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF7A3EEB).withValues(
                          alpha:
                              (widget.config.ambientGlowIntensity +
                                  (_ambientAnimation.value * 0.08)) *
                              logoProg,
                        ),
                        const Color(0xFF1FD6C8).withValues(
                          alpha:
                              (widget.config.ambientGlowIntensity * 0.6 +
                                  (_ambientAnimation.value * 0.05)) *
                              logoProg,
                        ),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),

                // Ultimate particle burst with configurable count
                if (logoProg > 0.15)
                  CustomPaint(
                    size: const Size(500, 500),
                    painter: _ExplosiveParticleBurstPainter(
                      progress: ((logoProg - 0.15) / 0.85).clamp(0, 1),
                      particleCount: widget.config.explosionParticleCount,
                      ambient: _ambientAnimation.value,
                    ),
                  ),

                // Dynamic ripple wave rings with config count
                if (logoProg > 0.2)
                  ...List.generate(widget.config.rippleWaveCount, (i) {
                    final waveDelay = i * 0.15;
                    final waveProg =
                        ((logoProg - 0.2 - waveDelay) / (1 - 0.2 - waveDelay))
                            .clamp(0, 1)
                            .toDouble();
                    return CustomPaint(
                      size: const Size(600, 600),
                      painter: _RippleWavePainter(progress: waveProg, index: i),
                    );
                  }),
                // Main logo container with premium multi-layer design
                Transform.rotate(
                  angle: math.sin(_ambientAnimation.value * math.pi) * 0.015,
                  child: Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        center: Alignment(-0.3, -0.3),
                        colors: [
                          Colors.white,
                          Colors.white.withValues(alpha: 0.99),
                          Colors.white.withValues(alpha: 0.97),
                          Colors.white.withValues(alpha: 0.95),
                        ],
                        stops: const [0.0, 0.5, 0.8, 1.0],
                      ),
                      boxShadow: [
                        // Primary purple glow - intense
                        BoxShadow(
                          color: const Color(0xFF7A3EEB).withValues(
                            alpha: 0.4 + (_ambientAnimation.value * 0.15),
                          ),
                          blurRadius: 60 + (_ambientAnimation.value * 15),
                          spreadRadius: 18,
                        ),
                        // Secondary purple glow - softer
                        BoxShadow(
                          color: const Color(0xFF7A3EEB).withValues(
                            alpha: 0.25 + (_ambientAnimation.value * 0.1),
                          ),
                          blurRadius: 85 + (_ambientAnimation.value * 12),
                          spreadRadius: 30,
                        ),
                        // Teal accent glow - primary
                        BoxShadow(
                          color: const Color(0xFF1FD6C8).withValues(
                            alpha: 0.28 + (_ambientAnimation.value * 0.1),
                          ),
                          blurRadius: 80,
                          spreadRadius: 28,
                        ),
                        // Teal accent glow - extended
                        BoxShadow(
                          color: const Color(0xFF1FD6C8).withValues(
                            alpha: 0.15 + (_ambientAnimation.value * 0.08),
                          ),
                          blurRadius: 110,
                          spreadRadius: 40,
                        ),
                        // Depth shadow - strong
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 35,
                          offset: const Offset(0, 12),
                        ),
                        // Depth shadow - soft
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 50,
                          offset: const Offset(0, 18),
                        ),
                        // White highlight - top left
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.9),
                          blurRadius: 25,
                          spreadRadius: -3,
                          offset: const Offset(-6, -6),
                        ),
                        // White highlight - soft glow
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.5),
                          blurRadius: 40,
                          spreadRadius: -8,
                          offset: const Offset(-4, -4),
                        ),
                      ],
                      border: Border.all(width: 4, color: Colors.transparent),
                    ),
                    // Premium inner gradient border with multiple layers
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          width: 3.5,
                          color: Colors.transparent,
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xFF7A3EEB).withValues(alpha: 0.25),
                            const Color(0xFF1FD6C8).withValues(alpha: 0.2),
                            const Color(0xFF7A3EEB).withValues(alpha: 0.15),
                          ],
                        ),
                      ),
                      child: Container(
                        margin: const EdgeInsets.all(3.5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFF7A3EEB,
                              ).withValues(alpha: 0.15),
                              blurRadius: 15,
                              spreadRadius: -5,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Logo from assets - PROMINENTLY DISPLAYED with premium effects
                            Transform.scale(
                              scale:
                                  1.0 +
                                  math.sin(_logoAnimation.value * math.pi) *
                                      0.04,
                              child: Container(
                                width: 120,
                                height: 120,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(32),
                                  boxShadow: [
                                    // Primary purple glow
                                    BoxShadow(
                                      color: const Color(0xFF7A3EEB).withValues(
                                        alpha:
                                            0.4 +
                                            (_ambientAnimation.value * 0.18),
                                      ),
                                      blurRadius:
                                          32 + (_ambientAnimation.value * 10),
                                      spreadRadius: 8,
                                    ),
                                    // Extended purple glow
                                    BoxShadow(
                                      color: const Color(0xFF7A3EEB).withValues(
                                        alpha:
                                            0.22 +
                                            (_ambientAnimation.value * 0.1),
                                      ),
                                      blurRadius:
                                          48 + (_ambientAnimation.value * 8),
                                      spreadRadius: 15,
                                    ),
                                    // Teal accent glow
                                    BoxShadow(
                                      color: const Color(0xFF1FD6C8).withValues(
                                        alpha:
                                            0.3 +
                                            (_ambientAnimation.value * 0.12),
                                      ),
                                      blurRadius: 40,
                                      spreadRadius: 12,
                                    ),
                                    // Teal extended glow
                                    BoxShadow(
                                      color: const Color(0xFF1FD6C8).withValues(
                                        alpha:
                                            0.18 +
                                            (_ambientAnimation.value * 0.08),
                                      ),
                                      blurRadius: 55,
                                      spreadRadius: 20,
                                    ),
                                    // Depth shadow
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.15,
                                      ),
                                      blurRadius: 22,
                                      offset: const Offset(0, 8),
                                    ),
                                    // Soft depth shadow
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.08,
                                      ),
                                      blurRadius: 35,
                                      offset: const Offset(0, 12),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  child: Opacity(
                                    opacity: logoProg.toDouble(),
                                    child: Image.asset(
                                      'assets/icon/icon.png',
                                      fit: BoxFit.cover,
                                      filterQuality: FilterQuality.high,
                                      errorBuilder: (
                                        context,
                                        error,
                                        stackTrace,
                                      ) {
                                        // Try logo.jpg as fallback
                                        return Image.asset(
                                          'assets/image/logo.jpg',
                                          fit: BoxFit.cover,
                                          filterQuality: FilterQuality.high,
                                          errorBuilder: (
                                            context,
                                            error,
                                            stackTrace,
                                          ) {
                                            // Show custom painter as final fallback
                                            return CustomPaint(
                                              size: const Size(116, 116),
                                              painter: _LogoAPainter(
                                                progress: logoProg.toDouble(),
                                                glowIntensity:
                                                    logoProg.toDouble(),
                                              ),
                                            );
                                          },
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            // Premium animated shimmer indicator
                            Container(
                              width: 45,
                              height: 3,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(3),
                                gradient: LinearGradient(
                                  begin: Alignment(
                                    -1.0 + (_ambientAnimation.value * 2),
                                    0,
                                  ),
                                  end: Alignment(
                                    1.0 + (_ambientAnimation.value * 2),
                                    0,
                                  ),
                                  colors: [
                                    const Color(0xFF7A3EEB).withValues(
                                      alpha:
                                          0.3 + (_ambientAnimation.value * 0.4),
                                    ),
                                    const Color(0xFF5B2BC9).withValues(
                                      alpha:
                                          0.5 + (_ambientAnimation.value * 0.3),
                                    ),
                                    const Color(0xFF1FD6C8).withValues(
                                      alpha:
                                          0.5 + (_ambientAnimation.value * 0.3),
                                    ),
                                    const Color(0xFF57E19C).withValues(
                                      alpha:
                                          0.3 + (_ambientAnimation.value * 0.4),
                                    ),
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF7A3EEB).withValues(
                                      alpha:
                                          0.4 + (_ambientAnimation.value * 0.3),
                                    ),
                                    blurRadius: 12,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),
                            // Premium app name with vibrant animated gradient
                            Transform.scale(
                              scale:
                                  1.0 +
                                  (math.sin(_logoAnimation.value * math.pi) *
                                      0.02),
                              child: ShaderMask(
                                shaderCallback: (bounds) {
                                  return LinearGradient(
                                    begin: Alignment(
                                      -1.0 + (_ambientAnimation.value * 0.5),
                                      -0.5,
                                    ),
                                    end: Alignment(
                                      1.0 - (_ambientAnimation.value * 0.5),
                                      0.5,
                                    ),
                                    colors: [
                                      const Color(0xFF7A3EEB),
                                      const Color(0xFF5B2BC9),
                                      const Color(0xFF1FD6C8),
                                      const Color(0xFF57E19C),
                                      const Color(0xFF7A3EEB),
                                    ],
                                    stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
                                  ).createShader(bounds);
                                },
                                child: const Text(
                                  'Attendanzy',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.8,
                                    color: Colors.white,
                                    shadows: [
                                      Shadow(
                                        blurRadius: 15,
                                        color: Color(0x607A3EEB),
                                        offset: Offset(0, 3),
                                      ),
                                      Shadow(
                                        blurRadius: 25,
                                        color: Color(0x401FD6C8),
                                      ),
                                      Shadow(
                                        blurRadius: 35,
                                        color: Color(0x2057E19C),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 5),
                            // Minimalist tagline to prevent overflow
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(
                                      0xFF7A3EEB,
                                    ).withValues(alpha: 0.12),
                                    const Color(
                                      0xFF1FD6C8,
                                    ).withValues(alpha: 0.1),
                                  ],
                                ),
                                border: Border.all(
                                  color: const Color(
                                    0xFF7A3EEB,
                                  ).withValues(alpha: 0.25),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF7A3EEB,
                                    ).withValues(alpha: 0.1),
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.school_rounded,
                                    size: 10,
                                    color: Color(0xFF7A3EEB),
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Smart Campus',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.6,
                                      color: Color(0xFF7A3EEB),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
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
  }
}

// ============================================================================
// OPTIMIZED CUSTOM PAINTERS
// ============================================================================

// Light beams painter for dynamic background
class _LightBeamsPainter extends CustomPainter {
  final double progress;
  final double ambient;

  _LightBeamsPainter({required this.progress, required this.ambient});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final beamCount = 8;

    for (int i = 0; i < beamCount; i++) {
      final angle = (i / beamCount) * math.pi * 2 + ambient * math.pi;
      final length = size.width * 0.6 * (1 - progress * 0.5);

      final gradient = LinearGradient(
        colors: [
          const Color(0xFF7A3EEB).withValues(alpha: 0.15 * (1 - progress)),
          Colors.transparent,
        ],
      );

      final path =
          Path()
            ..moveTo(center.dx, center.dy)
            ..lineTo(
              center.dx + math.cos(angle) * length,
              center.dy + math.sin(angle) * length,
            )
            ..lineTo(
              center.dx + math.cos(angle + 0.1) * length,
              center.dy + math.sin(angle + 0.1) * length,
            )
            ..close();

      final paint =
          Paint()
            ..shader = gradient.createShader(path.getBounds())
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_LightBeamsPainter old) =>
      old.progress != progress || old.ambient != ambient;
}

// Holographic pattern painter
class _HolographicPainter extends CustomPainter {
  final Color color;
  final double progress;
  final double offset;

  _HolographicPainter({
    required this.color,
    required this.progress,
    required this.offset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1;

    final spacing = 6.0;
    final shift = (progress * 20 + offset * 5) % (spacing * 2);

    // Diagonal lines pattern
    for (double i = -size.width; i < size.width + size.height; i += spacing) {
      final path =
          Path()
            ..moveTo(i + shift, 0)
            ..lineTo(i + size.height + shift, size.height);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_HolographicPainter old) =>
      old.progress != progress || old.offset != offset;
}

// Particle trail painter
class _ParticleTrailPainter extends CustomPainter {
  final Color color;
  final double progress;

  _ParticleTrailPainter({required this.color, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final random = math.Random(42);

    for (int i = 0; i < 5; i++) {
      final angle = random.nextDouble() * math.pi * 2;
      final distance = (1 - progress) * (size.width * 0.3);
      final particleSize = (1 - progress) * (3 + random.nextDouble() * 4);

      final x = center.dx + math.cos(angle) * distance;
      final y = center.dy + math.sin(angle) * distance;

      final paint =
          Paint()
            ..color = color.withValues(alpha: (1 - progress) * 0.6)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

      canvas.drawCircle(Offset(x, y), particleSize, paint);
    }
  }

  @override
  bool shouldRepaint(_ParticleTrailPainter old) => old.progress != progress;
}

// Explosive particle burst painter
class _ExplosiveParticleBurstPainter extends CustomPainter {
  final double progress;
  final int particleCount;
  final double ambient;

  _ExplosiveParticleBurstPainter({
    required this.progress,
    this.particleCount = 32,
    this.ambient = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final random = math.Random(42);

    for (int i = 0; i < particleCount; i++) {
      final angle =
          (i / particleCount) * math.pi * 2 + (progress * math.pi * 0.8);
      final baseDistance = 80 + random.nextDouble() * 90;
      final explosionCurve = Curves.easeOutQuart.transform(progress);
      final distance = explosionCurve * baseDistance * (1 + ambient * 0.3);
      final particleSize =
          (1 - progress) * (6 + random.nextDouble() * 10) * (1 + ambient * 0.4);

      final x = center.dx + math.cos(angle) * distance;
      final y = center.dy + math.sin(angle) * distance;

      final colors = [
        const Color(0xFF7A3EEB),
        const Color(0xFFAB47BC),
        const Color(0xFF1FD6C8),
        const Color(0xFFFF6B6B),
        const Color(0xFF57E19C),
        const Color(0xFFFFC107),
      ];

      final color = colors[i % 6];

      // Outer glow
      final glowPaint =
          Paint()
            ..color = color.withValues(alpha: (1 - progress) * 0.4)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8 + ambient * 4);
      canvas.drawCircle(Offset(x, y), particleSize * 1.5, glowPaint);

      // Main particle
      final paint =
          Paint()
            ..color = color.withValues(
              alpha: (1 - progress) * (0.9 + ambient * 0.1),
            )
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, 5 + ambient * 2);
      canvas.drawCircle(Offset(x, y), particleSize, paint);

      // Bright core
      final corePaint =
          Paint()
            ..color = Colors.white.withValues(alpha: (1 - progress) * 0.7)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      canvas.drawCircle(Offset(x, y), particleSize * 0.3, corePaint);
    }
  }

  @override
  bool shouldRepaint(_ExplosiveParticleBurstPainter old) =>
      old.progress != progress || old.ambient != ambient;
}

// Ripple wave painter
class _RippleWavePainter extends CustomPainter {
  final double progress;
  final int index;

  _RippleWavePainter({required this.progress, required this.index});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width * 0.6;
    final radius = Curves.easeOut.transform(progress) * maxRadius;

    final colors = [
      const Color(0xFF7A3EEB),
      const Color(0xFF1FD6C8),
      const Color(0xFFAB47BC),
    ];

    final paint =
        Paint()
          ..color = colors[index].withValues(alpha: (1 - progress) * 0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3 + (1 - progress) * 5
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(_RippleWavePainter old) => old.progress != progress;
}

// Custom painter for particle burst effect when tiles merge
class _ParticleBurstPainter extends CustomPainter {
  final double progress;
  final int particleCount;
  final double ambient;

  _ParticleBurstPainter({
    required this.progress,
    this.particleCount = 24,
    this.ambient = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final random = math.Random(42); // Fixed seed for consistency

    for (int i = 0; i < particleCount; i++) {
      // Create spiral burst pattern
      final angle =
          (i / particleCount) * math.pi * 2 + (progress * math.pi * 0.5);
      final baseDistance = 70 + random.nextDouble() * 70;
      final distance = progress * baseDistance * (1 + ambient * 0.2);
      final particleSize =
          (1 - progress) * (5 + random.nextDouble() * 8) * (1 + ambient * 0.3);

      final x = center.dx + math.cos(angle) * distance;
      final y = center.dy + math.sin(angle) * distance;

      final colors = [
        const Color(0xFF7A3EEB),
        const Color(0xFF1FD6C8),
        const Color(0xFFFF6B6B),
        const Color(0xFF57E19C),
      ];

      final color = colors[i % 4];

      // Main particle
      final paint =
          Paint()
            ..color = color.withValues(
              alpha: (1 - progress) * (0.85 + ambient * 0.15),
            )
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4 + ambient * 2);

      canvas.drawCircle(Offset(x, y), particleSize, paint);

      // Inner glow
      final glowPaint =
          Paint()
            ..color = Colors.white.withValues(alpha: (1 - progress) * 0.5)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

      canvas.drawCircle(Offset(x, y), particleSize * 0.4, glowPaint);
    }
  }

  @override
  bool shouldRepaint(_ParticleBurstPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.ambient != ambient;
  }
}

class _BokehParticlesPainter extends CustomPainter {
  final double progress;
  final double ambient;
  _BokehParticlesPainter({required this.progress, required this.ambient});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Create depth-of-field bokeh particles
    final particles = List.generate(25, (i) {
      final angle = (i * 14.4) * math.pi / 180;
      final distance = 100 + (i % 5) * 80 + ambient * 30;
      final depth = (i % 3) / 3.0;
      return (
        angle: angle,
        distance: distance,
        depth: depth,
        size: 20.0 + (i % 4) * 15,
      );
    });

    for (final particle in particles) {
      final rotatedAngle = particle.angle + progress * math.pi * 0.5;
      final x = center.dx + particle.distance * math.cos(rotatedAngle);
      final y = center.dy + particle.distance * math.sin(rotatedAngle);

      final opacity = (0.15 - particle.depth * 0.1) * (1.0 - progress * 0.7);
      final size =
          particle.size * (1.0 + particle.depth * 0.5) * (1.0 + ambient * 0.2);

      // Bokeh gradient
      final bokehGradient = RadialGradient(
        colors: [
          const Color(0xFF7A3EEB).withValues(alpha: opacity * 0.6),
          const Color(0xFF1FD6C8).withValues(alpha: opacity * 0.3),
          Colors.transparent,
        ],
      );

      final bokehPaint =
          Paint()
            ..shader = bokehGradient.createShader(
              Rect.fromCircle(center: Offset(x, y), radius: size),
            )
            ..maskFilter = MaskFilter.blur(
              BlurStyle.normal,
              5 + particle.depth * 10,
            )
            ..isAntiAlias = true;

      canvas.drawCircle(Offset(x, y), size, bokehPaint);
    }
  }

  @override
  bool shouldRepaint(_BokehParticlesPainter old) =>
      old.progress != progress || old.ambient != ambient;
}

class _EnergyWavesPainter extends CustomPainter {
  final double progress;
  final double ambient;
  _EnergyWavesPainter({required this.progress, required this.ambient});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Create expanding energy waves
    for (int i = 0; i < 4; i++) {
      final waveDelay = i * 0.2;
      final waveProgress = (progress - waveDelay).clamp(0, 1);
      final radius = (200 + i * 80) * waveProgress * (1.0 + ambient * 0.1);

      final waveGradient = RadialGradient(
        colors: [
          const Color(0xFF7A3EEB).withValues(
            alpha: (0.2 - i * 0.04) * waveProgress * (1 - waveProgress),
          ),
          const Color(0xFF1FD6C8).withValues(
            alpha: (0.12 - i * 0.02) * waveProgress * (1 - waveProgress),
          ),
          Colors.transparent,
        ],
        stops: const [0.7, 0.85, 1.0],
      );

      final wavePaint =
          Paint()
            ..shader = waveGradient.createShader(
              Rect.fromCircle(center: center, radius: radius),
            )
            ..isAntiAlias = true;

      canvas.drawCircle(center, radius, wavePaint);
    }
  }

  @override
  bool shouldRepaint(_EnergyWavesPainter old) =>
      old.progress != progress || old.ambient != ambient;
}

// Custom painter for subtle dot pattern texture on tiles
class _DotPatternPainter extends CustomPainter {
  final Color color;
  final double spacing;

  _DotPatternPainter({required this.color, this.spacing = 8});

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.fill;

    for (double x = spacing; x < size.width; x += spacing) {
      for (double y = spacing; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 0.8, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DotPatternPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.spacing != spacing;
  }
}

class _LogoAPainter extends CustomPainter {
  final double progress;
  final double glowIntensity;
  _LogoAPainter({required this.progress, required this.glowIntensity});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    final logoPaint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..isAntiAlias = true
          ..shader = LinearGradient(
            colors: [
              const Color(0xFF7A3EEB).withValues(alpha: progress),
              const Color(0xFF1FD6C8).withValues(alpha: progress * 0.8),
            ],
            stops: const [0.0, 1.0],
          ).createShader(
            Rect.fromCenter(center: center, width: 100, height: 100),
          );

    final path = Path();
    path.moveTo(center.dx - 38, center.dy + 48);
    path.lineTo(center.dx, center.dy - 50);
    path.lineTo(center.dx + 38, center.dy + 48);
    path.moveTo(center.dx - 20, center.dy + 10);
    path.lineTo(center.dx + 20, center.dy + 10);

    canvas.drawPath(path, logoPaint);

    // Accent dot
    final accentPaint =
        Paint()
          ..color = const Color(
            0xFF1FD6C8,
          ).withValues(alpha: progress * 0.8 * glowIntensity)
          ..isAntiAlias = true;

    canvas.drawCircle(
      Offset(center.dx + 32, center.dy - 35),
      7 * progress,
      accentPaint,
    );
  }

  @override
  bool shouldRepaint(_LogoAPainter old) =>
      old.progress != progress || old.glowIntensity != glowIntensity;
}
