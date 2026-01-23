import 'dart:developer';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:finding_buddy/utils/app_constants.dart';

class TensorflowService {
  TensorflowService._({required this.modelPath, required this.labelPath});

  /// Singleton instance for YOLOv8 model
  static final TensorflowService yolov8 = TensorflowService._(
    modelPath: AppConstants.yolov8ModelPath,
    labelPath: AppConstants.yolov8LabelPath,
  );

  final String modelPath;
  final String labelPath;

  Interpreter? _interpreter;
  List<String>? _labels;
  bool _isInitialized = false;

  Interpreter get interpreter {
    if (_interpreter == null) {
      throw Exception(
        'TensorflowService not initialized. Call initialize() first.',
      );
    }
    return _interpreter!;
  }

  List<String> get labels => _labels ?? [];
  bool get isInitialized => _isInitialized;

  /// Initialize the model and labels
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await Future.wait([_loadModel(), _loadLabels()]);
      _isInitialized = true;
      log(
        '✅ TensorflowService initialized successfully',
        name: 'TensorflowService',
      );
    } catch (e) {
      log(
        '❌ Failed to initialize TensorflowService: $e',
        name: 'TensorflowService',
      );
      rethrow;
    }
  }

  /// Load the TFLite model
  Future<void> _loadModel() async {
    try {
      // Use appropriate delegate based on platform
      final delegate = switch (defaultTargetPlatform) {
        TargetPlatform.iOS => GpuDelegate(),
        TargetPlatform.android => GpuDelegateV2(),
        _ => XNNPackDelegate(),
      };

      final options = InterpreterOptions()
        ..threads = 4
        ..addDelegate(delegate);

      _interpreter = await Interpreter.fromAsset(modelPath, options: options);

      // Log tensor info
      final inputTensors = _interpreter!.getInputTensors();
      final outputTensors = _interpreter!.getOutputTensors();

      log(
        'Input tensors: ${inputTensors.map((e) => '${e.name}: ${e.shape}').toList()}',
        name: 'TensorflowService',
      );
      log(
        'Output tensors: ${outputTensors.map((e) => '${e.name}: ${e.shape}').toList()}',
        name: 'TensorflowService',
      );

      _interpreter!.allocateTensors();
    } catch (e) {
      log('Failed to load model with GPU: $e', name: 'TensorflowService');

      // Try without GPU delegate as fallback
      try {
        final options = InterpreterOptions()..threads = 4;
        _interpreter = await Interpreter.fromAsset(modelPath, options: options);
        _interpreter!.allocateTensors();
        log('✅ Model loaded with CPU fallback', name: 'TensorflowService');
      } catch (e2) {
        log(
          '❌ Failed to load model with CPU fallback: $e2',
          name: 'TensorflowService',
        );
        rethrow;
      }
    }
  }

  /// Load labels from file
  Future<void> _loadLabels() async {
    try {
      final labelsRaw = await rootBundle.loadString(labelPath);
      _labels = labelsRaw
          .split('\n')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      log('Loaded ${_labels!.length} labels', name: 'TensorflowService');
    } catch (e) {
      log(
        'Failed to load labels, using defaults: $e',
        name: 'TensorflowService',
      );
      _labels = AppConstants.supportedClasses;
    }
  }

  /// Dispose resources
  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isInitialized = false;
  }
}
