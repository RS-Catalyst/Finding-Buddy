// ignore_for_file: avoid_print

import 'dart:async';
import 'package:camera/camera.dart';
import 'package:finding_buddy/models/detected_object/detected_object_dm.dart';
import 'package:finding_buddy/models/detected_object/quality.dart';
import 'package:finding_buddy/service/guidance_service.dart';
import 'package:finding_buddy/service/speech_service.dart';
import 'package:finding_buddy/service/storage_service.dart';
import 'package:finding_buddy/service/synonyms_service.dart';
import 'package:finding_buddy/service/tts_service.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:finding_buddy/utils/app_constants.dart';

class DetectionController extends GetxController {
  final RxBool isCountdownActive = false.obs;
  final RxInt countdownValue = 3.obs;
  // Camera
  CameraController? cameraController;
  final RxBool isCameraInitialized = false.obs;
  final RxBool isCameraPermissionGranted = false.obs;
  final RxBool isMicPermissionGranted = false.obs;
  final RxInt selectedCameraIndex = 0.obs;
  List<CameraDescription> cameras = [];

  // Detection state
  final RxBool isDetecting = false.obs;
  final RxBool showCameraView = true.obs;
  final RxString targetObject = ''.obs;
  final Rx<DetectedObjectDm?> currentDetection = Rx<DetectedObjectDm?>(null);

  // Guidance
  final RxInt clockPosition = 12.obs;
  final RxDouble estimatedDistance = 0.0.obs;
  final RxString guidanceMessage = ''.obs;
  final RxBool isObjectVisible = false.obs;
  final RxBool isObjectReached = false.obs;

  // Voice
  final RxBool isListening = false.obs;
  final RxBool isWaitingForCommand = false.obs;

  bool _speechEnabled = false;
  Worker? _stateWorker;

  // Camera Quality
  final Rx<CameraQualityResult?> cameraQuality = Rx<CameraQualityResult?>(null);
  final RxBool isQualityPoor = false.obs;
  DateTime? _lastQualityCheck;
  DateTime? _lastQualityAlert;

  // Error state
  final RxString errorMessage = ''.obs;

  // Camera lifecycle
  bool _isDisposed = false;
  bool _isStreamingActive = false;
  DateTime? _lastProcessTime;

  @override
  void onInit() {
    super.onInit();
    _initialize();
  }

  Future<void> _initialize() async {
    _isDisposed = false;
    await _requestPermissions();
    await _initializeCamera();
    _setupGuidanceListeners();

    showCameraView.value = StorageService.to.showCameraPreview;

    // Check for target from navigation
    final args = Get.arguments;
    if (args != null && args is Map && args.containsKey('target')) {
      final detectedTarget = args['target'] as String?;
      if (detectedTarget != null) {
        startDetectionForObject(detectedTarget);
      }
    }
  }

  Future<void> _requestPermissions() async {
    final cameraStatus = await Permission.camera.request();
    final micStatus = await Permission.microphone.request();

    isCameraPermissionGranted.value = cameraStatus.isGranted;
    isMicPermissionGranted.value = micStatus.isGranted;

    if (!cameraStatus.isGranted) {
      errorMessage.value = 'Camera permission required';
    }
  }

  Future<void> _initializeCamera() async {
    if (!isCameraPermissionGranted.value || _isDisposed) return;

    try {
      cameras = await availableCameras();
      if (cameras.isEmpty) {
        errorMessage.value = 'No camera available';
        return;
      }

      await _setupCamera(selectedCameraIndex.value);
    } catch (e) {
      errorMessage.value = 'Failed to initialize camera: $e';
    }
  }

  Future<void> _setupCamera(int index) async {
    if (cameras.isEmpty || _isDisposed) return;

    final camera = cameras[index];

    if (cameraController != null) {
      if (_isStreamingActive) {
        try {
          await cameraController!.stopImageStream();
        } catch (e) {
          print('Error stopping stream: $e');
        }
        _isStreamingActive = false;
      }

      try {
        await cameraController!.dispose();
      } catch (e) {
        print('Error disposing camera: $e');
      }
    }

    cameraController = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    try {
      await cameraController!.initialize();
      if (!_isDisposed) {
        isCameraInitialized.value = true;
      }
    } catch (e) {
      errorMessage.value = 'Camera initialization failed: $e';
    }
  }

  void _setupGuidanceListeners() {
    final guidance = GuidanceService.to;

    ever(guidance.state, (GuidanceState state) {
      switch (state) {
        case GuidanceState.idle:
          isDetecting.value = false;
          isObjectReached.value = false;
          break;
        case GuidanceState.searching:
        case GuidanceState.tracking:
          isDetecting.value = true;
          isObjectReached.value = false;
          break;
        case GuidanceState.reached:
          isDetecting.value = false;
          isObjectReached.value = true;
          break;
        case GuidanceState.notFound:
        case GuidanceState.error:
        case GuidanceState.poorQuality:
          isDetecting.value = false;
          isObjectReached.value = false;
          break;
      }
    });

    ever(guidance.currentDetection, (DetectedObjectDm? detection) {
      currentDetection.value = detection;
    });

    ever(guidance.clockPosition, (int pos) {
      clockPosition.value = pos;
    });

    ever(guidance.estimatedDistance, (double dist) {
      estimatedDistance.value = dist;
    });

    ever(guidance.guidanceMessage, (String msg) {
      guidanceMessage.value = msg;
    });

    ever(guidance.isObjectVisible, (bool visible) {
      isObjectVisible.value = visible;
    });
  }

  // ═══════════════════════════════════════════════════════════════════
  // SPEECH FOR DETECTION - COMPLETELY SEPARATE FROM HOME
  // ═══════════════════════════════════════════════════════════════════

  /// Setup and enable speech for detection screen
  void setupSpeechListeners() {
    if (_speechEnabled) return;

    print('🔍 ═══════════════════════════════════════');
    print('🔍 Setting up speech for detection');

    final speech = SpeechService.to;

    // Register DETECTION's callbacks (separate from home)
    speech.registerCallbacks(
      owner: SpeechOwner.detection,
      onCommandRecognized: (objectName) {
        print('🔍 Detection callback: $objectName');
        isWaitingForCommand.value = false;
        isListening.value = false;
        startDetectionForObject(objectName);
      },
      onError: (error) {
        print('🔍 Detection error: $error');
        isWaitingForCommand.value = false;
        isListening.value = false;
        if (error.startsWith('unsupported:')) {
          final obj = error.replaceFirst('unsupported:', '');
          TtsService.to.speakUnsupported(obj);
        }
      },
    );

    // Dispose old worker
    _stateWorker?.dispose();

    // Setup state listener
    _stateWorker = ever(speech.state, (SpeechState state) {
      if (speech.currentOwner.value == SpeechOwner.detection) {
        isListening.value = state == SpeechState.listening;
      }
    });

    _speechEnabled = true;
    print('🔍 Speech setup complete');
    print('🔍 ═══════════════════════════════════════');
  }

  /// Enable speech listening for detection
  Future<void> enableSpeechForDetection() async {
    print('🔍 Enabling speech for detection');

    final speech = SpeechService.to;

    // Setup callbacks first
    setupSpeechListeners();

    // Acquire ownership
    await speech.acquireOwnership(SpeechOwner.detection);

    // Start listening
    await speech.startListeningForWakeWord(SpeechOwner.detection);

    isListening.value = speech.isActivelyListening;
    print('🔍 Speech enabled, listening: ${isListening.value}');
  }

  /// Disable speech for detection
  Future<void> disableSpeechForDetection() async {
    print('🔍 Disabling speech for detection');

    final speech = SpeechService.to;

    // Stop listening
    await speech.stopListeningForWakeWord();

    // Clear callbacks
    speech.clearCallbacks(SpeechOwner.detection);

    // Release ownership
    if (speech.currentOwner.value == SpeechOwner.detection) {
      await speech.releaseOwnership(SpeechOwner.detection);
    }

    // Dispose worker
    _stateWorker?.dispose();
    _stateWorker = null;

    _speechEnabled = false;
    isListening.value = false;

    print('🔍 Speech disabled');
  }

  /// Start detection for object
  /// Start detection for object with countdown
  Future<void> startDetectionForObject(String objectName) async {
    if (_isDisposed) return;

    final modelClass = SynonymService.instance.resolveToModelClass(objectName);
    if (modelClass == null) {
      await TtsService.to.speakUnsupported(objectName);
      return;
    }

    targetObject.value = modelClass;

    // Reset quality
    isQualityPoor.value = false;
    cameraQuality.value = null;
    _lastQualityCheck = null;
    _lastQualityAlert = null;

    // Start camera stream
    if (cameraController != null &&
        cameraController!.value.isInitialized &&
        !_isStreamingActive &&
        !_isDisposed) {
      try {
        await cameraController!.startImageStream(_onCameraFrame);
        _isStreamingActive = true;
      } catch (e) {
        print('Error starting image stream: $e');
        errorMessage.value = 'Failed to start camera stream';
        return;
      }
    }

    // Start countdown (UI only - processing already started)

    // Now start guidance (speech will happen after countdown)
    await GuidanceService.to.startDetection(modelClass);

    _startCountdown();
  }

  /// Countdown timer - just for UI delay, processing continues
  Future<void> _startCountdown() async {
    isCountdownActive.value = true;

    for (int i = 3; i >= 1; i--) {
      if (_isDisposed) break;
      countdownValue.value = i;
      await Future.delayed(const Duration(seconds: 1));
    }

    isCountdownActive.value = false;
  }

  void _onCameraFrame(CameraImage image) async {
    if (_isDisposed || !isDetecting.value) return;

    final now = DateTime.now();

    if (_lastQualityCheck == null ||
        now.difference(_lastQualityCheck!) > const Duration(seconds: 3)) {
      _lastQualityCheck = now;
      _checkCameraQuality(image);
    }

    if (isQualityPoor.value) return;

    if (_lastProcessTime != null &&
        now.difference(_lastProcessTime!) < const Duration(milliseconds: 100)) {
      return;
    }

    _lastProcessTime = now;

    if (cameraController == null || !cameraController!.value.isInitialized) {
      return;
    }

    GuidanceService.to.processFrame(image, cameraController!);
  }

  void _checkCameraQuality(CameraImage image) {
    try {
      final quality = CameraQualityDetector.checkQuality(image);
      cameraQuality.value = quality;

      final wasPoor = isQualityPoor.value;
      isQualityPoor.value = !quality.isGood;

      if (isQualityPoor.value && !wasPoor) {
        final now = DateTime.now();

        if (_lastQualityAlert == null ||
            now.difference(_lastQualityAlert!) > const Duration(seconds: 10)) {
          _lastQualityAlert = now;

          if (quality.isDark) {
            TtsService.to.speakDarkOrBlocked();
          } else if (quality.isBlocked) {
            TtsService.to.speak('Camera is blocked or covered');
          }
        }
      }
    } catch (e) {
      print('❌ Quality check error: $e');
    }
  }

  Future<void> stopDetection() async {
    await GuidanceService.to.stopDetection();

    if (cameraController != null && _isStreamingActive) {
      try {
        if (cameraController!.value.isInitialized &&
            cameraController!.value.isStreamingImages) {
          await cameraController!.stopImageStream();
        }
      } catch (e) {
        print('Error stopping stream: $e');
      }
      _isStreamingActive = false;
    }

    targetObject.value = '';
    currentDetection.value = null;
    isObjectReached.value = false;

    isQualityPoor.value = false;
    cameraQuality.value = null;
  }

  void toggleCameraView() {
    showCameraView.value = !showCameraView.value;
    StorageService.to.setShowCameraPreview(showCameraView.value);
  }

  Future<void> switchCamera() async {
    if (cameras.length < 2 || _isDisposed) return;

    final wasStreaming = _isStreamingActive;

    if (wasStreaming) {
      try {
        if (cameraController?.value.isStreamingImages ?? false) {
          await cameraController?.stopImageStream();
        }
      } catch (e) {
        print('Error stopping stream: $e');
      }
      _isStreamingActive = false;
    }

    selectedCameraIndex.value =
        (selectedCameraIndex.value + 1) % cameras.length;
    await _setupCamera(selectedCameraIndex.value);

    if (wasStreaming && isDetecting.value && !_isDisposed) {
      try {
        await cameraController?.startImageStream(_onCameraFrame);
        _isStreamingActive = true;
      } catch (e) {
        print('Error restarting stream: $e');
      }
    }
  }

  /// Legacy methods
  Future<void> startVoiceCommand() async {
    await enableSpeechForDetection();
  }

  Future<void> stopVoiceCommand() async {
    await disableSpeechForDetection();
  }

  void resetAfterFound() {
    isObjectReached.value = false;
    targetObject.value = '';
    currentDetection.value = null;
    guidanceMessage.value = '';
  }

  List<String> get supportedObjects => AppConstants.supportedClasses;

  @override
  void onClose() {
    print('🔍 ═══════════════════════════════════════');
    print('🔍 DetectionController closing');

    _isDisposed = true;

    // 1. Stop streaming
    if (_isStreamingActive) {
      try {
        cameraController?.stopImageStream();
      } catch (e) {
        print('Error stopping stream: $e');
      }
      _isStreamingActive = false;
    }

    // 2. Dispose camera
    try {
      cameraController?.dispose();
    } catch (e) {
      print('Error disposing camera: $e');
    }

    // 3. Stop guidance
    GuidanceService.to.stopDetection();

    // 4. CRITICAL: Properly release speech
    if (_speechEnabled) {
      final speech = SpeechService.to;

      // Clear detection callbacks
      speech.clearCallbacks(SpeechOwner.detection);

      // Release ownership if we have it
      if (speech.currentOwner.value == SpeechOwner.detection) {
        speech.releaseOwnership(SpeechOwner.detection);
      }

      _speechEnabled = false;
    }

    // 5. Dispose worker
    _stateWorker?.dispose();
    _stateWorker = null;

    print('🔍 DetectionController closed');
    print('🔍 ═══════════════════════════════════════');

    super.onClose();
  }
}
