import 'package:finding_buddy/translation/ar_translation.dart';
import 'package:finding_buddy/translation/en_translation.dart';
import 'package:get/get.dart';

class AppTranslations extends Translations {
  @override
  Map<String, Map<String, String>> get keys => {
    'en_US': enTranslations,
    'ar_SA': arTranslations,
  };
}
