import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;

/// Service to detect camera quality issues (dark room, blocked camera)
class CameraQualityDetector {
  CameraQualityDetector._();

  static final CameraQualityDetector instance = CameraQualityDetector._();

  /// Check if camera image is too dark or blocked
  /// Returns CameraQualityResult with status and metrics
  CameraQualityResult checkImageQuality(img.Image image) {
    // Calculate brightness
    final brightness = _calculateBrightness(image);

    // Calculate variance (to detect if camera is blocked/uniform)
    final variance = _calculateVariance(image);

    // Determine status
    CameraQualityStatus status;
    String? message;

    // Thresholds
    const darkThreshold = 30.0; // Out of 255
    const blockedVarianceThreshold = 50.0; // Low variance = uniform/blocked

    if (brightness < darkThreshold) {
      status = CameraQualityStatus.tooDark;
      message = 'The room is too dark';
    } else if (variance < blockedVarianceThreshold) {
      status = CameraQualityStatus.blocked;
      message = 'Camera appears to be blocked or covered';
    } else {
      status = CameraQualityStatus.good;
    }

    return CameraQualityResult(
      status: status,
      brightness: brightness,
      variance: variance,
      message: message,
    );
  }

  /// Check quality from CameraImage directly
  CameraQualityResult? checkCameraImage(CameraImage cameraImage) {
    try {
      // Sample only part of the image for performance
      final sampledImage = _sampleCameraImage(cameraImage);
      if (sampledImage == null) return null;

      return checkImageQuality(sampledImage);
    } catch (e) {
      print('Error checking camera quality: $e');
      return null;
    }
  }

  /// Sample camera image for quick quality check (use center portion)
  img.Image? _sampleCameraImage(CameraImage cameraImage) {
    try {
      // For YUV420, we can directly use Y plane (brightness)
      if (cameraImage.format.group == ImageFormatGroup.yuv420) {
        final yPlane = cameraImage.planes[0];
        final width = cameraImage.width;
        final height = cameraImage.height;

        // Sample center 1/4 of image for speed
        final sampleWidth = width ~/ 2;
        final sampleHeight = height ~/ 2;
        final startX = width ~/ 4;
        final startY = height ~/ 4;

        final sampledImage = img.Image(
          width: sampleWidth,
          height: sampleHeight,
        );

        for (int y = 0; y < sampleHeight; y++) {
          for (int x = 0; x < sampleWidth; x++) {
            final yIndex = (startY + y) * yPlane.bytesPerRow + (startX + x);
            final yValue = yPlane.bytes[yIndex];
            sampledImage.setPixelRgb(x, y, yValue, yValue, yValue);
          }
        }

        return sampledImage;
      }

      // For other formats, return null (will skip quality check)
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Calculate average brightness of image (0-255)
  double _calculateBrightness(img.Image image) {
    int totalBrightness = 0;
    final pixelCount = image.width * image.height;

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        // Calculate luminance
        final brightness = (0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b)
            .round();
        totalBrightness += brightness;
      }
    }

    return totalBrightness / pixelCount;
  }

  /// Calculate variance to detect uniform/blocked images
  double _calculateVariance(img.Image image) {
    // First pass: calculate mean
    double mean = 0;
    final pixelCount = image.width * image.height;

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final brightness =
            (0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b);
        mean += brightness;
      }
    }
    mean /= pixelCount;

    // Second pass: calculate variance
    double variance = 0;
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final brightness =
            (0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b);
        final diff = brightness - mean;
        variance += diff * diff;
      }
    }
    variance /= pixelCount;

    return variance;
  }
}

/// Camera quality status
enum CameraQualityStatus { good, tooDark, blocked }

/// Result of camera quality check
class CameraQualityResult {
  final CameraQualityStatus status;
  final double brightness;
  final double variance;
  final String? message;

  const CameraQualityResult({
    required this.status,
    required this.brightness,
    required this.variance,
    this.message,
  });

  bool get isGood => status == CameraQualityStatus.good;
  bool get isTooDark => status == CameraQualityStatus.tooDark;
  bool get isBlocked => status == CameraQualityStatus.blocked;
  bool get hasIssue => !isGood;

  @override
  String toString() {
    return 'CameraQuality(status: $status, brightness: ${brightness.toStringAsFixed(1)}, '
        'variance: ${variance.toStringAsFixed(1)}, message: $message)';
  }
}
