import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Realistic Mac-style folder widget for request categorization
/// Features authentic macOS folder aesthetics with 3D depth and paper texture
class MacFolderWidget extends StatefulWidget {
  final String title;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;
  final IconData icon;
  final Color? folderColor;

  const MacFolderWidget({
    Key? key,
    required this.title,
    required this.count,
    required this.isSelected,
    required this.onTap,
    required this.icon,
    this.folderColor,
  }) : super(key: key);

  @override
  State<MacFolderWidget> createState() => _MacFolderWidgetState();
}

class _MacFolderWidgetState extends State<MacFolderWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _hoverController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _liftAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _hoverController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _hoverController, curve: Curves.easeOutCubic),
    );
    _liftAnimation = Tween<double>(begin: 0.0, end: 8.0).animate(
      CurvedAnimation(parent: _hoverController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _hoverController.dispose();
    super.dispose();
  }

  // Get folder colors based on selection and custom color
  Color get _primaryColor {
    if (widget.folderColor != null) return widget.folderColor!;
    return widget.isSelected
        ? const Color(0xFF1E88E5)
        : const Color(0xFF5DADE2);
  }

  Color get _secondaryColor {
    if (widget.folderColor != null) {
      return Color.lerp(widget.folderColor!, Colors.black, 0.15)!;
    }
    return widget.isSelected
        ? const Color(0xFF1565C0)
        : const Color(0xFF3498DB);
  }

  Color get _highlightColor {
    if (widget.folderColor != null) {
      return Color.lerp(widget.folderColor!, Colors.white, 0.3)!;
    }
    return widget.isSelected
        ? const Color(0xFF64B5F6)
        : const Color(0xFF85C1E9);
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) {
        setState(() => _isHovered = true);
        _hoverController.forward();
      },
      onExit: (_) {
        setState(() => _isHovered = false);
        _hoverController.reverse();
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _hoverController,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, -_liftAnimation.value),
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Realistic Folder
                    SizedBox(
                      width: 100,
                      height: 82,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // Shadow layer
                          Positioned(
                            bottom: -4,
                            left: 8,
                            right: 8,
                            child: Container(
                              height: 12,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(
                                      alpha:
                                          0.15 + (_liftAnimation.value * 0.01),
                                    ),
                                    blurRadius: 12 + _liftAnimation.value,
                                    spreadRadius: -2,
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Back folder panel (creates depth)
                          Positioned(
                            top: 8,
                            left: 2,
                            right: 2,
                            bottom: 0,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    _secondaryColor.withValues(alpha: 0.6),
                                    _secondaryColor.withValues(alpha: 0.8),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),

                          // Folder tab (the iconic tab at top-left)
                          Positioned(
                            top: 0,
                            left: 0,
                            child: CustomPaint(
                              size: const Size(42, 18),
                              painter: _FolderTabPainter(
                                color: _highlightColor,
                                secondaryColor: _primaryColor,
                              ),
                            ),
                          ),

                          // Main folder body
                          Positioned(
                            top: 12,
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    _highlightColor,
                                    _primaryColor,
                                    _secondaryColor,
                                  ],
                                  stops: const [0.0, 0.3, 1.0],
                                ),
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(3),
                                  topRight: Radius.circular(10),
                                  bottomLeft: Radius.circular(10),
                                  bottomRight: Radius.circular(10),
                                ),
                                border: Border.all(
                                  color: _secondaryColor.withValues(alpha: 0.5),
                                  width: 0.5,
                                ),
                              ),
                              child: Stack(
                                children: [
                                  // Top shine/reflection
                                  Positioned(
                                    top: 0,
                                    left: 0,
                                    right: 0,
                                    height: 28,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            Colors.white.withValues(
                                              alpha: 0.35,
                                            ),
                                            Colors.white.withValues(alpha: 0.1),
                                            Colors.transparent,
                                          ],
                                        ),
                                        borderRadius: const BorderRadius.only(
                                          topRight: Radius.circular(10),
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Paper texture simulation
                                  Positioned.fill(
                                    child: CustomPaint(
                                      painter: _PaperTexturePainter(
                                        color: Colors.white.withValues(
                                          alpha: 0.03,
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Folder crease line
                                  Positioned(
                                    top: 8,
                                    left: 8,
                                    right: 8,
                                    child: Container(
                                      height: 1,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.transparent,
                                            Colors.white.withValues(alpha: 0.2),
                                            Colors.white.withValues(alpha: 0.2),
                                            Colors.transparent,
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Icon centered
                                  Center(
                                    child: Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Icon(
                                        widget.icon,
                                        color: Colors.white.withValues(
                                          alpha: 0.95,
                                        ),
                                        size: 26,
                                        shadows: [
                                          Shadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.2,
                                            ),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),

                                  // Bottom edge shadow
                                  Positioned(
                                    bottom: 0,
                                    left: 0,
                                    right: 0,
                                    height: 8,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            Colors.transparent,
                                            Colors.black.withValues(
                                              alpha: 0.08,
                                            ),
                                          ],
                                        ),
                                        borderRadius: const BorderRadius.only(
                                          bottomLeft: Radius.circular(10),
                                          bottomRight: Radius.circular(10),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Count badge
                          Positioned(
                            top: -6,
                            right: -6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Color(0xFFFF6B6B),
                                    Color(0xFFEE5A5A),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFFEF4444,
                                    ).withValues(alpha: 0.4),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Text(
                                widget.count.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),

                          // Selection indicator
                          if (widget.isSelected)
                            Positioned(
                              bottom: 4,
                              left: 0,
                              right: 0,
                              child: Center(
                                child: Container(
                                  width: 24,
                                  height: 3,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    borderRadius: BorderRadius.circular(2),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.white.withValues(
                                          alpha: 0.5,
                                        ),
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Label
                    Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            widget.isSelected
                                ? FontWeight.w700
                                : FontWeight.w600,
                        color:
                            widget.isSelected
                                ? _primaryColor
                                : const Color(0xFF64748B),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Custom painter for the folder tab shape
class _FolderTabPainter extends CustomPainter {
  final Color color;
  final Color secondaryColor;

  _FolderTabPainter({required this.color, required this.secondaryColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [color, secondaryColor],
          ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path =
        Path()
          ..moveTo(0, size.height)
          ..lineTo(0, 6)
          ..quadraticBezierTo(0, 0, 6, 0)
          ..lineTo(size.width - 12, 0)
          ..quadraticBezierTo(size.width - 6, 0, size.width - 4, 4)
          ..quadraticBezierTo(
            size.width,
            size.height * 0.6,
            size.width,
            size.height,
          )
          ..close();

    canvas.drawPath(path, paint);

    // Add highlight
    final highlightPaint =
        Paint()
          ..color = Colors.white.withValues(alpha: 0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1;

    final highlightPath =
        Path()
          ..moveTo(2, size.height - 2)
          ..lineTo(2, 6)
          ..quadraticBezierTo(2, 2, 6, 2)
          ..lineTo(size.width - 14, 2);

    canvas.drawPath(highlightPath, highlightPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Custom painter for subtle paper texture
class _PaperTexturePainter extends CustomPainter {
  final Color color;

  _PaperTexturePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(42);
    final paint = Paint()..color = color;

    for (int i = 0; i < 30; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      canvas.drawCircle(Offset(x, y), 0.5 + random.nextDouble(), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Container widget to display folder navigation
class MacFolderNavigation extends StatelessWidget {
  final String selectedFilter;
  final Function(String) onFilterChanged;
  final int pendingCount;
  final int acceptedCount;
  final int rejectedCount;
  final bool
  useApprovedLabel; // For leave requests: "Approved" vs OD: "Accepted"

  const MacFolderNavigation({
    Key? key,
    required this.selectedFilter,
    required this.onFilterChanged,
    required this.pendingCount,
    required this.acceptedCount,
    required this.rejectedCount,
    this.useApprovedLabel = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final acceptedLabel = useApprovedLabel ? 'Approved' : 'Accepted';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white, const Color(0xFFF8FAFC)],
        ),
        border: const Border(
          bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          MacFolderWidget(
            title: 'Pending',
            count: pendingCount,
            isSelected: selectedFilter == 'Pending',
            onTap: () => onFilterChanged('Pending'),
            icon: Icons.schedule_rounded,
            folderColor: const Color(0xFFF59E0B),
          ),
          MacFolderWidget(
            title: acceptedLabel,
            count: acceptedCount,
            isSelected: selectedFilter == acceptedLabel,
            onTap: () => onFilterChanged(acceptedLabel),
            icon: Icons.check_circle_rounded,
            folderColor: const Color(0xFF10B981),
          ),
          MacFolderWidget(
            title: 'Rejected',
            count: rejectedCount,
            isSelected: selectedFilter == 'Rejected',
            onTap: () => onFilterChanged('Rejected'),
            icon: Icons.cancel_rounded,
            folderColor: const Color(0xFFEF4444),
          ),
        ],
      ),
    );
  }
}
