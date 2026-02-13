import 'dart:math';
import 'package:flutter/material.dart';

class SuccessAnimation extends StatefulWidget {
  final double size;
  final VoidCallback? onCompleted;
  final bool fullScreenConfetti;

  const SuccessAnimation({
    super.key,
    this.size = 100,
    this.onCompleted,
    this.fullScreenConfetti = false,
  });

  @override
  State<SuccessAnimation> createState() => _SuccessAnimationState();
}

class _SuccessAnimationState extends State<SuccessAnimation>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _checkAnimation;
  late Animation<double> _circleAnimation;

  final List<Particle> _particles = [];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _circleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.elasticOut),
      ),
    );

    _checkAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 0.6, curve: Curves.easeOutCubic),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _controller.addListener(() {
      if (_controller.value > 0.4 && _particles.isEmpty) {
        _generateParticles();
      }
      if (_particles.isNotEmpty) {
        _updateParticles();
      }
    });

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (widget.onCompleted != null) {
          widget.onCompleted!();
        }
      }
    });

    _controller.forward();
  }

  void _generateParticles() {
    final random = Random();
    for (int i = 0; i < 30; i++) {
      _particles.add(
        Particle(
          angle: random.nextDouble() * 2 * pi,
          distance: 0,
          speed: random.nextDouble() * 3 + 2,
          size: random.nextDouble() * 4 + 2,
          color: Colors.primaries[random.nextInt(Colors.primaries.length)],
        ),
      );
    }
  }

  void _updateParticles() {
    for (var particle in _particles) {
      particle.distance += particle.speed;
      particle.speed *= 0.95; // friction
      particle.size *= 0.98; // fade out size
    }
    setState(() {});
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: SizedBox(
        width: widget.size * (widget.fullScreenConfetti ? 3 : 1.5),
        height: widget.size * (widget.fullScreenConfetti ? 3 : 1.5),
        child: CustomPaint(
          painter: _SuccessPainter(
            progress: _controller.value,
            checkProgress: _checkAnimation.value,
            circleProgress: _circleAnimation.value,
            particles: _particles,
            primaryColor: const Color(0xFF10B981),
          ),
        ),
      ),
    );
  }
}

class Particle {
  double angle;
  double distance;
  double speed;
  double size;
  Color color;

  Particle({
    required this.angle,
    required this.distance,
    required this.speed,
    required this.size,
    required this.color,
  });
}

class _SuccessPainter extends CustomPainter {
  final double progress;
  final double checkProgress;
  final double circleProgress;
  final List<Particle> particles;
  final Color primaryColor;

  _SuccessPainter({
    required this.progress,
    required this.checkProgress,
    required this.circleProgress,
    required this.particles,
    required this.primaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 4; // Adjust size logic

    // Draw Circle
    if (circleProgress > 0) {
      final circlePaint =
          Paint()
            ..color = primaryColor
            ..style = PaintingStyle.fill;

      canvas.drawCircle(center, radius * circleProgress, circlePaint);
    }

    // Draw Checkmark
    if (checkProgress > 0) {
      final checkPath = Path();
      final start = Offset(center.dx - radius * 0.4, center.dy);
      final mid = Offset(center.dx - radius * 0.1, center.dy + radius * 0.3);
      final end = Offset(center.dx + radius * 0.4, center.dy - radius * 0.3);

      checkPath.moveTo(start.dx, start.dy);
      checkPath.lineTo(mid.dx, mid.dy);
      checkPath.lineTo(end.dx, end.dy);

      // Animate path drawing
      final pathMetrics = checkPath.computeMetrics().first;
      final extractPath = pathMetrics.extractPath(
        0.0,
        pathMetrics.length * checkProgress,
      );

      final checkPaint =
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = radius * 0.15
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round;

      canvas.drawPath(extractPath, checkPaint);
    }

    // Draw Confetti Particles
    for (var particle in particles) {
      if (particle.size > 0.5) {
        final x =
            center.dx + cos(particle.angle) * (radius + particle.distance);
        final y =
            center.dy + sin(particle.angle) * (radius + particle.distance);

        final particlePaint = Paint()..color = particle.color;
        canvas.drawCircle(Offset(x, y), particle.size, particlePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SuccessPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.particles != particles;
  }
}
