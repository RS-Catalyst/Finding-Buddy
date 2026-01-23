import 'dart:math';
import 'package:camera/camera.dart';

enum CameraQualityStatus { good, tooDark, tooBlurry, blocked }

class CameraQualityResult {
  final CameraQualityStatus status;
  final double brightness;
  final double variance;
  final String message;

  const CameraQualityResult({
    required this.status,
    required this.brightness,
    required this.variance,
    required this.message,
  });

  bool get isGood => status == CameraQualityStatus.good;
  bool get isDark => status == CameraQualityStatus.tooDark;
  bool get isBlocked => status == CameraQualityStatus.blocked;
  bool get isBlurry => status == CameraQualityStatus.tooBlurry;
}

class CameraQualityDetector {
  // Thresholds
  static const double _minBrightness = 15.0; // Too dark below this
  static const double _blockedThreshold = 5.0; // Completely blocked below this
  static const double _minVariance = 10.0; // Too uniform/blocked below this

  /// Check camera quality from YUV420 image
  static CameraQualityResult checkQuality(CameraImage image) {
    try {
      // Sample pixels from Y plane (brightness)
      final yPlane = image.planes[0];
      final yBytes = yPlane.bytes;

      // Sample 100 pixels evenly distributed
      const sampleSize = 100;
      final step = (yBytes.length / sampleSize).floor();

      if (step <= 0) {
        return const CameraQualityResult(
          status: CameraQualityStatus.good,
          brightness: 50.0,
          variance: 50.0,
          message: 'Could not analyze',
        );
      }

      final List<int> samples = [];
      for (int i = 0; i < yBytes.length; i += step) {
        if (samples.length >= sampleSize) break;
        samples.add(yBytes[i]);
      }

      if (samples.isEmpty) {
        return const CameraQualityResult(
          status: CameraQualityStatus.good,
          brightness: 50.0,
          variance: 50.0,
          message: 'Good quality',
        );
      }

      // Calculate brightness (mean)
      final double brightness =
          samples.reduce((a, b) => a + b) / samples.length;

      // Calculate variance
      final mean = brightness;
      final variance =
          samples.map((val) => pow(val - mean, 2)).reduce((a, b) => a + b) /
          samples.length;

      // Determine quality status
      if (brightness < _blockedThreshold) {
        return CameraQualityResult(
          status: CameraQualityStatus.blocked,
          brightness: brightness,
          variance: variance,
          message: 'Camera is blocked or covered',
        );
      }

      if (brightness < _minBrightness) {
        return CameraQualityResult(
          status: CameraQualityStatus.tooDark,
          brightness: brightness,
          variance: variance,
          message: 'The room is too dark',
        );
      }

      if (variance < _minVariance) {
        return CameraQualityResult(
          status: CameraQualityStatus.blocked,
          brightness: brightness,
          variance: variance,
          message: 'Camera might be blocked',
        );
      }

      return CameraQualityResult(
        status: CameraQualityStatus.good,
        brightness: brightness,
        variance: variance,
        message: 'Good quality',
      );
    } catch (e) {
      print('❌ Camera quality check error: $e');
      return const CameraQualityResult(
        status: CameraQualityStatus.good,
        brightness: 50.0,
        variance: 50.0,
        message: 'Analysis failed',
      );
    }
  }

  /// Quick check if frame is too dark (faster than full quality check)
  static bool isTooDark(CameraImage image) {
    try {
      final yPlane = image.planes[0];
      final yBytes = yPlane.bytes;

      // Sample just 20 pixels
      final step = (yBytes.length / 20).floor();
      if (step <= 0) return false;

      int sum = 0;
      int count = 0;

      for (int i = 0; i < yBytes.length && count < 20; i += step) {
        sum += yBytes[i];
        count++;
      }

      if (count == 0) return false;

      final brightness = sum / count;
      return brightness < _minBrightness;
    } catch (e) {
      return false;
    }
  }
}
