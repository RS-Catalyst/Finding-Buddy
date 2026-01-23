import 'dart:ui';

import 'package:finding_buddy/service/guidance_service.dart';
import 'package:finding_buddy/service/speech_service.dart';
import 'package:finding_buddy/service/storage_service.dart';
import 'package:finding_buddy/service/synonyms_service.dart';
import 'package:finding_buddy/service/tensorflow_service.dart';
import 'package:finding_buddy/service/tts_service.dart';
import 'package:get/get.dart';

import 'package:finding_buddy/utils/app_constants.dart';

class AppController extends GetxController {
  final RxBool isInitialized = false.obs;
  final RxBool isLoading = true.obs;
  final RxString initError = ''.obs;
  final RxString currentLanguage = AppConstants.langEnglish.obs;

  static AppController get to => Get.find<AppController>();

  @override
  void onInit() {
    super.onInit();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      isLoading.value = true;
      initError.value = '';

      // Initialize services in order
      await Get.putAsync(() => StorageService().init());

      // Load language setting
      currentLanguage.value = StorageService.to.selectedLanguage;

      // Initialize TTS
      await Get.putAsync(() => TtsService().init());

      // ✅ Set TTS language based on saved preference
      await TtsService.to.setLanguage(currentLanguage.value);

      // Initialize Speech Recognition
      await Get.putAsync(() => SpeechService().init());

      // Initialize TensorFlow model
      await TensorflowService.yolov8.initialize();

      // Initialize Synonym Service
      await SynonymService.instance.initialize();

      // Initialize Guidance Service
      Get.put(GuidanceService());

      // ✅ Update GetX locale based on saved language
      final locale = currentLanguage.value == AppConstants.langArabic
          ? const Locale('ar', 'SA')
          : const Locale('en', 'US');
      Get.updateLocale(locale);

      isInitialized.value = true;
    } catch (e) {
      initError.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  /// Check if this is first launch
  bool get isFirstLaunch => StorageService.to.isFirstLaunch;

  /// Check if onboarding is complete
  bool get isOnboardingComplete => StorageService.to.isOnboardingComplete;

  /// Complete onboarding
  Future<void> completeOnboarding() async {
    await StorageService.to.setOnboardingComplete(true);
    await StorageService.to.setFirstLaunch(false);
  }

  /// Change language
  Future<void> changeLanguage(String languageCode) async {
    currentLanguage.value = languageCode;
    await StorageService.to.setSelectedLanguage(languageCode);
    await TtsService.to.setLanguage(languageCode);

    // Update GetX locale
    final locale = languageCode == AppConstants.langArabic
        ? const Locale('ar', 'SA')
        : const Locale('en', 'US');
    Get.updateLocale(locale);
  }

  /// Get current locale
  Locale get currentLocale {
    return currentLanguage.value == AppConstants.langArabic
        ? const Locale('ar', 'SA')
        : const Locale('en', 'US');
  }

  /// Check if Arabic
  bool get isArabic => currentLanguage.value == AppConstants.langArabic;
}
