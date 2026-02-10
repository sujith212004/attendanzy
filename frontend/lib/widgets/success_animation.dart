import 'dart:math';
import 'package:flutter/material.dart';

class SuccessAnimation extends StatefulWidget {
  final double size;
  final Duration duration;
  final VoidCallback? onCompleted;
  final bool fullScreenConfetti;

  const SuccessAnimation({
    Key? key,
    this.size = 180,
    this.duration = const Duration(milliseconds: 1200),
    this.onCompleted,
    this.fullScreenConfetti = false,
  }) : super(key: key);

  @override
  State<SuccessAnimation> createState() => _SuccessAnimationState();
}

class _SuccessAnimationState extends State<SuccessAnimation>
    with TickerProviderStateMixin {
  late final AnimationController _mainController;
  late final AnimationController _decorController;

  late final Animation<double> _scaleAnim;
  late final Animation<double> _checkAnim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();

    _mainController = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Future.delayed(const Duration(milliseconds: 700), () {
          if (mounted) widget.onCompleted?.call();
        });
      }
    });

    _decorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    // Enhanced bounce for circle
    _scaleAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.65, curve: Curves.elasticOut),
      ),
    );

    // Smoother check mark drawing
    _checkAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.55, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    // Quicker decorative elements fade
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.25, 0.75, curve: Curves.easeOutQuad),
      ),
    );

    _mainController.forward();
  }

  @override
  void dispose() {
    _mainController.dispose();
    _decorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size * 1.8,
      height: widget.size * 1.8,
      child: AnimatedBuilder(
        animation: Listenable.merge([_mainController, _decorController]),
        builder: (context, child) {
          return CustomPaint(
            size: Size(widget.size * 1.8, widget.size * 1.8),
            painter: _ModernSuccessPainter(
              scaleProgress: _scaleAnim.value,
              checkProgress: _checkAnim.value,
              fadeProgress: _fadeAnim.value,
              decorProgress: _decorController.value,
              size: widget.size,
            ),
          );
        },
      ),
    );
  }
}

// Duplicate simple painter removed — using the enhanced _ModernSuccessPainter implementation below.

class _ModernSuccessPainter extends CustomPainter {
  final double scaleProgress;
  final double checkProgress;
  final double fadeProgress;
  final double decorProgress;
  final double size;

  _ModernSuccessPainter({
    required this.scaleProgress,
    required this.checkProgress,
    required this.fadeProgress,
    required this.decorProgress,
    required this.size,
  });

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final center = Offset(canvasSize.width / 2, canvasSize.height / 2);
    final radius = size / 2;

    _drawDecorativeElements(
      canvas,
      center,
      radius,
      fadeProgress,
      decorProgress,
    );
    _drawMainCircle(canvas, center, radius * scaleProgress);
    if (checkProgress > 0) {
      _drawCheckmark(canvas, center, radius * 0.7, checkProgress);
    }
  }

  void _drawDecorativeElements(
    Canvas canvas,
    Offset center,
    double radius,
    double fade,
    double pulse,
  ) {
    if (fade <= 0) return;

    final baseOpacity = fade * 0.65;
    final pulseOffset = pulse * 6; // Reduced for subtler movement

    // Single paint object for all circles (optimization)
    final circlePaint =
        Paint()
          ..color = const Color(0xFF0EA5E9).withOpacity(baseOpacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.8
          ..isAntiAlias = true;

    // Draw circles with slight scale variation (reduced size)
    canvas.drawCircle(
      Offset(
        center.dx + radius * 1.4 + pulseOffset,
        center.dy - radius * 1.3 - pulseOffset,
      ),
      6 * (1 + pulse * 0.12),
      circlePaint,
    );
    canvas.drawCircle(
      Offset(center.dx - radius * 1.5 - pulseOffset, center.dy - radius * 0.1),
      5 * (1 + pulse * 0.1),
      circlePaint,
    );
    canvas.drawCircle(
      Offset(center.dx + radius * 1.5, center.dy + radius * 1.4 + pulseOffset),
      5.5 * (1 + pulse * 0.11),
      circlePaint,
    );
    canvas.drawCircle(
      Offset(center.dx + radius * 1.6 + pulseOffset, center.dy + radius * 0.5),
      5 * (1 + pulse * 0.08),
      circlePaint,
    );
    canvas.drawCircle(
      Offset(center.dx - radius * 0.6 - pulseOffset, center.dy + radius * 1.5),
      7 * (1 + pulse * 0.12),
      circlePaint,
    );

    // Plus signs with smooth animation
    final plusPaint =
        Paint()
          ..color = const Color(0xFF0EA5E9).withOpacity(baseOpacity * 0.9)
          ..strokeWidth = 2.8
          ..strokeCap = StrokeCap.round
          ..isAntiAlias = true;

    // Reduced plus sign size
    final plusScale = 1 + pulse * 0.15;
    _drawPlus(
      canvas,
      Offset(center.dx - radius * 1.3 + pulseOffset, center.dy - radius * 1.6),
      10 * plusScale,
      plusPaint,
    );
    _drawPlus(
      canvas,
      Offset(center.dx + radius * 1.4 - pulseOffset, center.dy + radius * 1.2),
      10 * plusScale,
      plusPaint,
    );

    // Optimized ellipse paint
    final ellipsePaint = Paint()..isAntiAlias = true;

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(
          center.dx + radius * 1.3 + pulseOffset,
          center.dy - radius * 0.8,
        ),
        width: 180,
        height: 140,
      ),
      ellipsePaint..color = const Color(0xFFDCEEFE).withOpacity(fade * 0.42),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(
          center.dx - radius * 1.1 - pulseOffset,
          center.dy + radius * 0.9,
        ),
        width: 160,
        height: 120,
      ),
      ellipsePaint..color = const Color(0xFFDCEEFE).withOpacity(fade * 0.35),
    );
  }

  void _drawRotatedBlob(
    Canvas canvas,
    double cx,
    double cy,
    double w,
    double h,
    double r,
    double angle,
    Paint paint,
  ) {
    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(angle);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: w, height: h),
        Radius.circular(r),
      ),
      paint,
    );
    canvas.restore();
  }

  void _drawPlus(Canvas canvas, Offset position, double size, Paint paint) {
    canvas.drawLine(
      Offset(position.dx, position.dy - size / 2),
      Offset(position.dx, position.dy + size / 2),
      paint,
    );
    canvas.drawLine(
      Offset(position.dx - size / 2, position.dy),
      Offset(position.dx + size / 2, position.dy),
      paint,
    );
  }

  void _drawMainCircle(Canvas canvas, Offset center, double radius) {
    if (radius <= 0) return;

    final rect = Rect.fromCircle(center: center, radius: radius);

    // Enhanced gradient with better color distribution
    final gradient = RadialGradient(
      center: const Alignment(-0.3, -0.3),
      colors: const [
        Color(0xFF38BDF8), // Light blue
        Color(0xFF0EA5E9), // Sky blue
        Color(0xFF0284C7), // Deeper blue
      ],
      stops: const [0.0, 0.55, 1.0],
    );

    final circlePaint =
        Paint()
          ..shader = gradient.createShader(rect)
          ..isAntiAlias = true;

    canvas.drawCircle(center, radius, circlePaint);

    // Subtle glow effect
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = const Color(0xFF38BDF8).withOpacity(0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8)
        ..isAntiAlias = true,
    );

    // Enhanced highlight
    final highlightGradient = RadialGradient(
      center: const Alignment(-0.5, -0.5),
      radius: 0.5,
      colors: [
        Colors.white.withOpacity(0.45),
        Colors.white.withOpacity(0.15),
        Colors.transparent,
      ],
    );

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = highlightGradient.createShader(rect)
        ..isAntiAlias = true,
    );
  }

  void _drawCheckmark(
    Canvas canvas,
    Offset center,
    double radius,
    double progress,
  ) {
    final path =
        Path()
          ..moveTo(center.dx - radius * 0.35, center.dy - radius * 0.05)
          ..lineTo(center.dx - radius * 0.08, center.dy + radius * 0.28)
          ..lineTo(center.dx + radius * 0.42, center.dy - radius * 0.25);

    final metrics = path.computeMetrics().first;
    final extractedPath = metrics.extractPath(0, metrics.length * progress);

    // Enhanced glow effect
    canvas.drawPath(
      extractedPath,
      Paint()
        ..color = Colors.white.withOpacity(0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 15
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5)
        ..isAntiAlias = true,
    );

    // Main checkmark with perfect anti-aliasing
    canvas.drawPath(
      extractedPath,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(covariant _ModernSuccessPainter oldDelegate) {
    return oldDelegate.scaleProgress != scaleProgress ||
        oldDelegate.checkProgress != checkProgress ||
        oldDelegate.fadeProgress != fadeProgress ||
        oldDelegate.decorProgress != decorProgress;
  }
}
