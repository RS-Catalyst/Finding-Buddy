import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:finding_buddy/utils/app_constants.dart';

class StorageService extends GetxService {
  late SharedPreferences _prefs;

  static StorageService get to => Get.find<StorageService>();

  Future<StorageService> init() async {
    _prefs = await SharedPreferences.getInstance();
    return this;
  }

  // First Launch
  bool get isFirstLaunch => _prefs.getBool(AppConstants.keyFirstLaunch) ?? true;
  Future<void> setFirstLaunch(bool value) async {
    await _prefs.setBool(AppConstants.keyFirstLaunch, value);
  }

  // Onboarding Complete
  bool get isOnboardingComplete =>
      _prefs.getBool(AppConstants.keyOnboardingComplete) ?? false;
  Future<void> setOnboardingComplete(bool value) async {
    await _prefs.setBool(AppConstants.keyOnboardingComplete, value);
  }

  // Selected Language
  String get selectedLanguage =>
      _prefs.getString(AppConstants.keySelectedLanguage) ??
      AppConstants.langEnglish;
  Future<void> setSelectedLanguage(String value) async {
    await _prefs.setString(AppConstants.keySelectedLanguage, value);
  }

  bool get isArabic => selectedLanguage == AppConstants.langArabic;

  // Voice Enabled
  bool get isVoiceEnabled =>
      _prefs.getBool(AppConstants.keyVoiceEnabled) ?? true;
  Future<void> setVoiceEnabled(bool value) async {
    await _prefs.setBool(AppConstants.keyVoiceEnabled, value);
  }

  // Haptic Feedback
  bool get isHapticFeedbackEnabled =>
      _prefs.getBool(AppConstants.keyHapticFeedback) ?? true;
  Future<void> setHapticFeedbackEnabled(bool value) async {
    await _prefs.setBool(AppConstants.keyHapticFeedback, value);
  }

  // Show Camera Preview
  bool get showCameraPreview =>
      _prefs.getBool(AppConstants.keyShowCameraPreview) ?? true;
  Future<void> setShowCameraPreview(bool value) async {
    await _prefs.setBool(AppConstants.keyShowCameraPreview, value);
  }

  // Guidance Frequency (in seconds)
  double get guidanceFrequency =>
      _prefs.getDouble(AppConstants.keyGuidanceFrequency) ??
      AppConstants.guidanceUpdateInterval;
  Future<void> setGuidanceFrequency(double value) async {
    await _prefs.setDouble(AppConstants.keyGuidanceFrequency, value);
  }

  // Clear all data
  Future<void> clearAll() async {
    await _prefs.clear();
  }
}
