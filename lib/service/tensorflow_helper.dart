import 'dart:ui';
import 'dart:math';
import 'package:finding_buddy/models/detected_object/detected_object_dm.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:finding_buddy/utils/app_constants.dart';

class TensorflowHelper {
  const TensorflowHelper._();

  static const int inputSize = AppConstants.inputSize;
  static const double confThreshold = AppConstants.confidenceThreshold;
  static const double iouThreshold = AppConstants.iouThreshold;

  /// COCO 80 classes for YOLOv8
  static const List<String> classNames = [
    'person',
    'bicycle',
    'car',
    'motorcycle',
    'airplane',
    'bus',
    'train',
    'truck',
    'boat',
    'traffic light',
    'fire hydrant',
    'stop sign',
    'parking meter',
    'bench',
    'bird',
    'cat',
    'dog',
    'horse',
    'sheep',
    'cow',
    'elephant',
    'bear',
    'zebra',
    'giraffe',
    'backpack',
    'umbrella',
    'handbag',
    'tie',
    'suitcase',
    'frisbee',
    'skis',
    'snowboard',
    'sports ball',
    'kite',
    'baseball bat',
    'baseball glove',
    'skateboard',
    'surfboard',
    'tennis racket',
    'bottle',
    'wine glass',
    'cup',
    'fork',
    'knife',
    'spoon',
    'bowl',
    'banana',
    'apple',
    'sandwich',
    'orange',
    'broccoli',
    'carrot',
    'hot dog',
    'pizza',
    'donut',
    'cake',
    'chair',
    'couch',
    'potted plant',
    'bed',
    'dining table',
    'toilet',
    'tv',
    'laptop',
    'mouse',
    'remote',
    'keyboard',
    'cell phone',
    'microwave',
    'oven',
    'toaster',
    'sink',
    'refrigerator',
    'book',
    'clock',
    'vase',
    'scissors',
    'teddy bear',
    'hair drier',
    'toothbrush',
  ];

  /// Analyze image and return detections - COMPLETE FIXED VERSION
  static AnalysisResult analyseImage(
    img.Image image, {
    required Interpreter interpreter,
    required List<String> labels,
    String? targetClass,
    double minConfidence = confThreshold,
    int sensorOrientation = 0,
    bool isFrontCamera = false,
  }) {
    final originalWidth = image.width;
    final originalHeight = image.height;
    final originalSize = Size(
      originalWidth.toDouble(),
      originalHeight.toDouble(),
    );

    print('\n=== TENSORFLOW HELPER DEBUG ===');
    print('Original image: ${originalWidth}x$originalHeight');

    // Resize for YOLOv8 input
    final resizedImage = img.copyResize(
      image,
      width: inputSize,
      height: inputSize,
    );

    // Run inference
    final detections = _runInference(
      resizedImage,
      interpreter,
      originalWidth,
      originalHeight,
      originalSize,
      sensorOrientation,
      isFrontCamera,
    );

    print('Total detections before filtering: ${detections.length}');

    // Filter detections
    List<DetectedObjectDm> filtered = detections
        .where((d) => d.score >= minConfidence)
        .toList();

    print('After confidence filter: ${filtered.length}');

    // Filter by target class if specified
    if (targetClass != null && targetClass.isNotEmpty) {
      filtered = filtered
          .where((d) => d.label.toLowerCase() == targetClass.toLowerCase())
          .toList();
      print('After target class filter: ${filtered.length}');
    }

    // Sort by confidence
    filtered.sort((a, b) => b.score.compareTo(a.score));

    print('=== END TENSORFLOW HELPER ===\n');

    return AnalysisResult(detectedObjects: filtered, imageSize: originalSize);
  }

  /// Run YOLOv8 inference
  static List<DetectedObjectDm> _runInference(
    img.Image image,
    Interpreter interpreter,
    int originalWidth,
    int originalHeight,
    Size originalSize,
    int sensorOrientation,
    bool isFrontCamera,
  ) {
    // Preprocess image
    final input = _preprocessImage(image);
    final inputTensor = input.reshape([1, inputSize, inputSize, 3]);

    // Output tensor shape: [1, 84, 8400] for YOLOv8
    final outputTensor = List.filled(1 * 84 * 8400, 0.0).reshape([1, 84, 8400]);

    // Run inference
    interpreter.run(inputTensor, outputTensor);

    DateTime now2 = DateTime.now();
    print(
      'arbaz khan mashwnai camer image 2 resize runinference ${now2.hour}:${now2.minute}:${now2.second}',
    );

    // Decode output with FIXED scaling
    return _decodeOutput(
      outputTensor[0],
      originalWidth,
      originalHeight,
      originalSize,
      sensorOrientation,
      isFrontCamera,
    );
  }

  /// Preprocess image for YOLOv8 (normalize to [0, 1])
  static List<double> _preprocessImage(img.Image image) {
    final input = List<double>.filled(inputSize * inputSize * 3, 0.0);
    int pixelIndex = 0;

    for (int y = 0; y < inputSize; y++) {
      for (int x = 0; x < inputSize; x++) {
        final pixel = image.getPixel(x, y);
        input[pixelIndex++] = pixel.r / 255.0;
        input[pixelIndex++] = pixel.g / 255.0;
        input[pixelIndex++] = pixel.b / 255.0;
      }
    }

    return input;
  }

  /// Decode YOLOv8 output to COMPLETE detections - FIXED SCALING
  static List<DetectedObjectDm> _decodeOutput(
    List<List<double>> output,
    int originalWidth,
    int originalHeight,
    Size originalSize,
    int sensorOrientation,
    bool isFrontCamera,
  ) {
    final List<_RawDetection> rawDetections = [];

    print('\n=== DECODE OUTPUT DEBUG ===');
    print('Original size: ${originalWidth}x$originalHeight');
    print('Input size: $inputSize');

    // YOLOv8 output format: [84, 8400]
    for (int i = 0; i < 8400; i++) {
      final List<double> pred = List.generate(84, (idx) => output[idx][i]);

      // CRITICAL: Check if coordinates are normalized or in pixel space
      // YOLOv8 typically outputs coordinates relative to input size (640x640)
      // Format: x_center, y_center, width, height
      final double xCenter = pred[0];
      final double yCenter = pred[1];
      final double width = pred[2];
      final double height = pred[3];

      // Debug first detection
      if (i == 0) {
        print('\nFirst prediction RAW values:');
        print('  xCenter: $xCenter');
        print('  yCenter: $yCenter');
        print('  width: $width');
        print('  height: $height');
      }

      // Class scores (indices 4-83)
      final List<double> classScores = pred.sublist(4, 84);
      final double maxScore = classScores.reduce(max);
      final int classIndex = classScores.indexOf(maxScore);

      if (maxScore >= confThreshold) {
        // CRITICAL FIX: Determine if coords are normalized or in input space
        // Based on your console output, coords are VERY SMALL (< 2)
        // This means they're NORMALIZED to input size (0-1 range for 640x640)
        // OR they're in a 0-2 range for some reason

        // Strategy: Check magnitude and scale accordingly
        final bool areNormalized =
            (xCenter < 10 && yCenter < 10 && width < 10 && height < 10);

        double scaledXCenter, scaledYCenter, scaledWidth, scaledHeight;

        if (areNormalized) {
          // Coordinates are normalized (0-1 or 0-2 range)
          // First normalize to 0-1 if needed, then scale to original size
          if (xCenter > 1.0 || yCenter > 1.0) {
            // Seems to be in 0-2 range, normalize to 0-1 first
            scaledXCenter = (xCenter / 2.0) * originalWidth;
            scaledYCenter = (yCenter / 2.0) * originalHeight;
            scaledWidth = (width / 2.0) * originalWidth;
            scaledHeight = (height / 2.0) * originalHeight;
          } else {
            // Already 0-1 normalized
            scaledXCenter = xCenter * originalWidth;
            scaledYCenter = yCenter * originalHeight;
            scaledWidth = width * originalWidth;
            scaledHeight = height * originalHeight;
          }

          if (i < 3 && maxScore >= confThreshold) {
            print('\nDetection $i (NORMALIZED coords):');
            print('  Raw: ($xCenter, $yCenter, $width, $height)');
            print(
              '  Scaled: ($scaledXCenter, $scaledYCenter, $scaledWidth, $scaledHeight)',
            );
          }
        } else {
          // Coordinates are in input pixel space (0-640)
          // Scale from input size to original size
          final double scaleX = originalWidth / inputSize;
          final double scaleY = originalHeight / inputSize;

          scaledXCenter = xCenter * scaleX;
          scaledYCenter = yCenter * scaleY;
          scaledWidth = width * scaleX;
          scaledHeight = height * scaleY;

          if (i < 3 && maxScore >= confThreshold) {
            print('\nDetection $i (INPUT SPACE coords):');
            print('  Raw: ($xCenter, $yCenter, $width, $height)');
            print('  Scale factors: ($scaleX, $scaleY)');
            print(
              '  Scaled: ($scaledXCenter, $scaledYCenter, $scaledWidth, $scaledHeight)',
            );
          }
        }

        // Convert from center format to corner format
        double left = scaledXCenter - scaledWidth / 2;
        double top = scaledYCenter - scaledHeight / 2;
        double right = scaledXCenter + scaledWidth / 2;
        double bottom = scaledYCenter + scaledHeight / 2;

        // Clamp to image bounds
        left = left.clamp(0, originalWidth.toDouble());
        top = top.clamp(0, originalHeight.toDouble());
        right = right.clamp(0, originalWidth.toDouble());
        bottom = bottom.clamp(0, originalHeight.toDouble());

        final rect = Rect.fromLTRB(left, top, right, bottom);

        if (rect.width > 0 && rect.height > 0) {
          rawDetections.add(_RawDetection(rect, maxScore, classIndex));

          if (rawDetections.length <= 3) {
            print(
              '  Final box: (${left.toStringAsFixed(2)}, ${top.toStringAsFixed(2)}, ${right.toStringAsFixed(2)}, ${bottom.toStringAsFixed(2)})',
            );
            print(
              '  Box center: (${rect.center.dx.toStringAsFixed(2)}, ${rect.center.dy.toStringAsFixed(2)})',
            );
          }
        }
      }
    }

    print('\nTotal raw detections: ${rawDetections.length}');
    print('=== END DECODE ===\n');

    // Apply NMS
    final nmsDetections = _nonMaxSuppression(rawDetections, iouThreshold);

    print('After NMS: ${nmsDetections.length}\n');

    // Convert to COMPLETE DetectedObjectDm
    return nmsDetections.map((det) {
      final label = det.classIndex < classNames.length
          ? classNames[det.classIndex]
          : 'unknown';

      return DetectedObjectDm(
        label: label,
        score: det.confidence,
        location: det.box,
        imageSize: originalSize,
        sensorOrientation: sensorOrientation,
        isFrontCamera: isFrontCamera,
        realWorldObjectWidthCm: _getTypicalObjectWidth(label),
      );
    }).toList();
  }

  static double? _getTypicalObjectWidth(String label) {
    const Map<String, double> typicalSizes = {
      'person': 50, // shoulder width
      'bicycle': 45,
      'car': 180,
      'motorcycle': 75,
      'airplane': 6000, // fuselage width (approx)
      'bus': 250,
      'train': 320,
      'truck': 250,
      'boat': 200,
      'traffic light': 30,
      'fire hydrant': 25,
      'stop sign': 75,
      'parking meter': 20,
      'bench': 120,
      'bird': 20,
      'cat': 25,
      'dog': 40,
      'horse': 60,
      'sheep': 40,
      'cow': 70,
      'elephant': 150,
      'bear': 60,
      'zebra': 60,
      'giraffe': 80,
      'backpack': 35,
      'umbrella': 90,
      'handbag': 30,
      'tie': 10,
      'suitcase': 45,
      'frisbee': 25,
      'skis': 10,
      'snowboard': 28,
      'sports ball': 22,
      'kite': 50,
      'baseball bat': 6,
      'baseball glove': 30,
      'skateboard': 20,
      'surfboard': 50,
      'tennis racket': 30,
      'bottle': 7,
      'wine glass': 8,
      'cup': 8,
      'fork': 3,
      'knife': 3,
      'spoon': 4,
      'bowl': 15,
      'banana': 4,
      'apple': 8,
      'sandwich': 10,
      'orange': 7,
      'broccoli': 12,
      'carrot': 3,
      'hot dog': 4,
      'pizza': 30,
      'donut': 10,
      'cake': 22,
      'chair': 50,
      'couch': 200,
      'potted plant': 25,
      'bed': 150,
      'dining table': 90,
      'toilet': 40,
      'tv': 100,
      'laptop': 35,
      'mouse': 6,
      'remote': 5,
      'keyboard': 45,
      'cell phone': 7,
      'microwave': 50,
      'oven': 60,
      'toaster': 25,
      'sink': 55,
      'refrigerator': 80,
      'book': 15,
      'clock': 30,
      'vase': 12,
      'scissors': 6,
      'teddy bear': 30,
      'hair drier': 10,
      'toothbrush': 2,
    };

    return typicalSizes[label.toLowerCase()];
  }

  /// Non-Maximum Suppression
  static List<_RawDetection> _nonMaxSuppression(
    List<_RawDetection> detections,
    double iouThreshold,
  ) {
    detections.sort((a, b) => b.confidence.compareTo(a.confidence));

    final List<_RawDetection> result = [];

    while (detections.isNotEmpty) {
      final best = detections.removeAt(0);
      result.add(best);

      detections.removeWhere((det) {
        if (det.classIndex != best.classIndex) return false;
        return _calculateIoU(best.box, det.box) > iouThreshold;
      });
    }

    return result;
  }

  /// Calculate Intersection over Union
  static double _calculateIoU(Rect a, Rect b) {
    final areaA = a.width * a.height;
    final areaB = b.width * b.height;

    if (areaA <= 0 || areaB <= 0) return 0;

    final interLeft = max(a.left, b.left);
    final interTop = max(a.top, b.top);
    final interRight = min(a.right, b.right);
    final interBottom = min(a.bottom, b.bottom);

    final interWidth = interRight - interLeft;
    final interHeight = interBottom - interTop;

    if (interWidth <= 0 || interHeight <= 0) return 0;

    final interArea = interWidth * interHeight;
    final unionArea = areaA + areaB - interArea;

    return interArea / unionArea;
  }
}

/// Internal class for raw detection processing
class _RawDetection {
  final Rect box;
  final double confidence;
  final int classIndex;

  _RawDetection(this.box, this.confidence, this.classIndex);
}

/// Analysis result containing detections and image info
class AnalysisResult {
  final List<DetectedObjectDm> detectedObjects;
  final Size imageSize;

  const AnalysisResult({
    required this.detectedObjects,
    required this.imageSize,
  });

  DetectedObjectDm? getBestDetection() {
    if (detectedObjects.isEmpty) return null;
    return detectedObjects.first;
  }

  DetectedObjectDm? getCenterMostDetection() {
    return detectedObjects.getCenterMost(imageSize);
  }

  DetectedObjectDm? getClosestDetection() {
    return detectedObjects.getClosest();
  }

  DetectedObjectDm? getLargestDetection() {
    return detectedObjects.getLargest();
  }
}
