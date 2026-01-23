import 'dart:ui';
import 'package:finding_buddy/models/detected_object/detected_object_dm.dart';
import 'package:flutter/material.dart';
import 'package:finding_buddy/theme/app_theme.dart';

class BoxWidget extends StatelessWidget {
  const BoxWidget({
    super.key,
    required this.label,
    required this.score,
    this.width,
    this.height,
    this.color,
  });

  final String label;
  final double score;
  final double? width;
  final double? height;
  final Color? color;

  factory BoxWidget.fromDetection(
    DetectedObjectDm detection, {
    required Size screenSize,
    required Size imageSize,
    bool isFrontCamera = false,
    Color? color,
  }) {
    final rect = detection.getScaledLocation(
      screenSize: screenSize,
      imageSize: imageSize,
      isFrontCamera: isFrontCamera,
    );

    return BoxWidget(
      label: detection.label,
      score: detection.score,
      width: rect.width,
      height: rect.height,
      color: color,
    );
  }

  @override
  Widget build(BuildContext context) {
    final boxColor = color ?? AppTheme.primaryTeal;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        border: Border.all(color: boxColor, width: 3),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: boxColor.withOpacity(0.3),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Align(
        alignment: Alignment.topLeft,
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(5),
            bottomRight: Radius.circular(8),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
            child: Container(
              color: boxColor.withOpacity(0.8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      label.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${(score * 100).toInt()}%',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
