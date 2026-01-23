import 'package:flutter/material.dart';
import 'package:finding_buddy/theme/app_theme.dart';

class GridBackgroundPainter extends CustomPainter {
  final double spacing;
  final Color gridColor;
  final double strokeWidth;

  GridBackgroundPainter({
    this.spacing = 40,
    this.gridColor = AppTheme.lightGray,
    this.strokeWidth = 0.5,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = gridColor.withOpacity(0.3)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    // Draw vertical lines
    for (double x = 0; x <= size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Draw horizontal lines
    for (double y = 0; y <= size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class GridBackground extends StatelessWidget {
  final Widget child;
  final double spacing;
  final Color? gridColor;

  const GridBackground({
    super.key,
    required this.child,
    this.spacing = 40,
    this.gridColor,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: GridBackgroundPainter(
              spacing: spacing,
              gridColor: Colors.grey.shade400,
            ),
          ),
        ),
        child,
      ],
    );
  }
}
