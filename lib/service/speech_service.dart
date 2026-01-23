import 'dart:async';
import 'package:finding_buddy/service/storage_service.dart';
import 'package:finding_buddy/utils/app_constants.dart';
import 'package:get/get.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

enum SpeechState { idle, listening, processing, paused }

/// Identifies which module is using speech
enum SpeechOwner { none, home, detection }

/// Callback holder for each owner
class SpeechCallbacks {
  Function(String)? onCommandRecognized;
  Function(List<String>)? onMultipleObjectsDetected;
  Function(String)? onError;
  Function()? onWakeWordOnly;

  void clear() {
    onCommandRecognized = null;
    onMultipleObjectsDetected = null;
    onError = null;
    onWakeWordOnly = null;
  }
}

class SpeechService extends GetxService {
  late SpeechToText _speechToText;

  final Rx<SpeechState> state = SpeechState.idle.obs;
  final RxBool isAvailable = false.obs;
  final RxString lastRecognizedWords = ''.obs;

  // ═══════════════════════════════════════════════════════════════════
  // OWNERSHIP & LIFECYCLE
  // ═══════════════════════════════════════════════════════════════════

  /// Current owner of speech recognition
  final Rx<SpeechOwner> currentOwner = SpeechOwner.none.obs;

  /// Track if user MANUALLY paused
  final RxBool isManuallyPaused = false.obs;

  /// Track if paused for navigation
  final RxBool isPausedForNavigation = false.obs;

  /// Track if TTS is speaking
  final RxBool isTTSSpeaking = false.obs;

  // ═══════════════════════════════════════════════════════════════════
  // CALLBACKS - SEPARATE PER OWNER (KEY FIX!)
  // ═══════════════════════════════════════════════════════════════════

  final Map<SpeechOwner, SpeechCallbacks> _ownerCallbacks = {
    SpeechOwner.home: SpeechCallbacks(),
    SpeechOwner.detection: SpeechCallbacks(),
  };

  // Sentence completion tracking
  String _lastHeardText = '';
  DateTime? _lastWordTime;
  Timer? _sentenceCompleteTimer;
  bool _isProcessing = false;

  // ═══════════════════════════════════════════════════════════════════
  // TIMING CONSTANTS
  // ═══════════════════════════════════════════════════════════════════

  static const int _sentenceCompleteDelayMs = 2500;
  static const int _restartDelayMs = 2000;
  static const int _minRestartGapMs = 3000;
  static const int _listenDurationSeconds = 60;
  static const int _pauseForSeconds = 10; // Increased more

  DateTime? _lastRestartTime;

  // Timers
  Timer? _restartListeningTimer;
  Timer? _ttsBlockTimer;
  Timer? _silenceTimer;

  static SpeechService get to => Get.find<SpeechService>();

  Future<SpeechService> init() async {
    _speechToText = SpeechToText();

    try {
      isAvailable.value = await _speechToText.initialize(
        onStatus: _onStatus,
        onError: _onError,
        debugLogging: false,
      );
      print('🎤 Speech initialized: ${isAvailable.value}');
    } catch (e) {
      print('🎤 Speech init error: $e');
      isAvailable.value = false;
    }

    return this;
  }

  // ═══════════════════════════════════════════════════════════════════
  // CALLBACK REGISTRATION - PER OWNER
  // ═══════════════════════════════════════════════════════════════════

  /// Register callbacks for a specific owner
  void registerCallbacks({
    required SpeechOwner owner,
    Function(String)? onCommandRecognized,
    Function(List<String>)? onMultipleObjectsDetected,
    Function(String)? onError,
    Function()? onWakeWordOnly,
  }) {
    print('🎤 Registering callbacks for $owner');

    final callbacks = _ownerCallbacks[owner];
    if (callbacks != null) {
      callbacks.onCommandRecognized = onCommandRecognized;
      callbacks.onMultipleObjectsDetected = onMultipleObjectsDetected;
      callbacks.onError = onError;
      callbacks.onWakeWordOnly = onWakeWordOnly;
    }
  }

  /// Clear callbacks for a specific owner
  void clearCallbacks(SpeechOwner owner) {
    print('🎤 Clearing callbacks for $owner');
    _ownerCallbacks[owner]?.clear();
  }

  /// Get current owner's callbacks
  SpeechCallbacks? get _currentCallbacks {
    if (currentOwner.value == SpeechOwner.none) return null;
    return _ownerCallbacks[currentOwner.value];
  }

  // ═══════════════════════════════════════════════════════════════════
  // STATUS & ERROR HANDLERS
  // ═══════════════════════════════════════════════════════════════════

  void _onStatus(String status) {
    print(
      '🎤 Status: $status, owner: ${currentOwner.value}, manual: ${isManuallyPaused.value}',
    );

    if (status == 'done' || status == 'notListening') {
      if (_shouldAutoRestart()) {
        _processFinalSentence();
        _scheduleRestartListening();
      } else {
        print('🎤 Not restarting - conditions not met');
        if (state.value == SpeechState.listening) {
          state.value = SpeechState.idle;
        }
      }
    }
  }

  void _onError(dynamic error) {
    print('🎤 Error: $error');

    // Check if it's a "no match" or similar non-critical error
    final errorStr = error.toString().toLowerCase();
    final isNonCritical =
        errorStr.contains('no match') ||
        errorStr.contains('no speech') ||
        errorStr.contains('error_no_match') ||
        errorStr.contains('error_speech_timeout');

    if (isNonCritical) {
      print('🎤 Non-critical error, will restart if conditions met');
    }

    if (_shouldAutoRestart()) {
      _processFinalSentence();
      _scheduleRestartListening();
    }
  }

  bool _shouldAutoRestart() {
    if (isManuallyPaused.value) {
      print('🎤 Skip: manually paused');
      return false;
    }

    if (isPausedForNavigation.value) {
      print('🎤 Skip: navigation pause');
      return false;
    }

    if (isTTSSpeaking.value) {
      print('🎤 Skip: TTS speaking');
      return false;
    }

    if (currentOwner.value == SpeechOwner.none) {
      print('🎤 Skip: no owner');
      return false;
    }

    if (!StorageService.to.isVoiceEnabled) {
      print('🎤 Skip: voice disabled');
      return false;
    }

    if (_lastRestartTime != null) {
      final gap = DateTime.now().difference(_lastRestartTime!).inMilliseconds;
      if (gap < _minRestartGapMs) {
        print('🎤 Skip: too soon (${gap}ms)');
        return false;
      }
    }

    return true;
  }

  void _scheduleRestartListening() {
    _restartListeningTimer?.cancel();

    if (!_shouldAutoRestart()) return;

    print('🎤 Scheduling restart in ${_restartDelayMs}ms');

    _restartListeningTimer = Timer(
      const Duration(milliseconds: _restartDelayMs),
      () {
        if (_shouldAutoRestart() && state.value != SpeechState.processing) {
          _lastRestartTime = DateTime.now();
          _startListening();
        }
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // OWNERSHIP MANAGEMENT
  // ═══════════════════════════════════════════════════════════════════

  /// Acquire speech ownership
  Future<bool> acquireOwnership(SpeechOwner owner) async {
    print('🎤 ═══════════════════════════════════════');
    print('🎤 Acquiring ownership: $owner (current: ${currentOwner.value})');

    // If same owner, just return
    if (currentOwner.value == owner) {
      print('🎤 Already owned by $owner');
      return true;
    }

    // If someone else owns it, release first
    if (currentOwner.value != SpeechOwner.none) {
      print('🎤 Releasing previous owner: ${currentOwner.value}');
      await _forceRelease();
    }

    // Full reset before new owner takes over
    await _fullReset();

    currentOwner.value = owner;
    isManuallyPaused.value = false;
    isPausedForNavigation.value = false;

    print('🎤 Ownership acquired by $owner');
    print('🎤 ═══════════════════════════════════════');

    return true;
  }

  /// Release speech ownership
  Future<void> releaseOwnership(SpeechOwner owner) async {
    print('🎤 ═══════════════════════════════════════');
    print('🎤 Releasing ownership: $owner (current: ${currentOwner.value})');

    if (currentOwner.value != owner) {
      print('🎤 Warning: $owner is not current owner');
      return;
    }

    await _forceRelease();

    print('🎤 Ownership released by $owner');
    print('🎤 ═══════════════════════════════════════');
  }

  /// Force release without owner check
  Future<void> _forceRelease() async {
    _cancelAllTimers();
    await _stopListeningInternal();
    _resetProcessingState();
    currentOwner.value = SpeechOwner.none;
    state.value = SpeechState.idle;
  }

  /// Full reset of all state
  Future<void> _fullReset() async {
    print('🎤 Full reset');
    _cancelAllTimers();
    await _stopListeningInternal();
    _resetProcessingState();

    // Wait a bit for speech engine to fully stop
    await Future.delayed(const Duration(milliseconds: 300));

    state.value = SpeechState.idle;
    lastRecognizedWords.value = '';
  }

  // ═══════════════════════════════════════════════════════════════════
  // NAVIGATION LIFECYCLE
  // ═══════════════════════════════════════════════════════════════════

  /// Pause for navigation
  Future<void> pauseForNavigation() async {
    print('🎤 Pausing for navigation');
    isPausedForNavigation.value = true;

    _cancelAllTimers();
    await _stopListeningInternal();

    state.value = SpeechState.paused;
  }

  /// Resume after navigation
  Future<void> resumeAfterNavigation(SpeechOwner owner) async {
    print('🎤 ═══════════════════════════════════════');
    print('🎤 Resuming after navigation for $owner');
    print(
      '🎤 Current owner: ${currentOwner.value}, manually paused: ${isManuallyPaused.value}',
    );

    // Take ownership
    if (currentOwner.value != owner) {
      await acquireOwnership(owner);
    }

    isPausedForNavigation.value = false;

    // CRITICAL: Don't resume if manually paused
    if (isManuallyPaused.value) {
      print('🎤 Not resuming: manually paused by user');
      state.value = SpeechState.idle;
      return;
    }

    if (!StorageService.to.isVoiceEnabled) {
      print('🎤 Not resuming: voice disabled');
      state.value = SpeechState.idle;
      return;
    }

    // Wait before starting
    await Future.delayed(const Duration(milliseconds: 500));

    // Start fresh
    _resetProcessingState();
    await _startListening();

    print('🎤 Resumed for $owner, state: ${state.value}');
    print('🎤 ═══════════════════════════════════════');
  }

  // ═══════════════════════════════════════════════════════════════════
  // MANUAL PAUSE/RESUME
  // ═══════════════════════════════════════════════════════════════════

  /// User manually pauses
  Future<void> manualPause() async {
    print('🎤 Manual pause by user');
    isManuallyPaused.value = true;

    _cancelAllTimers();
    await _stopListeningInternal();

    state.value = SpeechState.idle;
  }

  /// User manually resumes
  Future<void> manualResume(SpeechOwner owner) async {
    print('🎤 Manual resume by user for $owner');

    isManuallyPaused.value = false;
    isPausedForNavigation.value = false;

    if (currentOwner.value != owner) {
      await acquireOwnership(owner);
    }

    if (StorageService.to.isVoiceEnabled) {
      _resetProcessingState();
      await _startListening();
    }
  }

  /// Toggle listening
  Future<void> toggleListening(SpeechOwner owner) async {
    print(
      '🎤 Toggle for $owner, current state: ${state.value}, manual: ${isManuallyPaused.value}',
    );

    if (state.value == SpeechState.listening) {
      await manualPause();
    } else {
      await manualResume(owner);
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // TTS INTEGRATION
  // ═══════════════════════════════════════════════════════════════════

  Future<void> pauseForTTS() async {
    print('🔇 Pausing for TTS');
    isTTSSpeaking.value = true;

    _sentenceCompleteTimer?.cancel();
    _silenceTimer?.cancel();
    _restartListeningTimer?.cancel();

    await _stopListeningInternal();
  }

  Future<void> resumeAfterTTS({int delayMs = 1200}) async {
    print('🔊 Resuming after TTS (delay: ${delayMs}ms)');

    _ttsBlockTimer?.cancel();
    _ttsBlockTimer = Timer(Duration(milliseconds: delayMs), () {
      isTTSSpeaking.value = false;
      _resetProcessingState();

      if (_shouldAutoRestart()) {
        _lastRestartTime = DateTime.now();
        _startListening();
      }
    });
  }

  // ═══════════════════════════════════════════════════════════════════
  // MAIN LISTENING LOGIC
  // ═══════════════════════════════════════════════════════════════════

  /// Public method to start listening
  Future<void> startListeningForWakeWord(SpeechOwner owner) async {
    print('🎤 startListeningForWakeWord for $owner');

    if (!isAvailable.value) {
      print('🎤 Cannot start: not available');
      return;
    }

    if (!StorageService.to.isVoiceEnabled) {
      print('🎤 Cannot start: voice disabled');
      return;
    }

    // Ensure we own it
    if (currentOwner.value != owner) {
      await acquireOwnership(owner);
    }

    // Stop any existing session
    await _stopListeningInternal();
    await Future.delayed(const Duration(milliseconds: 300));

    _resetProcessingState();
    await _startListening();
  }

  /// Internal start listening
  Future<void> _startListening() async {
    // Pre-flight checks
    if (!isAvailable.value) return;
    if (isTTSSpeaking.value) return;
    if (_isProcessing) return;
    if (isPausedForNavigation.value) return;
    if (isManuallyPaused.value) return;
    if (currentOwner.value == SpeechOwner.none) return;

    // Check if already listening
    if (_speechToText.isListening) {
      print('🎤 Already listening, skipping start');
      return;
    }

    state.value = SpeechState.listening;

    final isArabic = StorageService.to.isArabic;
    final localeId = isArabic ? 'ar_SA' : 'en_US';

    try {
      print('🎤 Starting to listen (owner: ${currentOwner.value})...');

      await _speechToText.listen(
        onResult: _handleSpeechResult,
        listenFor: const Duration(seconds: _listenDurationSeconds),
        pauseFor: const Duration(seconds: _pauseForSeconds),
        localeId: localeId,
        listenMode: ListenMode.dictation,
        cancelOnError: false,
        partialResults: true,
      );

      _startSilenceMonitor();
      print('🎤 Listening started successfully');
    } catch (e) {
      print('🎤 Listen error: $e');
      state.value = SpeechState.idle;

      if (_shouldAutoRestart()) {
        _scheduleRestartListening();
      }
    }
  }

  /// Monitor silence
  void _startSilenceMonitor() {
    _silenceTimer?.cancel();

    _silenceTimer = Timer(const Duration(seconds: 45), () {
      if (state.value == SpeechState.listening &&
          _lastHeardText.isEmpty &&
          _shouldAutoRestart()) {
        print('🎤 Extended silence - gentle restart');
        _gentleRestart();
      }
    });
  }

  /// Gentle restart
  Future<void> _gentleRestart() async {
    await _stopListeningInternal();
    await Future.delayed(const Duration(milliseconds: 500));

    if (_shouldAutoRestart()) {
      _lastRestartTime = DateTime.now();
      await _startListening();
    }
  }

  /// Internal stop
  Future<void> _stopListeningInternal() async {
    try {
      if (_speechToText.isListening) {
        await _speechToText.stop();
        print('🎤 Stopped listening');
      }
    } catch (e) {
      print('🎤 Stop error: $e');
    }
  }

  /// Public stop
  Future<void> stopListeningForWakeWord() async {
    print('🎤 Stopping...');

    _cancelAllTimers();
    _resetProcessingState();

    await _stopListeningInternal();
    state.value = SpeechState.idle;
  }

  void _resetProcessingState() {
    _lastHeardText = '';
    _lastWordTime = null;
    _isProcessing = false;
    _sentenceCompleteTimer?.cancel();
  }

  void _cancelAllTimers() {
    _sentenceCompleteTimer?.cancel();
    _sentenceCompleteTimer = null;
    _restartListeningTimer?.cancel();
    _restartListeningTimer = null;
    _ttsBlockTimer?.cancel();
    _ttsBlockTimer = null;
    _silenceTimer?.cancel();
    _silenceTimer = null;
  }

  // ═══════════════════════════════════════════════════════════════════
  // SPEECH RESULT HANDLING
  // ═══════════════════════════════════════════════════════════════════

  void _handleSpeechResult(SpeechRecognitionResult result) {
    final text = result.recognizedWords.toLowerCase().trim();
    if (text.isEmpty) return;

    // Reset silence timer
    _startSilenceMonitor();

    // Skip if shouldn't process
    if (isTTSSpeaking.value ||
        _isProcessing ||
        isPausedForNavigation.value ||
        isManuallyPaused.value) {
      print('🔇 Skipping result');
      return;
    }

    // Check owner is valid
    if (currentOwner.value == SpeechOwner.none) {
      print('🎤 No owner, ignoring result');
      return;
    }

    print(
      '🎤 Heard: "$text" (final: ${result.finalResult}, owner: ${currentOwner.value})',
    );

    _lastHeardText = text;
    _lastWordTime = DateTime.now();
    lastRecognizedWords.value = text;

    _sentenceCompleteTimer?.cancel();

    if (result.finalResult) {
      print('✅ Final result, processing');
      _processFinalSentence();
    } else {
      _sentenceCompleteTimer = Timer(
        const Duration(milliseconds: _sentenceCompleteDelayMs),
        () {
          if (!isPausedForNavigation.value && !isManuallyPaused.value) {
            print('⏰ Timeout, processing');
            _processFinalSentence();
          }
        },
      );
    }
  }

  void _processFinalSentence() {
    _sentenceCompleteTimer?.cancel();

    final text = _lastHeardText.trim();
    if (text.isEmpty || _isProcessing) return;

    // Verify owner is still valid
    if (currentOwner.value == SpeechOwner.none) {
      print('🎤 No owner during processing, aborting');
      return;
    }

    print('✅ Processing: "$text" for ${currentOwner.value}');
    _isProcessing = true;
    state.value = SpeechState.processing;

    _stopListeningInternal();

    // Extract objects
    final detectedObjects = _extractAllObjectsFromSentence(text);

    if (detectedObjects.isEmpty) {
      print('⚠️ No object detected');
      _isProcessing = false;
      state.value = SpeechState.idle;
      _lastHeardText = ''; // Clear so we don't re-process

      if (_shouldAutoRestart()) {
        _scheduleRestartListening();
      }
      return;
    }

    // Success! Call the CURRENT OWNER's callbacks
    _isProcessing = false;
    state.value = SpeechState.idle;
    _lastHeardText = ''; // Clear

    final callbacks = _currentCallbacks;
    if (callbacks == null) {
      print('🎤 No callbacks for ${currentOwner.value}');
      return;
    }

    if (detectedObjects.length == 1) {
      print('✅ Single object: ${detectedObjects[0]} -> ${currentOwner.value}');
      callbacks.onCommandRecognized?.call(detectedObjects[0]);
    } else {
      print('✅ Multiple objects: $detectedObjects -> ${currentOwner.value}');
      callbacks.onMultipleObjectsDetected?.call(detectedObjects);
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // OBJECT EXTRACTION
  // ═══════════════════════════════════════════════════════════════════

  List<String> _extractAllObjectsFromSentence(String sentence) {
    final detectedObjects = <String>[];
    const supportedClasses = AppConstants.supportedClasses;

    for (final label in supportedClasses) {
      final normalizedLabel = label.toLowerCase();

      if (sentence.contains(normalizedLabel)) {
        if (!detectedObjects.contains(label)) {
          detectedObjects.add(label);
        }
        continue;
      }

      final synonyms = _getSynonymsForLabel(label);
      for (final synonym in synonyms) {
        if (sentence.contains(synonym.toLowerCase())) {
          if (!detectedObjects.contains(label)) {
            detectedObjects.add(label);
          }
          break;
        }
      }
    }

    return detectedObjects;
  }

  List<String> _getSynonymsForLabel(String label) {
    const synonymMap = {
      'cell phone': ['phone', 'mobile', 'cellphone', 'smartphone', 'fon'],
      'laptop': ['computer', 'notebook', 'leptop'],
      'cup': ['mug', 'glass', 'kup'],
      'remote': ['remote control', 'tv remote'],
      'tv': ['television', 'monitor'],
      'bottle': ['water bottle', 'botal'],
      'backpack': ['bag', 'school bag'],
      'handbag': ['purse', 'wallet'],
      'keyboard': ['keys', 'keybord'],
      'mouse': ['computer mouse'],
      'couch': ['sofa'],
      'dining table': ['table'],
      'refrigerator': ['fridge'],
      'hair drier': ['hair dryer', 'dryer', 'blow dryer'],
    };

    return synonymMap[label.toLowerCase()] ?? [];
  }

  // ═══════════════════════════════════════════════════════════════════
  // PUBLIC GETTERS
  // ═══════════════════════════════════════════════════════════════════

  bool get isListening => _speechToText.isListening;
  bool get isListeningForWake => state.value == SpeechState.listening;
  bool get isActivelyListening =>
      state.value == SpeechState.listening &&
      !isManuallyPaused.value &&
      currentOwner.value != SpeechOwner.none;

  Future<void> stopListening() async {
    await stopListeningForWakeWord();
  }

  @override
  void onClose() {
    _cancelAllTimers();
    stopListening();
    super.onClose();
  }
}
