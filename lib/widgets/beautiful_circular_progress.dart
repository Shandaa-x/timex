import 'package:flutter/material.dart';
import 'dart:math' as math;

class BeautifulCircularProgress extends StatefulWidget {
  final double size;
  final double strokeWidth;
  final List<Color> gradientColors;
  final Color backgroundColor;
  final Duration animationDuration;
  final Color? centerGlowColor;
  final double? centerGlowSize;
  final bool showCenterGlow;
  final Widget? centerChild;

  const BeautifulCircularProgress({
    super.key,
    this.size = 80.0,
    this.strokeWidth = 4.0,
    this.gradientColors = const [
      Color(0xFF8B5CF6),
      Color(0xFFA78BFA),
      Color(0xFFC084FC),
      Color(0xFFE879F9),
    ],
    this.backgroundColor = const Color(0x33000000),
    this.animationDuration = const Duration(seconds: 2),
    this.centerGlowColor,
    this.centerGlowSize,
    this.showCenterGlow = true,
    this.centerChild,
  });

  @override
  State<BeautifulCircularProgress> createState() =>
      _BeautifulCircularProgressState();
}

class _BeautifulCircularProgressState extends State<BeautifulCircularProgress>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _rotationAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );

    // Smooth rotation animation with custom curve
    _rotationAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.linear),
    );

    // Pulsing animation for center glow
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _animationController.repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              // Background circle
              Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.backgroundColor,
                ),
              ),

              // Rotating gradient progress indicator
              Transform.rotate(
                angle: _rotationAnimation.value * 2 * math.pi,
                child: CustomPaint(
                  size: Size(widget.size, widget.size),
                  painter: GradientCircularProgressPainter(
                    strokeWidth: widget.strokeWidth,
                    gradientColors: widget.gradientColors,
                    progress: 0.75, // 3/4 circle for visual appeal
                  ),
                ),
              ),

              // Glossy shine effect
              Transform.rotate(
                angle: (_rotationAnimation.value * 2 * math.pi) + (math.pi / 2),
                child: CustomPaint(
                  size: Size(widget.size, widget.size),
                  painter: ShineEffectPainter(
                    strokeWidth: widget.strokeWidth,
                    shinePosition: _rotationAnimation.value,
                  ),
                ),
              ),

              // Center glow effect
              if (widget.showCenterGlow)
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    final glowSize =
                        (widget.centerGlowSize ?? widget.size * 0.3) *
                        _pulseAnimation.value;
                    return Container(
                      width: glowSize,
                      height: glowSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color:
                                (widget.centerGlowColor ??
                                        widget.gradientColors.first)
                                    .withOpacity(0.6),
                            blurRadius: glowSize * 0.3,
                            spreadRadius: glowSize * 0.1,
                          ),
                        ],
                      ),
                    );
                  },
                ),

              // Center child widget
              if (widget.centerChild != null)
                ScaleTransition(
                  scale: _pulseAnimation,
                  child: widget.centerChild!,
                ),
            ],
          );
        },
      ),
    );
  }
}

class GradientCircularProgressPainter extends CustomPainter {
  final double strokeWidth;
  final List<Color> gradientColors;
  final double progress;

  GradientCircularProgressPainter({
    required this.strokeWidth,
    required this.gradientColors,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Create gradient shader
    final gradient = SweepGradient(
      colors: gradientColors,
      stops: List.generate(
        gradientColors.length,
        (index) => index / (gradientColors.length - 1),
      ),
      startAngle: 0,
      endAngle: 2 * math.pi,
    );

    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Draw the arc
    canvas.drawArc(
      rect,
      -math.pi / 2, // Start from top
      2 * math.pi * progress, // Draw 3/4 circle
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class ShineEffectPainter extends CustomPainter {
  final double strokeWidth;
  final double shinePosition;

  ShineEffectPainter({required this.strokeWidth, required this.shinePosition});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Create shine effect
    final shinePaint = Paint()
      ..color = Colors.white.withOpacity(0.8)
      ..strokeWidth = strokeWidth * 0.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Calculate shine position
    final shineAngle = shinePosition * 2 * math.pi;
    final shineLength = math.pi / 8; // Length of shine effect

    final rect = Rect.fromCircle(center: center, radius: radius);

    // Draw shine effect
    canvas.drawArc(
      rect,
      shineAngle - shineLength / 2,
      shineLength,
      false,
      shinePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// Preset configurations for common use cases
class BeautifulCircularProgressPresets {
  static const BeautifulCircularProgress small = BeautifulCircularProgress(
    size: 40,
    strokeWidth: 3,
  );

  static const BeautifulCircularProgress medium = BeautifulCircularProgress(
    size: 60,
    strokeWidth: 4,
  );

  static const BeautifulCircularProgress large = BeautifulCircularProgress(
    size: 100,
    strokeWidth: 6,
  );

  static BeautifulCircularProgress purple({double size = 80}) =>
      BeautifulCircularProgress(
        size: size,
        gradientColors: const [
          Color(0xFF8B5CF6),
          Color(0xFFA78BFA),
          Color(0xFFC084FC),
        ],
      );

  static BeautifulCircularProgress blue({double size = 80}) =>
      BeautifulCircularProgress(
        size: size,
        gradientColors: const [
          Color(0xFF3B82F6),
          Color(0xFF60A5FA),
          Color(0xFF93C5FD),
        ],
      );

  static BeautifulCircularProgress green({double size = 80}) =>
      BeautifulCircularProgress(
        size: size,
        gradientColors: const [
          Color(0xFF10B981),
          Color(0xFF34D399),
          Color(0xFF6EE7B7),
        ],
      );
}
