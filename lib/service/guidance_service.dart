import 'dart:async';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:finding_buddy/models/detected_object/detected_object_dm.dart';
import 'package:finding_buddy/service/dark_quaility.dart';
import 'package:finding_buddy/service/detector.dart';
import 'package:finding_buddy/service/storage_service.dart';
import 'package:finding_buddy/service/tts_service.dart';
import 'package:finding_buddy/utils/app_constants.dart';
import 'package:get/get.dart';
import 'package:vibration/vibration.dart';

enum GuidanceState {
  idle,
  searching,
  tracking,
  reached,
  notFound,
  error,
  poorQuality,
}

class GuidanceService extends GetxService {
  final RxList<DetectedObjectDm> allDetections = <DetectedObjectDm>[].obs;
  final Rx<GuidanceState> state = GuidanceState.idle.obs;
  final RxString targetObject = ''.obs;
  final Rx<DetectedObjectDm?> currentDetection = Rx<DetectedObjectDm?>(null);
  final RxInt clockPosition = 12.obs;
  final RxDouble estimatedDistance = 0.0.obs;
  final RxString guidanceMessage = ''.obs;
  final RxBool isObjectVisible = false.obs;

  Detector? _detector;
  StreamSubscription? _detectionSubscription;
  Timer? _guidanceTimer;
  Timer? _searchTimeoutTimer;

  // REAL-TIME MODE: No persistence, immediate updates
  static const int _searchTimeoutSeconds = 45;

  CameraQualityResult? _lastQualityCheck;

  // Speech timing
  DateTime? _lastGuidanceSpokenTime;
  static const int _minGuidanceIntervalMs = 2500; // 2.5 seconds
  DateTime? _lastNotVisibleSpokenTime;
  static const int _notVisibleSpeechIntervalMs = 4000; // 4 seconds

  // Last frame info for display
  Size? _lastImageSize;

  static GuidanceService get to => Get.find<GuidanceService>();

  /// Start detection for a target object
  Future<void> startDetection(String objectName) async {
    if (state.value != GuidanceState.idle) {
      await stopDetection();
    }

    targetObject.value = objectName;
    state.value = GuidanceState.searching;

    _lastQualityCheck = null;
    _lastGuidanceSpokenTime = null;
    _lastNotVisibleSpokenTime = null;

    // Start detector
    _detector ??= await Detector.start();
    _detector!.setTargetClass(objectName);
    _detector!.setMinConfidence(AppConstants.confidenceThreshold);
    _detector!.setQualityChecksEnabled(true);

    // Listen to detection results
    _detectionSubscription = _detector!.resultsStream.listen(
      _handleDetectionResult,
    );

    // Start guidance timer
    _startGuidanceTimer();

    // Start search timeout
    _startSearchTimeout();

    // Announce start
    final isArabic = StorageService.to.isArabic;
    final message = isArabic
        ? 'جاري البحث عن $objectName'
        : 'Searching for $objectName';
    await TtsService.to.speak(message);
  }

  /// Handle detection results - REAL-TIME MODE
  void _handleDetectionResult(DetectionResult result) {
    _lastImageSize = result.imageSize;

    allDetections.value = result.detections; // ← ADD THIS LINE
    // print(result.qualityResult.toString() + 'arbaz');
    // // STEP 1: CHECK CAMERA QUALITY
    // if (result.qualityResult != null) {
    //   _handleQualityCheck(result.qualityResult!);
    // }

    if (state.value == GuidanceState.poorQuality) {
      return;
    }

    // STEP 2: REAL-TIME DETECTION (no persistence)
    if (result.detections.isEmpty) {
      // Immediately mark as not visible
      isObjectVisible.value = false;
      currentDetection.value = null;

      if (state.value == GuidanceState.tracking) {
        state.value = GuidanceState.searching;
      }
      return;
    }

    // Get the closest detection (smallest distance in meters)
    final detection = result.detections.getClosest();
    if (detection == null) {
      isObjectVisible.value = false;
      currentDetection.value = null;
      if (state.value == GuidanceState.tracking) {
        state.value = GuidanceState.searching;
      }
      return;
    }

    // REAL-TIME: Immediately update with current detection
    isObjectVisible.value = true;
    currentDetection.value = detection;

    // Use COMPLETE DetectedObjectDm data
    clockPosition.value = detection.clockPosition;
    estimatedDistance.value = detection.distanceMeters;

    // Update state
    if (state.value != GuidanceState.tracking) {
      state.value = GuidanceState.tracking;
    }

    // Reset search timeout
    _startSearchTimeout();

    // Check if reached (30% coverage threshold)
    if (detection.areaPercentage >= 0.30) {
      _handleObjectReached();
    }
  }

  /// Handle camera quality check

  /// Handle object reached
  Future<void> _handleObjectReached() async {
    state.value = GuidanceState.reached;
    await _stopGuidanceTimer();
    _cancelSearchTimeout();
    allDetections.clear();

    if (StorageService.to.isHapticFeedbackEnabled) {
      Vibration.vibrate(duration: 500, amplitude: 255);
    }

    await TtsService.to.speakReached();
  }

  /// Start guidance timer - OPTIMIZED
  void _startGuidanceTimer() {
    _guidanceTimer?.cancel();

    // Fast UI updates, controlled speech
    _guidanceTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _updateGuidanceUI();
      _maybeAnnounceGuidance();
    });
  }

  /// Update UI guidance - REAL-TIME
  void _updateGuidanceUI() {
    if (state.value == GuidanceState.reached ||
        state.value == GuidanceState.idle ||
        state.value == GuidanceState.notFound) {
      return;
    }

    if (state.value == GuidanceState.poorQuality) {
      guidanceMessage.value =
          _lastQualityCheck?.message ?? 'Camera quality issue';
      return;
    }

    final isArabic = StorageService.to.isArabic;

    if (isObjectVisible.value && currentDetection.value != null) {
      final detection = currentDetection.value!;

      // Use enhanced DetectedObjectDm methods
      final direction = detection.getDirectionString(isArabic: isArabic);
      final distance = detection.distanceString;

      guidanceMessage.value = isArabic
          ? '$direction، $distance'
          : '$direction, $distance';
    } else {
      guidanceMessage.value = isArabic
          ? 'غير مرئي. يرجى الدوران ببطء'
          : 'Not in view. Please turn slowly';
    }
  }

  /// Announce guidance with timing control
  Future<void> _maybeAnnounceGuidance() async {
    if (state.value == GuidanceState.reached ||
        state.value == GuidanceState.idle ||
        state.value == GuidanceState.notFound ||
        state.value == GuidanceState.poorQuality) {
      return;
    }

    if (TtsService.to.isSpeaking.value) return;

    final now = DateTime.now();

    if (isObjectVisible.value && currentDetection.value != null) {
      if (_lastGuidanceSpokenTime != null) {
        final elapsed = now.difference(_lastGuidanceSpokenTime!).inMilliseconds;
        if (elapsed < _minGuidanceIntervalMs) return;
      }

      _lastGuidanceSpokenTime = now;
      await TtsService.to.speak(guidanceMessage.value);

      if (StorageService.to.isHapticFeedbackEnabled) {
        Vibration.vibrate(duration: 50);
      }
    } else {
      if (_lastNotVisibleSpokenTime != null) {
        final elapsed = now
            .difference(_lastNotVisibleSpokenTime!)
            .inMilliseconds;
        if (elapsed < _notVisibleSpeechIntervalMs) return;
      }

      _lastNotVisibleSpokenTime = now;
      await TtsService.to.speak(guidanceMessage.value);
    }
  }

  /// Stop guidance timer
  Future<void> _stopGuidanceTimer() async {
    _guidanceTimer?.cancel();
    _guidanceTimer = null;
  }

  /// Start search timeout
  void _startSearchTimeout() {
    _searchTimeoutTimer?.cancel();
    _searchTimeoutTimer = Timer(
      const Duration(seconds: _searchTimeoutSeconds),
      _handleSearchTimeout,
    );
  }

  /// Cancel search timeout
  void _cancelSearchTimeout() {
    _searchTimeoutTimer?.cancel();
    _searchTimeoutTimer = null;
  }

  /// Handle search timeout
  Future<void> _handleSearchTimeout() async {
    if (state.value == GuidanceState.searching) {
      state.value = GuidanceState.notFound;
      await TtsService.to.speakNotFound();
      await stopDetection();
    }
  }

  /// Process camera frame
  void processFrame(dynamic cameraImage, CameraController cont) {
    if (state.value == GuidanceState.idle ||
        state.value == GuidanceState.reached ||
        state.value == GuidanceState.notFound) {
      return;
    }

    _detector?.processFrame(cameraImage, cont);
  }

  /// Stop detection
  Future<void> stopDetection() async {
    state.value = GuidanceState.idle;
    _stopGuidanceTimer();
    _cancelSearchTimeout();

    _detectionSubscription?.cancel();
    _detectionSubscription = null;

    targetObject.value = '';
    currentDetection.value = null;
    isObjectVisible.value = false;
    guidanceMessage.value = '';

    _lastQualityCheck = null;
    _lastGuidanceSpokenTime = null;
    _lastNotVisibleSpokenTime = null;
    allDetections.clear();

    await TtsService.to.stop();
  }

  /// Dispose detector
  void disposeDetector() {
    stopDetection();
    _detector?.stop();
    _detector = null;
  }

  @override
  void onClose() {
    disposeDetector();
    super.onClose();
  }
}
