import 'dart:math';
import 'dart:ui';

class ClockFaceCalculator {
  ClockFaceCalculator._();

  /// Calculate clock position (1-12) based on object center in image
  /// Returns the clock hour where the object is located
  static int calculateClockPosition(Offset objectCenter, Size imageSize) {
    // Calculate center of the image
    final imageCenter = Offset(imageSize.width / 2, imageSize.height / 2);

    // Calculate vector from image center to object center
    final dx = objectCenter.dx - imageCenter.dx;
    final dy = objectCenter.dy - imageCenter.dy;

    // Calculate angle in radians (0 = right, π/2 = down, π = left, 3π/2 = up)
    final double angle = atan2(dy, dx);

    // Convert to degrees
    double degrees = angle * (180 / pi);

    // Adjust so 0° is at the top (12 o'clock)
    // Original: 0° = right (3 o'clock)
    // We want: 0° = top (12 o'clock)
    degrees = degrees + 90;

    // Normalize to 0-360 range
    if (degrees < 0) degrees += 360;

    // Convert degrees to clock hours (12 divisions)
    // 360° / 12 = 30° per hour
    int clockHour = ((degrees / 30).round()) % 12;
    if (clockHour == 0) clockHour = 12;

    return clockHour;
  }

  /// Estimate distance based on bounding box size
  /// Uses the principle: larger box = closer object
  /// Returns estimated distance in meters
  static double estimateDistance({
    required Rect boundingBox,
    required Size imageSize,
    double referenceWidth = 640.0, // Model input size
  }) {
    // Calculate bounding box dimensions
    final boxWidth = boundingBox.width;
    final boxHeight = boundingBox.height;

    // Calculate box area as percentage of image
    final boxArea = boxWidth * boxHeight;
    final imageArea = imageSize.width * imageSize.height;
    final areaPercentage = boxArea / imageArea;

    // Distance estimation based on area percentage
    // This is a heuristic calibration:
    // - 40%+ coverage = Very close (< 0.5m)
    // - 20-40% coverage = Close (0.5-1.0m)
    // - 10-20% coverage = Medium (1.0-2.0m)
    // - 5-10% coverage = Far (2.0-4.0m)
    // - < 5% coverage = Very far (> 4.0m)

    double distance;

    if (areaPercentage >= 0.40) {
      // Very close: 0.3m to 0.5m
      distance = 0.3 + (0.50 - areaPercentage) * 0.4;
    } else if (areaPercentage >= 0.20) {
      // Close: 0.5m to 1.0m
      distance = 0.5 + (0.40 - areaPercentage) * 2.5;
    } else if (areaPercentage >= 0.10) {
      // Medium: 1.0m to 2.5m
      distance = 1.0 + (0.20 - areaPercentage) * 15.0;
    } else if (areaPercentage >= 0.05) {
      // Far: 2.5m to 5.0m
      distance = 2.5 + (0.10 - areaPercentage) * 50.0;
    } else {
      // Very far: 5.0m to 10.0m
      distance = 5.0 + (0.05 - areaPercentage) * 100.0;
    }

    // Clamp distance to reasonable range
    distance = distance.clamp(0.3, 10.0);

    return distance;
  }

  /// Generate guidance message based on clock position and distance
  static String generateGuidanceMessage({
    required int clockPosition,
    required double distance,
    required bool isArabic,
  }) {
    // Direction text
    final String direction = _getDirectionText(clockPosition, isArabic);

    // Distance text
    final String distanceText = _getDistanceText(distance, isArabic);

    if (isArabic) {
      return '$direction، $distanceText';
    } else {
      return '$direction, $distanceText';
    }
  }

  /// Get direction text based on clock position
  static String _getDirectionText(int clockPosition, bool isArabic) {
    if (isArabic) {
      switch (clockPosition) {
        case 12:
          return 'مباشرة أمامك';
        case 1:
          return 'أمامك قليلاً إلى اليمين';
        case 2:
          return 'إلى اليمين الأمامي';
        case 3:
          return 'إلى اليمين';
        case 4:
          return 'إلى اليمين الخلفي';
        case 5:
          return 'خلفك قليلاً إلى اليمين';
        case 6:
          return 'مباشرة خلفك';
        case 7:
          return 'خلفك قليلاً إلى اليسار';
        case 8:
          return 'إلى اليسار الخلفي';
        case 9:
          return 'إلى اليسار';
        case 10:
          return 'إلى اليسار الأمامي';
        case 11:
          return 'أمامك قليلاً إلى اليسار';
        default:
          return 'مباشرة أمامك';
      }
    } else {
      switch (clockPosition) {
        case 12:
          return 'Straight ahead';
        case 1:
          return 'Slightly ahead to the right';
        case 2:
          return 'Front right';
        case 3:
          return 'To your right';
        case 4:
          return 'Back right';
        case 5:
          return 'Slightly behind to the right';
        case 6:
          return 'Directly behind';
        case 7:
          return 'Slightly behind to the left';
        case 8:
          return 'Back left';
        case 9:
          return 'To your left';
        case 10:
          return 'Front left';
        case 11:
          return 'Slightly ahead to the left';
        default:
          return 'Straight ahead';
      }
    }
  }

  /// Get distance text
  static String _getDistanceText(double distance, bool isArabic) {
    if (distance < 0.5) {
      return isArabic ? 'قريب جداً' : 'very close';
    } else if (distance < 1.0) {
      return isArabic ? 'قريب' : 'close';
    } else if (distance < 2.0) {
      return isArabic
          ? '${distance.toStringAsFixed(1)} متر'
          : '${distance.toStringAsFixed(1)} meters';
    } else {
      return isArabic
          ? '${distance.toStringAsFixed(1)} متر'
          : '${distance.toStringAsFixed(1)} meters away';
    }
  }

  /// Get scanning prompt when object is not visible
  static String getScanPrompt({
    Offset? lastKnownPosition,
    Size? imageSize,
    required bool isArabic,
  }) {
    if (lastKnownPosition != null && imageSize != null) {
      // Give hint based on last known position
      final clock = calculateClockPosition(lastKnownPosition, imageSize);
      final direction = _getDirectionText(clock, isArabic);

      return isArabic
          ? 'غير مرئي حالياً. كان آخر مرة $direction'
          : 'Not visible. Last seen $direction';
    }

    return isArabic
        ? 'غير مرئي. يرجى الدوران ببطء'
        : 'Not in view. Please turn slowly';
  }

  /// Check if object is in center zone (for reached detection)
  static bool isInCenterZone(Offset objectCenter, Size imageSize) {
    final imageCenter = Offset(imageSize.width / 2, imageSize.height / 2);
    final distance = (objectCenter - imageCenter).distance;
    final threshold =
        min(imageSize.width, imageSize.height) * 0.15; // 15% threshold
    return distance < threshold;
  }

  /// Get relative direction (left, right, center)
  static String getRelativeDirection(
    Offset objectCenter,
    Size imageSize,
    bool isArabic,
  ) {
    final centerX = imageSize.width / 2;
    final threshold = imageSize.width * 0.15; // 15% threshold

    if (objectCenter.dx < centerX - threshold) {
      return isArabic ? 'يسار' : 'left';
    } else if (objectCenter.dx > centerX + threshold) {
      return isArabic ? 'يمين' : 'right';
    } else {
      return isArabic ? 'وسط' : 'center';
    }
  }
}
