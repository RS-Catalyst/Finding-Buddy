import 'dart:async';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:get/get.dart';
import 'package:finding_buddy/service/storage_service.dart';
import 'package:finding_buddy/service/speech_service.dart';

class TtsService extends GetxService {
  late FlutterTts _flutterTts;

  final RxBool isSpeaking = false.obs;
  final RxBool isInitialized = false.obs;

  final List<String> _messageQueue = [];
  bool _isProcessingQueue = false;

  int _minIntervalMs = 2000;
  DateTime? _lastSpeakTime;

  static TtsService get to => Get.find<TtsService>();

  Future<TtsService> init() async {
    _flutterTts = FlutterTts();

    await _flutterTts.setSharedInstance(true);
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);

    await _updateLanguage();

    _flutterTts.setStartHandler(() {
      isSpeaking.value = true;
    });

    _flutterTts.setCompletionHandler(() {
      isSpeaking.value = false;
      _resumeSpeechRecognition();
      _processQueue();
    });

    _flutterTts.setErrorHandler((error) {
      isSpeaking.value = false;
      _resumeSpeechRecognition();
      _processQueue();
    });

    _flutterTts.setCancelHandler(() {
      isSpeaking.value = false;
      _resumeSpeechRecognition();
    });

    isInitialized.value = true;
    return this;
  }

  Future<void> _pauseSpeechRecognition() async {
    try {
      if (Get.isRegistered<SpeechService>()) {
        await SpeechService.to.pauseForTTS();
      }
    } catch (e) {
      print('TTS: Pause error: $e');
    }
  }

  void _resumeSpeechRecognition() {
    try {
      if (Get.isRegistered<SpeechService>()) {
        SpeechService.to.resumeAfterTTS(delayMs: 800);
      }
    } catch (e) {
      print('TTS: Resume error: $e');
    }
  }

  Future<void> _updateLanguage() async {
    final isArabic = StorageService.to.isArabic;
    final language = isArabic ? 'ar-SA' : 'en-US';
    await _flutterTts.setLanguage(language);
  }

  void setMinInterval(double seconds) {
    _minIntervalMs = (seconds * 1000).toInt();
  }

  Future<void> speak(String text, {bool immediate = false}) async {
    if (!isInitialized.value || text.isEmpty) return;

    if (immediate) {
      await stop();
      await _speak(text);
    } else {
      _messageQueue.add(text);
      _processQueue();
    }
  }

  Future<void> speakGuidance(String text) async {
    if (!isInitialized.value || text.isEmpty) return;

    final now = DateTime.now();
    if (_lastSpeakTime != null) {
      final elapsed = now.difference(_lastSpeakTime!).inMilliseconds;
      if (elapsed < _minIntervalMs) {
        return;
      }
    }

    _lastSpeakTime = now;
    await speak(text);
  }

  Future<void> _speak(String text) async {
    await _pauseSpeechRecognition();
    await _updateLanguage();
    await _flutterTts.speak(text);
  }

  void _processQueue() {
    if (_isProcessingQueue || _messageQueue.isEmpty || isSpeaking.value) {
      return;
    }

    _isProcessingQueue = true;
    final text = _messageQueue.removeAt(0);
    _speak(text).then((_) {
      _isProcessingQueue = false;
    });
  }

  Future<void> stop() async {
    _messageQueue.clear();
    await _flutterTts.stop();
    isSpeaking.value = false;
  }

  Future<void> setLanguage(String languageCode) async {
    await StorageService.to.setSelectedLanguage(languageCode);
    await _updateLanguage();
  }

  // ═══════════════════════════════════════════════════════════════════
  // Pre-built Messages
  // ═══════════════════════════════════════════════════════════════════

  /// ✅ NEW: When user says wake word but no object
  Future<void> speakNeedFullCommand() async {
    final isArabic = StorageService.to.isArabic;
    final message = isArabic
        ? 'قل الأمر كاملاً، مثل: هاي فايندنج بادي اعثر على هاتفي'
        : 'Say the full command, like: Hey Finding Buddy find my phone';
    await speak(message, immediate: true);
  }

  Future<void> speakReached() async {
    final isArabic = StorageService.to.isArabic;
    final message = isArabic
        ? 'لقد وصلت إلى الهدف'
        : "You've reached the object";
    await speak(message, immediate: true);
  }

  Future<void> speakNotFound() async {
    final isArabic = StorageService.to.isArabic;
    final message = isArabic ? 'فشل، لم يتم العثور عليه' : 'Failed, not found';
    await speak(message, immediate: true);
  }

  Future<void> speakDarkOrBlocked() async {
    final isArabic = StorageService.to.isArabic;
    final message = isArabic
        ? 'الغرفة مظلمة جداً أو الكاميرا محجوبة'
        : 'The room is too dark or camera is blocked';
    await speak(message, immediate: true);
  }

  Future<void> speakUnsupported(String objectName) async {
    final isArabic = StorageService.to.isArabic;
    final message = isArabic
        ? 'لا أستطيع التعرف على "$objectName" حتى الآن'
        : "I can't recognize '$objectName' yet";
    await speak(message, immediate: true);
  }

  Future<void> speakScanPrompt() async {
    final isArabic = StorageService.to.isArabic;
    final message = isArabic
        ? 'غير مرئي. يرجى الدوران ببطء'
        : 'Object not in view. Please turn slowly';
    await speak(message);
  }

  Future<void> speakSearching(String objectName) async {
    final isArabic = StorageService.to.isArabic;
    final message = isArabic
        ? 'جاري البحث عن $objectName'
        : 'Searching for $objectName';
    await speak(message, immediate: true);
  }

  @override
  void onClose() {
    _flutterTts.stop();
    super.onClose();
  }
}
