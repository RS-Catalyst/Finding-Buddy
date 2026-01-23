import 'dart:async';
import 'dart:isolate';
import 'package:camera/camera.dart';
import 'package:finding_buddy/models/detected_object/detected_object_dm.dart';
import 'package:finding_buddy/service/dark_quaility.dart';
import 'package:finding_buddy/service/tensorflow_helper.dart';
import 'package:finding_buddy/service/tensorflow_service.dart';

import 'package:finding_buddy/utils/app_constants.dart';
import 'package:finding_buddy/utils/image_utils.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

/// Command types for isolate communication
enum DetectorCommand { init, ready, busy, detect, result, qualityCheck, stop }

/// Command message for isolate communication
class _DetectorMessage {
  final DetectorCommand command;
  final dynamic data;

  const _DetectorMessage(this.command, [this.data]);
}

/// Detection result from isolate - NOW WITH QUALITY INFO
class DetectionResult {
  final List<DetectedObjectDm> detections;
  final Size imageSize;
  final DateTime timestamp;
  final CameraQualityResult? qualityResult; // ADDED: Camera quality info

  const DetectionResult({
    required this.detections,
    required this.imageSize,
    required this.timestamp,
    this.qualityResult,
  });

  /// Get center-most detection
  DetectedObjectDm? getCenterMostDetection() {
    return detections.getCenterMost(imageSize);
  }

  /// Get closest detection (smallest distance)
  DetectedObjectDm? getClosestDetection() {
    return detections.getClosest();
  }

  /// Check if camera quality is good
  bool get hasGoodQuality => qualityResult?.isGood ?? true;

  /// Get quality issue message if any
  String? get qualityIssueMessage => qualityResult?.message;
}

/// Main detector class that manages isolate-based detection
class Detector {
  Detector._({
    required Isolate isolate,
    required int interpreterAddress,
    required List<String> labels,
  }) : _isolate = isolate,
       _interpreterAddress = interpreterAddress,
       _labels = labels;

  final Isolate _isolate;
  final int _interpreterAddress;
  final List<String> _labels;

  late SendPort _sendPort;
  bool _isReady = false;

  String? _targetClass;
  double _minConfidence = AppConstants.confidenceThreshold;

  // Camera quality tracking
  bool _enableQualityChecks = false;
  final int _qualityCheckInterval = 10; // Check every 5th frame
  int _frameCounter = 0;

  final StreamController<DetectionResult> _resultsController =
      StreamController<DetectionResult>.broadcast();

  /// Stream of detection results
  Stream<DetectionResult> get resultsStream => _resultsController.stream;

  /// Whether detector is ready to process frames
  bool get isReady => _isReady;

  /// Enable/disable quality checks
  void setQualityChecksEnabled(bool enabled) {
    _enableQualityChecks = enabled;
  }

  /// Set target class for single-target detection
  void setTargetClass(String? targetClass) {
    _targetClass = targetClass;
  }

  /// Set minimum confidence threshold
  void setMinConfidence(double confidence) {
    _minConfidence = confidence.clamp(0.0, 1.0);
  }

  /// Start the detector
  static Future<Detector> start() async {
    if (!TensorflowService.yolov8.isInitialized) {
      await TensorflowService.yolov8.initialize();
    }

    final receivePort = ReceivePort();

    final isolate = await Isolate.spawn(
      _DetectorIsolate._run,
      receivePort.sendPort,
    );

    final detector = Detector._(
      isolate: isolate,
      interpreterAddress: TensorflowService.yolov8.interpreter.address,
      labels: TensorflowService.yolov8.labels,
    );

    receivePort.listen((message) {
      detector._handleMessage(message as _DetectorMessage);
    });

    return detector;
  }

  /// Process a camera frame
  void processFrame(CameraImage cameraImage, CameraController controller) {
    if (!_isReady) return;

    final sensorOrientation = controller.description.sensorOrientation;
    final isFrontCamera =
        controller.description.lensDirection == CameraLensDirection.front;

    _frameCounter++;

    // Check quality every Nth frame
    final shouldCheckQuality =
        _enableQualityChecks && (_frameCounter % _qualityCheckInterval == 0);

    _sendPort.send(
      _DetectorMessage(DetectorCommand.detect, {
        'cameraImage': cameraImage,
        'targetClass': _targetClass,
        'minConfidence': _minConfidence,
        'sensorOrientation': sensorOrientation,
        'isFrontCamera': isFrontCamera,
        'checkQuality': shouldCheckQuality,
      }),
    );
  }

  /// Handle messages from isolate
  void _handleMessage(_DetectorMessage message) {
    switch (message.command) {
      case DetectorCommand.init:
        _sendPort = message.data as SendPort;
        _sendPort.send(
          _DetectorMessage(DetectorCommand.init, {
            'rootIsolateToken': RootIsolateToken.instance!,
            'interpreterAddress': _interpreterAddress,
            'labels': _labels,
          }),
        );
        break;

      case DetectorCommand.ready:
        _isReady = true;
        break;

      case DetectorCommand.busy:
        _isReady = false;
        break;

      case DetectorCommand.result:
        _isReady = true;
        if (!_resultsController.isClosed && message.data != null) {
          _resultsController.add(message.data as DetectionResult);
        }
        break;

      default:
        break;
    }
  }

  /// Stop the detector and cleanup
  void stop() {
    _resultsController.close();
    _isolate.kill(priority: Isolate.immediate);
  }
}

/// Isolate worker for detection processing
class _DetectorIsolate {
  _DetectorIsolate(this._sendPort);

  final SendPort _sendPort;
  Interpreter? _interpreter;
  List<String>? _labels;

  static void _run(SendPort sendPort) {
    final receivePort = ReceivePort();
    final isolate = _DetectorIsolate(sendPort);

    receivePort.listen((message) async {
      await isolate._handleMessage(message as _DetectorMessage);
    });

    sendPort.send(_DetectorMessage(DetectorCommand.init, receivePort.sendPort));
  }

  Future<void> _handleMessage(_DetectorMessage message) async {
    switch (message.command) {
      case DetectorCommand.init:
        final data = message.data as Map<String, dynamic>;
        final rootToken = data['rootIsolateToken'] as RootIsolateToken;
        BackgroundIsolateBinaryMessenger.ensureInitialized(rootToken);

        _interpreter = Interpreter.fromAddress(
          data['interpreterAddress'] as int,
        );
        _labels = List<String>.from(data['labels'] as List);

        _sendPort.send(const _DetectorMessage(DetectorCommand.ready));
        break;

      case DetectorCommand.detect:
        _sendPort.send(const _DetectorMessage(DetectorCommand.busy));
        await _processFrame(message.data as Map<String, dynamic>);
        break;

      default:
        break;
    }
  }

  Future<void> _processFrame(Map<String, dynamic> data) async {
    try {
      final cameraImage = data['cameraImage'] as CameraImage;
      final targetClass = data['targetClass'] as String?;
      final minConfidence = data['minConfidence'] as double;
      final sensorOrientation = data['sensorOrientation'] as int?;
      final isFrontCamera = data['isFrontCamera'] as bool? ?? false;
      final checkQuality = data['checkQuality'] as bool? ?? false;

      // Convert camera image
      var image = ImageUtils.convertCameraImageToImage(cameraImage);
      if (image == null || _interpreter == null) {
        _sendPort.send(const _DetectorMessage(DetectorCommand.result, null));
        return;
      }

      // CAMERA QUALITY CHECK - Before rotation/resize
      CameraQualityResult? qualityResult;
      if (checkQuality) {
        qualityResult = CameraQualityDetector.instance.checkImageQuality(image);
      }

      // Rotate image based on sensor orientation
      if (sensorOrientation != null) {
        switch (sensorOrientation) {
          case 0:
            break;
          case 90:
            image = ImageUtils.rotateImage(image, 90);
            break;
          case 180:
            image = ImageUtils.rotateImage(image, 180);
            break;
          case 270:
            image = ImageUtils.rotateImage(image, 270);
            break;
        }
      }

      // Store original size before resize
      final originalSize = Size(
        image.width.toDouble(),
        image.height.toDouble(),
      );

      // Resize for model
      image = ImageUtils.resizeImage(image, 640);

      // Run detection
      final result = TensorflowHelper.analyseImage(
        image,
        interpreter: _interpreter!,
        labels: _labels ?? [],
        targetClass: targetClass,
        minConfidence: minConfidence,
      );

      // Enhance detections with complete data
      final enhancedDetections = result.detectedObjects.map((det) {
        return DetectedObjectDm(
          label: det.label,
          score: det.score,
          location: det.location,
          imageSize: originalSize,
          isFrontCamera: isFrontCamera,
          sensorOrientation: sensorOrientation ?? 0,
        );
      }).toList();

      // Send results with quality info
      _sendPort.send(
        _DetectorMessage(
          DetectorCommand.result,
          DetectionResult(
            detections: enhancedDetections,
            imageSize: originalSize,
            timestamp: DateTime.now(),
            qualityResult: qualityResult,
          ),
        ),
      );
    } catch (e) {
      print('Detection error: $e');
      _sendPort.send(const _DetectorMessage(DetectorCommand.result, null));
    }
  }
}
