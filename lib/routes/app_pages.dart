import 'package:finding_buddy/binding/detection_binding.dart';
import 'package:finding_buddy/controller/setting_controller.dart';
import 'package:finding_buddy/routes/app_routes.dart';
import 'package:finding_buddy/screens/detection_screen.dart';
import 'package:finding_buddy/screens/home_screen.dart';
import 'package:finding_buddy/screens/onboarding.dart';
import 'package:finding_buddy/screens/settings.dart';
import 'package:finding_buddy/screens/splash_screen.dart';
import 'package:finding_buddy/screens/toturial_screen.dart';
import 'package:get/get.dart';

class AppPages {
  static final pages = [
    GetPage(name: AppRoutes.splash, page: () => const SplashScreen()),
    GetPage(name: AppRoutes.onboarding, page: () => const OnboardingScreen()),
    GetPage(name: AppRoutes.home, page: () => const HomeScreen()),
    GetPage(
      name: AppRoutes.detection,
      page: () => const DetectionScreen(),
      binding: DetectionBinding(),
    ),
    GetPage(
      name: AppRoutes.settings,
      page: () => const SettingsScreen(),
      binding: BindingsBuilder(() {
        Get.lazyPut(() => SettingsController());
      }),
    ),
    GetPage(name: AppRoutes.tutorial, page: () => const TutorialScreen()),
  ];
}
