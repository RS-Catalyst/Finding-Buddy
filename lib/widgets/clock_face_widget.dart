import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:finding_buddy/theme/app_theme.dart';

class ClockFaceWidget extends StatelessWidget {
  const ClockFaceWidget({
    super.key,
    required this.activeHour,
    this.size = 180,
    this.showDirection = true,
  });

  final int activeHour;
  final double size;
  final bool showDirection;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: ClockFacePainter(
          activeHour: activeHour,
          primaryColor: AppTheme.primaryTeal,
        ),
        child: showDirection
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Transform.rotate(
                      angle: _getAngleForHour(activeHour),
                      child: Icon(
                        Icons.navigation,
                        color: AppTheme.primaryTeal,
                        size: size * 0.22,
                      ),
                    ),
                    SizedBox(height: size * 0.04),
                    Text(
                      "$activeHour o'clock",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: size * 0.12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              )
            : null,
      ),
    );
  }

  double _getAngleForHour(int hour) {
    // Convert clock hour to radians
    // 12 o'clock = 0 degrees (top)
    // 3 o'clock = 90 degrees (right)
    // etc.
    final normalizedHour = hour % 12;
    return (normalizedHour * 30) * math.pi / 180;
  }
}

class ClockFacePainter extends CustomPainter {
  ClockFacePainter({required this.activeHour, required this.primaryColor});

  final int activeHour;
  final Color primaryColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Draw outer ring with gradient
    final outerRingPaint = Paint()
      ..shader = RadialGradient(
        colors: [primaryColor.withOpacity(0.3), Colors.transparent],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, outerRingPaint);

    // Draw border
    final borderPaint = Paint()
      ..color = primaryColor.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(center, radius - 2, borderPaint);

    // Draw hour markers
    for (int i = 0; i < 12; i++) {
      final isActive = (i == 0 ? 12 : i) == activeHour;
      final angle = (i * 30 - 90) * math.pi / 180;
      final markerRadius = radius * 0.78;

      final markerCenter = Offset(
        center.dx + markerRadius * math.cos(angle),
        center.dy + markerRadius * math.sin(angle),
      );

      final markerPaint = Paint()
        ..color = isActive ? primaryColor : Colors.white.withOpacity(0.5);

      final markerSize = isActive ? 10.0 : 6.0;
      canvas.drawCircle(markerCenter, markerSize / 2, markerPaint);

      // Draw glow for active marker
      if (isActive) {
        final glowPaint = Paint()
          ..color = primaryColor.withOpacity(0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
        canvas.drawCircle(markerCenter, markerSize, glowPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant ClockFacePainter oldDelegate) {
    return oldDelegate.activeHour != activeHour;
  }
}
