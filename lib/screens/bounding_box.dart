import 'dart:math';

import 'package:flutter/material.dart';
import 'package:finding_buddy/models/detected_object/detected_object_dm.dart';

/// Real-time bounding box overlay for live camera detection
class BoundingBoxOverlay extends StatelessWidget {
  final List<DetectedObjectDm> detections;
  final Size cameraSize;
  final String? targetObject;

  const BoundingBoxOverlay({
    super.key,
    required this.detections,
    required this.cameraSize,
    this.targetObject,
  });

  @override
  Widget build(BuildContext context) {
    if (detections.isEmpty) return const SizedBox.shrink();

    return CustomPaint(
      size: Size.infinite,
      painter: _RealtimeBoundingBoxPainter(
        detections: detections,
        cameraSize: cameraSize,
        targetObject: targetObject,
      ),
    );
  }
}

class _RealtimeBoundingBoxPainter extends CustomPainter {
  final List<DetectedObjectDm> detections;
  final Size cameraSize;
  final String? targetObject;

  _RealtimeBoundingBoxPainter({
    required this.detections,
    required this.cameraSize,
    this.targetObject,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Calculate scale from camera size to display size
    final scaleX = size.width / cameraSize.width;
    final scaleY = size.height / cameraSize.height;

    for (int i = 0; i < detections.length; i++) {
      final detection = detections[i];
      final location = detection.location;

      // Check if this is the target object
      final isTarget =
          targetObject != null &&
          detection.label.toLowerCase() == targetObject?.toLowerCase();

      // Scale bounding box
      final left = location.left * scaleX;
      final top = location.top * scaleY;
      final right = location.right * scaleX;
      final bottom = location.bottom * scaleY;

      final rect = Rect.fromLTRB(left, top, right, bottom);

      // Draw bounding box - THICKER for target object
      final boxPaint = Paint()
        ..color = isTarget ? Colors.green : _getColorForIndex(i)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isTarget ? 5.0 : 3.0;

      canvas.drawRect(rect, boxPaint);

      // Draw corner markers for better visibility
      _drawCornerMarkers(canvas, rect, boxPaint.color);

      // Draw label background
      final labelBgPaint = Paint()
        ..color = isTarget
            ? Colors.green.withOpacity(0.9)
            : _getColorForIndex(i).withOpacity(0.9)
        ..style = PaintingStyle.fill;

      // Label text
      final labelText = isTarget
          ? '${detection.label} - ${detection.distanceString}'
          : '${detection.label} ${(detection.score * 100).toStringAsFixed(0)}%';

      final textSpan = TextSpan(
        text: labelText,
        style: TextStyle(
          color: Colors.white,
          fontSize: isTarget ? 18 : 14,
          fontWeight: isTarget ? FontWeight.bold : FontWeight.w600,
        ),
      );

      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );

      textPainter.layout();

      // Label background rect
      final labelRect = Rect.fromLTWH(
        left,
        top - textPainter.height - 10,
        textPainter.width + 16,
        textPainter.height + 10,
      );

      canvas.drawRRect(
        RRect.fromRectAndRadius(labelRect, const Radius.circular(4)),
        labelBgPaint,
      );

      // Draw label text
      textPainter.paint(canvas, Offset(left + 8, top - textPainter.height - 5));

      // For target object, draw direction indicator
      if (isTarget) {
        _drawDirectionIndicator(canvas, size, detection);
      }
    }
  }

  /// Draw corner markers for box
  void _drawCornerMarkers(Canvas canvas, Rect rect, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    const cornerLength = 20.0;

    // Top-left corner
    canvas.drawLine(
      Offset(rect.left, rect.top),
      Offset(rect.left + cornerLength, rect.top),
      paint,
    );
    canvas.drawLine(
      Offset(rect.left, rect.top),
      Offset(rect.left, rect.top + cornerLength),
      paint,
    );

    // Top-right corner
    canvas.drawLine(
      Offset(rect.right, rect.top),
      Offset(rect.right - cornerLength, rect.top),
      paint,
    );
    canvas.drawLine(
      Offset(rect.right, rect.top),
      Offset(rect.right, rect.top + cornerLength),
      paint,
    );

    // Bottom-left corner
    canvas.drawLine(
      Offset(rect.left, rect.bottom),
      Offset(rect.left + cornerLength, rect.bottom),
      paint,
    );
    canvas.drawLine(
      Offset(rect.left, rect.bottom),
      Offset(rect.left, rect.bottom - cornerLength),
      paint,
    );

    // Bottom-right corner
    canvas.drawLine(
      Offset(rect.right, rect.bottom),
      Offset(rect.right - cornerLength, rect.bottom),
      paint,
    );
    canvas.drawLine(
      Offset(rect.right, rect.bottom),
      Offset(rect.right, rect.bottom - cornerLength),
      paint,
    );
  }

  /// Draw direction indicator (arrow from center to object)
  void _drawDirectionIndicator(
    Canvas canvas,
    Size screenSize,
    DetectedObjectDm detection,
  ) {
    final screenCenter = Offset(screenSize.width / 2, screenSize.height / 2);
    final scaleX = screenSize.width / cameraSize.width;
    final scaleY = screenSize.height / cameraSize.height;

    final objectCenter = Offset(
      detection.center.dx * scaleX,
      detection.center.dy * scaleY,
    );

    // Draw arrow from screen center to object
    final arrowPaint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(screenCenter, objectCenter, arrowPaint);

    // Draw arrowhead
    _drawArrowhead(canvas, screenCenter, objectCenter, arrowPaint);

    // Draw distance text at midpoint
    final midpoint = Offset(
      (screenCenter.dx + objectCenter.dx) / 2,
      (screenCenter.dy + objectCenter.dy) / 2,
    );

    final distanceText = TextSpan(
      text: detection.distanceString,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.bold,
        shadows: [Shadow(color: Colors.black, blurRadius: 4)],
      ),
    );

    final textPainter = TextPainter(
      text: distanceText,
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        midpoint.dx - textPainter.width / 2,
        midpoint.dy - textPainter.height / 2,
      ),
    );
  }

  /// Draw arrowhead
  void _drawArrowhead(Canvas canvas, Offset start, Offset end, Paint paint) {
    const arrowSize = 15.0;
    final angle = (end - start).direction;

    final arrowPoint1 = Offset(
      end.dx - arrowSize * cos(angle - 0.5),
      end.dy - arrowSize * sin(angle - 0.5),
    );

    final arrowPoint2 = Offset(
      end.dx - arrowSize * cos(angle + 0.5),
      end.dy - arrowSize * sin(angle + 0.5),
    );

    final path = Path()
      ..moveTo(end.dx, end.dy)
      ..lineTo(arrowPoint1.dx, arrowPoint1.dy)
      ..moveTo(end.dx, end.dy)
      ..lineTo(arrowPoint2.dx, arrowPoint2.dy);

    canvas.drawPath(path, paint);
  }

  Color _getColorForIndex(int index) {
    final colors = [
      Colors.blue,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
      Colors.pink,
      Colors.cyan,
      Colors.amber,
    ];
    return colors[index % colors.length];
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
