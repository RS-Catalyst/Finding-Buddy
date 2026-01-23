import 'package:finding_buddy/controller/app_controller.dart';
import 'package:finding_buddy/service/speech_service.dart';
import 'package:finding_buddy/service/storage_service.dart';
import 'package:finding_buddy/service/tts_service.dart';
import 'package:finding_buddy/utils/app_constants.dart';
import 'package:get/get.dart';

class SettingsController extends GetxController {
  final RxBool voiceEnabled = true.obs;
  final RxBool hapticFeedback = true.obs;
  final RxBool showCameraPreview = true.obs;
  final RxDouble guidanceFrequency = 2.0.obs;
  final RxString selectedLanguage = AppConstants.langEnglish.obs;

  static SettingsController get to => Get.find<SettingsController>();

  @override
  void onInit() {
    super.onInit();
    _loadSettings();
  }

  void _loadSettings() {
    final storage = StorageService.to;
    voiceEnabled.value = storage.isVoiceEnabled;
    hapticFeedback.value = storage.isHapticFeedbackEnabled;
    showCameraPreview.value = storage.showCameraPreview;
    guidanceFrequency.value = storage.guidanceFrequency;
    selectedLanguage.value = storage.selectedLanguage;
  }

  Future<void> setVoiceEnabled(bool value) async {
    voiceEnabled.value = value;
    await StorageService.to.setVoiceEnabled(value);

    if (!value) {
      // Stop listening when disabled
      await SpeechService.to.manualPause();
    }
  }

  Future<void> setHapticFeedback(bool value) async {
    hapticFeedback.value = value;
    await StorageService.to.setHapticFeedbackEnabled(value);
  }

  Future<void> setShowCameraPreview(bool value) async {
    showCameraPreview.value = value;
    await StorageService.to.setShowCameraPreview(value);
  }

  Future<void> setGuidanceFrequency(double value) async {
    guidanceFrequency.value = value;
    await StorageService.to.setGuidanceFrequency(value);
    TtsService.to.setMinInterval(value);
  }

  Future<void> setLanguage(String languageCode) async {
    if (selectedLanguage.value == languageCode) return;
    selectedLanguage.value = languageCode;
    await AppController.to.changeLanguage(languageCode);
  }

  bool get isArabic => selectedLanguage.value == AppConstants.langArabic;
}
