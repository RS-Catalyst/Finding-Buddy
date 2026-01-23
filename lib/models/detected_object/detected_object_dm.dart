import 'dart:math';
import 'dart:ui';

/// COMPLETE Enhanced Detection Model
/// Contains ALL detection information with precise calculations
class DetectedObjectDm {
  const DetectedObjectDm({
    required this.label,
    required this.score,
    required this.location,
    required this.imageSize,
    this.sensorOrientation = 0,
    this.isFrontCamera = false,
    // Camera calibration parameters (can be customized per device)
    this.focalLengthMm = 4.0, // Typical smartphone focal length
    this.sensorWidthMm = 5.76, // Typical 1/2.55" sensor
    this.realWorldObjectWidthCm, // If known, for accurate distance
  });

  /// Core detection data from YOLO
  final String label;
  final double score;
  final Rect location; // Bounding box in image coordinates
  final Size imageSize; // Original image dimensions

  /// Camera parameters
  final int sensorOrientation; // 0, 90, 180, 270
  final bool isFrontCamera;

  /// Camera calibration for distance estimation
  final double focalLengthMm;
  final double sensorWidthMm;
  final double? realWorldObjectWidthCm; // Known object width for accuracy

  // ============================================================================
  // BASIC GEOMETRIC CALCULATIONS
  // ============================================================================

  /// Bounding box center point
  Offset get center => location.center;

  /// Bounding box width in pixels
  double get width => location.width;

  /// Bounding box height in pixels
  double get height => location.height;

  /// Bounding box area in pixels²
  double get area => width * height;

  /// Area as percentage of total image (0.0 to 1.0)
  double get areaPercentage => area / (imageSize.width * imageSize.height);

  /// Aspect ratio of bounding box (width/height)
  double get aspectRatio => width / height;

  // ============================================================================
  // POSITION CALCULATIONS
  // ============================================================================

  /// Image center point
  Offset get imageCenter => Offset(imageSize.width / 2, imageSize.height / 2);

  /// Horizontal position relative to center (-1.0 to 1.0)
  /// -1.0 = far left, 0.0 = center, 1.0 = far right
  double get horizontalPositionNormalized {
    final centerX = center.dx;
    final imageCenterX = imageSize.width / 2;
    return (centerX - imageCenterX) / (imageSize.width / 2);
  }

  /// Vertical position relative to center (-1.0 to 1.0)
  /// -1.0 = top, 0.0 = center, 1.0 = bottom
  double get verticalPositionNormalized {
    final centerY = center.dy;
    final imageCenterY = imageSize.height / 2;
    return (centerY - imageCenterY) / (imageSize.height / 2);
  }

  /// Horizontal position category
  HorizontalPosition get horizontalPosition {
    final normalized = horizontalPositionNormalized;
    if (normalized < -0.2) return HorizontalPosition.left;
    if (normalized > 0.2) return HorizontalPosition.right;
    return HorizontalPosition.center;
  }

  /// Vertical position category
  VerticalPosition get verticalPosition {
    final normalized = verticalPositionNormalized;
    if (normalized < -0.2) return VerticalPosition.above;
    if (normalized > 0.2) return VerticalPosition.below;
    return VerticalPosition.center;
  }

  // ============================================================================
  // CLOCK POSITION CALCULATION (1-12)
  // ============================================================================

  /// Calculate clock position (1-12 o'clock)
  ///
  /// Formula:
  /// 1. Calculate angle from image center to object center
  /// 2. Convert to degrees with 0° at top (12 o'clock)
  /// 3. Divide into 12 equal sectors (30° each)
  ///
  /// Angle mapping:
  /// - 0° = 12 o'clock (straight ahead)
  /// - 90° = 3 o'clock (right)
  /// - 180° = 6 o'clock (behind/down)
  /// - 270° = 9 o'clock (left)
  int get clockPosition {
    // Vector from image center to object center
    final dx = center.dx - imageCenter.dx;
    final dy = center.dy - imageCenter.dy;

    // Calculate angle using atan2 (range: -π to π)
    // Image coordinates: (0,0) = top-left, Y increases downward
    // atan2(dy, dx) where:
    //   RIGHT (dx>0, dy=0) → 0°
    //   BOTTOM (dx=0, dy>0) → +90°
    //   LEFT (dx<0, dy=0) → ±180°
    //   TOP (dx=0, dy<0) → -90°
    final double angleRad = atan2(dy, dx);

    // Convert to degrees
    double angleDeg = angleRad * (180 / pi);

    // DEBUG PRINT
    print('=== CLOCK DEBUG ===');
    print('Object: $label');
    print('Image size: ${imageSize.width}x${imageSize.height}');
    print('Image center: ${imageCenter.dx}, ${imageCenter.dy}');
    print('Object center: ${center.dx}, ${center.dy}');
    print('dx: $dx, dy: $dy');
    print('Angle (rad): $angleRad');
    print('Angle (deg): $angleDeg');

    // Rotate by +90° so 0° is at top (12 o'clock)
    // This maps: 0°→90°, 90°→180°, 180°→270°, -90°→0°
    angleDeg = angleDeg + 90;

    print('After +90: $angleDeg');

    // Normalize to 0-360 range
    if (angleDeg < 0) angleDeg += 360;

    print('Normalized: $angleDeg');

    // Convert to clock hour (30° per hour)
    final rawHour = angleDeg / 30;
    int hour = rawHour.round() % 12;
    if (hour == 0) hour = 12;

    print('Raw hour: $rawHour, Final hour: $hour');
    print('==================\n');

    return hour;
  }

  /// Get angle in degrees (0-360)
  /// 0° = top, 90° = right, 180° = bottom, 270° = left
  double get angleDegrees {
    final dx = center.dx - imageCenter.dx;
    final dy = center.dy - imageCenter.dy;
    double angle = atan2(dy, dx) * (180 / pi) + 90;
    if (angle < 0) angle += 360;
    return angle;
  }

  // ============================================================================
  // DISTANCE ESTIMATION
  // ============================================================================

  /// Estimate distance using MULTIPLE methods for best accuracy
  double get distanceMeters {
    // Method 1: If we know real object width (most accurate)
    if (realWorldObjectWidthCm != null) {
      return _distanceFromKnownObjectWidth();
    }

    // Method 2: Use typical object sizes
    final typicalWidth = _getTypicalObjectWidth(label);
    if (typicalWidth != null) {
      return _distanceFromKnownObjectWidth(objectWidthCm: typicalWidth);
    }

    // Method 3: Heuristic based on bounding box area
    return _distanceFromBoundingBoxArea();
  }

  /// Method 1: Distance from known object width (MOST ACCURATE)
  ///
  /// Formula: distance = (realWorldWidth × focalLength × imageWidth) / (objectWidthInPixels × sensorWidth)
  ///
  /// This is the pinhole camera model:
  /// - realWorldWidth: actual object width in cm
  /// - focalLength: camera focal length in mm
  /// - imageWidth: image width in pixels
  /// - objectWidthInPixels: bounding box width
  /// - sensorWidth: camera sensor width in mm
  double _distanceFromKnownObjectWidth({double? objectWidthCm}) {
    final widthCm = objectWidthCm ?? realWorldObjectWidthCm ?? 10.0;

    // Convert to consistent units
    final widthMm = widthCm * 10; // cm to mm

    // Pinhole camera formula
    // distance = (realWidth × focalLength × imageWidth) / (pixelWidth × sensorWidth)
    final pixelWidth = width;
    final imageWidthPx = imageSize.width;

    final distanceMm =
        (widthMm * focalLengthMm * imageWidthPx) / (pixelWidth * sensorWidthMm);

    final distanceM = distanceMm / 1000; // mm to meters

    // Clamp to reasonable range
    return distanceM.clamp(0.2, 15.0);
  }

  /// Method 2: Distance from bounding box area (HEURISTIC)
  ///
  /// Logic: Larger bounding box = closer object
  /// Calibrated empirically for typical use cases
  double _distanceFromBoundingBoxArea() {
    final percentage = areaPercentage;

    double distance;

    // Calibrated thresholds (adjust based on testing)
    if (percentage >= 0.40) {
      // Very close: 0.3m to 0.5m
      distance = 0.3 + (0.50 - percentage) * 0.4;
    } else if (percentage >= 0.25) {
      // Close: 0.5m to 1.0m
      distance = 0.5 + (0.40 - percentage) * 3.33;
    } else if (percentage >= 0.15) {
      // Medium-close: 1.0m to 1.5m
      distance = 1.0 + (0.25 - percentage) * 5.0;
    } else if (percentage >= 0.08) {
      // Medium: 1.5m to 2.5m
      distance = 1.5 + (0.15 - percentage) * 14.3;
    } else if (percentage >= 0.04) {
      // Medium-far: 2.5m to 4.0m
      distance = 2.5 + (0.08 - percentage) * 37.5;
    } else if (percentage >= 0.02) {
      // Far: 4.0m to 6.0m
      distance = 4.0 + (0.04 - percentage) * 100.0;
    } else {
      // Very far: 6.0m to 10.0m
      distance = 6.0 + (0.02 - percentage) * 200.0;
    }

    return distance.clamp(0.3, 10.0);
  }

  /// Get typical object width for known labels
  static double? _getTypicalObjectWidth(String label) {
    // Typical object widths in cm (measured across widest dimension)
    const Map<String, double> typicalSizes = {
      'cell phone': 7.0,
      'laptop': 35.0,
      'keyboard': 45.0,
      'mouse': 6.0,
      'remote': 5.0,
      'bottle': 7.0,
      'cup': 8.0,
      'book': 15.0,
      'chair': 50.0,
      'tv': 100.0,
      'backpack': 40.0,
      'handbag': 30.0,
      'person': 50.0, // shoulder width
      'dog': 40.0, // medium dog
      'cat': 25.0,
      'car': 180.0,
    };

    return typicalSizes[label.toLowerCase()];
  }

  /// Distance category for easy interpretation
  DistanceCategory get distanceCategory {
    final dist = distanceMeters;
    if (dist < 0.5) return DistanceCategory.veryClose;
    if (dist < 1.0) return DistanceCategory.close;
    if (dist < 2.5) return DistanceCategory.medium;
    if (dist < 5.0) return DistanceCategory.far;
    return DistanceCategory.veryFar;
  }

  // ============================================================================
  // OBJECT ORIENTATION/ANGLE (HEURISTIC)
  // ============================================================================

  /// Estimate object orientation based on bounding box shape
  /// Note: YOLO doesn't provide rotation, this is a heuristic
  ObjectOrientation get orientation {
    final ratio = aspectRatio;

    // Portrait orientation (taller than wide)
    if (ratio < 0.7) return ObjectOrientation.portrait;

    // Landscape orientation (wider than tall)
    if (ratio > 1.4) return ObjectOrientation.landscape;

    // Square-ish
    return ObjectOrientation.neutral;
  }

  /// Estimated rotation angle based on aspect ratio (ROUGH ESTIMATE)
  /// Returns 0° for upright, 90° for horizontal
  double get estimatedRotationDegrees {
    if (orientation == ObjectOrientation.landscape) return 90.0;
    if (orientation == ObjectOrientation.portrait) return 0.0;
    return 45.0; // Neutral/unknown
  }

  // ============================================================================
  // SCALED LOCATION FOR DISPLAY
  // ============================================================================

  /// Get bounding box scaled to screen dimensions
  Rect getScaledLocation({
    required Size screenSize,
    required Size imageSize,
    bool isFrontCamera = false,
  }) {
    final double scaleX = screenSize.width / imageSize.width;
    final double scaleY = screenSize.height / imageSize.height;

    double left = location.left * scaleX;
    final double top = location.top * scaleY;
    double right = location.right * scaleX;
    final double bottom = location.bottom * scaleY;

    // Mirror for front camera
    if (isFrontCamera) {
      final temp = left;
      left = screenSize.width - right;
      right = screenSize.width - temp;
    }

    return Rect.fromLTRB(left, top, right, bottom);
  }

  // ============================================================================
  // VALIDATION & UTILITIES
  // ============================================================================

  /// Check if this is a valid detection
  bool isValid({double threshold = 0.60}) => score >= threshold;

  /// Check if object is centered
  bool get isCentered {
    return horizontalPosition == HorizontalPosition.center &&
        verticalPosition == VerticalPosition.center;
  }

  /// Distance from object center to image center (pixels)
  double get distanceFromImageCenter {
    return (center - imageCenter).distance;
  }

  /// Is object in the center zone (within 20% of center)
  bool get isInCenterZone {
    final threshold = min(imageSize.width, imageSize.height) * 0.2;
    return distanceFromImageCenter < threshold;
  }

  // ============================================================================
  // STRING REPRESENTATIONS
  // ============================================================================

  /// Human-readable distance string
  String get distanceString {
    final dist = distanceMeters;
    if (dist < 0.5) return 'very close';
    if (dist < 1.0) return '${dist.toStringAsFixed(1)}m (close)';
    return '${dist.toStringAsFixed(1)}m';
  }

  /// Human-readable direction string
  String getDirectionString({bool isArabic = false}) {
    if (isArabic) {
      return _getArabicDirectionString();
    }

    switch (clockPosition) {
      case 12:
        return 'Straight ahead';
      case 1:
        return 'Slightly right';
      case 2:
        return 'Front right';
      case 3:
        return 'To your right';
      case 4:
        return 'Back right';
      case 5:
        return 'Behind right';
      case 6:
        return 'Behind you';
      case 7:
        return 'Behind left';
      case 8:
        return 'Back left';
      case 9:
        return 'To your left';
      case 10:
        return 'Front left';
      case 11:
        return 'Slightly left';
      default:
        return 'Straight ahead';
    }
  }

  String _getArabicDirectionString() {
    switch (clockPosition) {
      case 12:
        return 'مباشرة أمامك';
      case 1:
        return 'قليلاً إلى اليمين';
      case 2:
        return 'أمامك يميناً';
      case 3:
        return 'إلى اليمين';
      case 4:
        return 'خلفك يميناً';
      case 5:
        return 'خلفك إلى اليمين';
      case 6:
        return 'خلفك مباشرة';
      case 7:
        return 'خلفك إلى اليسار';
      case 8:
        return 'خلفك يساراً';
      case 9:
        return 'إلى اليسار';
      case 10:
        return 'أمامك يساراً';
      case 11:
        return 'قليلاً إلى اليسار';
      default:
        return 'مباشرة أمامك';
    }
  }

  // ============================================================================
  // COPY & EQUALITY
  // ============================================================================

  DetectedObjectDm copyWith({
    String? label,
    double? score,
    Rect? location,
    Size? imageSize,
    int? sensorOrientation,
    bool? isFrontCamera,
    double? focalLengthMm,
    double? sensorWidthMm,
    double? realWorldObjectWidthCm,
  }) {
    return DetectedObjectDm(
      label: label ?? this.label,
      score: score ?? this.score,
      location: location ?? this.location,
      imageSize: imageSize ?? this.imageSize,
      sensorOrientation: sensorOrientation ?? this.sensorOrientation,
      isFrontCamera: isFrontCamera ?? this.isFrontCamera,
      focalLengthMm: focalLengthMm ?? this.focalLengthMm,
      sensorWidthMm: sensorWidthMm ?? this.sensorWidthMm,
      realWorldObjectWidthCm:
          realWorldObjectWidthCm ?? this.realWorldObjectWidthCm,
    );
  }

  @override
  String toString() {
    return 'DetectedObject(\n'
        '  label: $label,\n'
        '  confidence: ${(score * 100).toStringAsFixed(1)}%,\n'
        '  position: ${horizontalPosition.name},\n'
        '  clock: $clockPosition o\'clock,\n'
        '  distance: $distanceString,\n'
        '  angle: ${angleDegrees.toStringAsFixed(0)}°\n'
        ')';
  }

  /// Convert to JSON-like map for API/storage
  Map<String, dynamic> toJson() {
    return {
      'label': label,
      'confidence': score,
      'bounding_box': {
        'x': location.left,
        'y': location.top,
        'width': width,
        'height': height,
      },
      'distance_meters': distanceMeters,
      'distance_category': distanceCategory.name,
      'horizontal_position': horizontalPosition.name,
      'vertical_position': verticalPosition.name,
      'clock_position': clockPosition,
      'angle_degrees': angleDegrees,
      'orientation': orientation.name,
      'area_percentage': areaPercentage,
      'is_centered': isCentered,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DetectedObjectDm &&
        other.label == label &&
        other.score == score &&
        other.location == location;
  }

  @override
  int get hashCode => Object.hash(label, score, location);
}

// ============================================================================
// ENUMS FOR CATEGORIZATION
// ============================================================================

enum HorizontalPosition { left, center, right }

enum VerticalPosition { above, center, below }

enum DistanceCategory { veryClose, close, medium, far, veryFar }

enum ObjectOrientation { portrait, landscape, neutral }

// ============================================================================
// LIST EXTENSIONS
// ============================================================================

extension DetectedObjectListExt on List<DetectedObjectDm> {
  /// Filter by minimum confidence score
  List<DetectedObjectDm> filterByScore(double minScore) {
    return where((obj) => obj.score >= minScore).toList();
  }

  /// Filter by specific label
  List<DetectedObjectDm> filterByLabel(String label) {
    return where(
      (obj) => obj.label.toLowerCase() == label.toLowerCase(),
    ).toList();
  }

  /// Get the closest object (smallest distance)
  DetectedObjectDm? getClosest() {
    if (isEmpty) return null;
    return reduce((a, b) => a.distanceMeters < b.distanceMeters ? a : b);
  }

  /// Get the largest object (biggest bounding box)
  DetectedObjectDm? getLargest() {
    if (isEmpty) return null;
    return reduce((a, b) => a.area > b.area ? a : b);
  }

  /// Get the center-most object
  DetectedObjectDm? getCenterMost(Size imageSize) {
    if (isEmpty) return null;
    final imageCenter = Offset(imageSize.width / 2, imageSize.height / 2);
    return reduce((a, b) {
      final distA = (a.center - imageCenter).distance;
      final distB = (b.center - imageCenter).distance;
      return distA < distB ? a : b;
    });
  }

  /// Get objects within a distance range
  List<DetectedObjectDm> inDistanceRange(double minMeters, double maxMeters) {
    return where((obj) {
      final dist = obj.distanceMeters;
      return dist >= minMeters && dist <= maxMeters;
    }).toList();
  }

  /// Sort by distance (closest first)
  List<DetectedObjectDm> sortedByDistance() {
    final sorted = List<DetectedObjectDm>.from(this);
    sorted.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
    return sorted;
  }

  /// Sort by confidence (highest first)
  List<DetectedObjectDm> sortedByConfidence() {
    final sorted = List<DetectedObjectDm>.from(this);
    sorted.sort((a, b) => b.score.compareTo(a.score));
    return sorted;
  }
}
