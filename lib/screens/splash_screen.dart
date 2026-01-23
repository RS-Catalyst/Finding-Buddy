import 'package:finding_buddy/controller/app_controller.dart';
import 'package:finding_buddy/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:finding_buddy/painters/grid_background.dart';
import 'package:finding_buddy/theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _handleNavigation();
  }

  Future<void> _handleNavigation() async {
    // Wait for animation and initialization
    await Future.delayed(const Duration(milliseconds: 2500));

    if (!mounted) return;

    final appController = AppController.to;

    // Wait for initialization to complete
    while (appController.isLoading.value) {
      await Future.delayed(const Duration(milliseconds: 100));
    }

    if (appController.initError.value.isNotEmpty) {
      // Show error and retry
      Get.snackbar(
        'Error',
        appController.initError.value,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    // Navigate based on onboarding status
    if (appController.isOnboardingComplete) {
      Get.offAllNamed(AppRoutes.home);
    } else {
      Get.offAllNamed(AppRoutes.onboarding);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundSecondary,
      body: GridBackground(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(35),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryTeal.withOpacity(0.4),
                          blurRadius: 40,
                          offset: const Offset(0, 20),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.visibility,
                        size: 70,
                        color: Colors.white,
                      ),
                    ),
                  )
                  .animate()
                  .scale(duration: 600.ms, curve: Curves.easeOutBack)
                  .fadeIn(duration: 400.ms),

              const SizedBox(height: 40),

              // App Name
              Text(
                    'finding_buddy'.tr.isEmpty
                        ? 'Finding Buddy'
                        : 'app_name'.tr,
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  )
                  .animate()
                  .fadeIn(delay: 300.ms, duration: 600.ms)
                  .slideY(begin: 0.3, end: 0),

              const SizedBox(height: 12),

              // Tagline
              Text(
                    'app_tagline'.tr.isEmpty
                        ? 'AI-Powered Object Finding'
                        : 'app_tagline'.tr,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppTheme.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  )
                  .animate()
                  .fadeIn(delay: 500.ms, duration: 600.ms)
                  .slideY(begin: 0.3, end: 0),

              const SizedBox(height: 60),

              // Loading Indicator
              SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppTheme.primaryTeal.withOpacity(0.6),
                      ),
                    ),
                  )
                  .animate(onPlay: (controller) => controller.repeat())
                  .fadeIn(delay: 700.ms, duration: 400.ms),
            ],
          ),
        ),
      ),
    );
  }
}
