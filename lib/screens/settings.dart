import 'package:finding_buddy/controller/setting_controller.dart';
import 'package:finding_buddy/utils/app_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:finding_buddy/theme/app_theme.dart';

class SettingsScreen extends GetView<SettingsController> {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundSecondary,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundSecondary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () => Get.back(),
        ),
        title: Text(
          'settings'.tr,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spacingLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Voice & Audio Section
            _SectionHeader(
              title: 'voice_audio'.tr,
            ).animate().fadeIn(duration: 300.ms),
            const SizedBox(height: AppTheme.spacingMd),

            _SettingsCard(
              children: [
                Obx(
                  () => _SwitchTile(
                    icon: Icons.mic,
                    title: 'voice_control'.tr,
                    subtitle: 'voice_control_desc'.tr,
                    value: controller.voiceEnabled.value,
                    onChanged: controller.setVoiceEnabled,
                  ),
                ),
                const _Divider(),
                Obx(
                  () => _SwitchTile(
                    icon: Icons.vibration,
                    title: 'haptic_feedback'.tr,
                    subtitle: 'haptic_feedback_desc'.tr,
                    value: controller.hapticFeedback.value,
                    onChanged: controller.setHapticFeedback,
                  ),
                ),
              ],
            ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1),

            const SizedBox(height: AppTheme.spacingXl),

            // Display Section
            _SectionHeader(title: 'display'.tr).animate().fadeIn(delay: 200.ms),
            const SizedBox(height: AppTheme.spacingMd),

            _SettingsCard(
              children: [
                Obx(
                  () => _SwitchTile(
                    icon: Icons.visibility,
                    title: 'camera_preview'.tr,
                    subtitle: 'camera_preview_desc'.tr,
                    value: controller.showCameraPreview.value,
                    onChanged: controller.setShowCameraPreview,
                  ),
                ),
                const _Divider(),
                Obx(
                  () => _SliderTile(
                    icon: Icons.timer,
                    title: 'guidance_frequency'.tr,
                    subtitle:
                        '${'update_interval'.tr} ${controller.guidanceFrequency.value.toStringAsFixed(1)}s',
                    value: controller.guidanceFrequency.value,
                    min: 1.0,
                    max: 5.0,
                    onChanged: controller.setGuidanceFrequency,
                  ),
                ),
              ],
            ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1),

            const SizedBox(height: AppTheme.spacingXl),

            // Language Section
            _SectionHeader(
              title: 'language'.tr,
            ).animate().fadeIn(delay: 400.ms),
            const SizedBox(height: AppTheme.spacingMd),

            _SettingsCard(
              children: [
                Obx(
                  () => _NavigationTile(
                    icon: Icons.language,
                    title: 'app_language'.tr,
                    subtitle:
                        controller.selectedLanguage.value ==
                            AppConstants.langArabic
                        ? 'العربية'
                        : 'English',
                    onTap: () => _showLanguagePicker(context),
                  ),
                ),
              ],
            ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.1),

            const SizedBox(height: AppTheme.spacingXl),

            // About Section
            _SectionHeader(title: 'about'.tr).animate().fadeIn(delay: 600.ms),
            const SizedBox(height: AppTheme.spacingMd),

            _SettingsCard(
              children: [
                _InfoTile(
                  icon: Icons.info_outline,
                  title: 'version'.tr,
                  subtitle: AppConstants.appVersion,
                ),
                const _Divider(),
                _NavigationTile(
                  icon: Icons.privacy_tip_outlined,
                  title: 'privacy_policy'.tr,
                  onTap: () => _showPrivacyPolicy(context),
                ),
                const _Divider(),
                _NavigationTile(
                  icon: Icons.description_outlined,
                  title: 'terms_of_service'.tr,
                  onTap: () => _showTermsOfService(context),
                ),
              ],
            ).animate().fadeIn(delay: 700.ms).slideY(begin: 0.1),

            const SizedBox(height: AppTheme.spacingXxl),
          ],
        ),
      ),
    );
  }

  void _showLanguagePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'select_language'.tr,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 20),
            _LanguageOption(
              title: 'English',
              subtitle: 'English',
              isSelected:
                  controller.selectedLanguage.value == AppConstants.langEnglish,
              onTap: () {
                controller.setLanguage(AppConstants.langEnglish);
                Get.back();
              },
            ),
            _LanguageOption(
              title: 'العربية',
              subtitle: 'Arabic',
              isSelected:
                  controller.selectedLanguage.value == AppConstants.langArabic,
              onTap: () {
                controller.setLanguage(AppConstants.langArabic);
                Get.back();
              },
            ),
            const SafeArea(child: SizedBox(height: 16)),
          ],
        ),
      ),
    );
  }

  void _showPrivacyPolicy(BuildContext context) {
    _showInfoSheet(
      context,
      title: 'privacy_policy'.tr,
      content: '''
Finding Buddy Privacy Policy

Your privacy is important to us. This app is designed with privacy as a core principle.

• All object detection processing happens entirely on your device
• We do not collect, store, or transmit any camera images
• Voice commands are processed locally without cloud services
• No personal data is sent to external servers
• No analytics or tracking is implemented

The app requires camera and microphone permissions solely for the object detection and voice command features. These permissions are used only when the app is actively running and are not accessed in the background.

For any questions about privacy, please contact us.
      ''',
    );
  }

  void _showTermsOfService(BuildContext context) {
    _showInfoSheet(
      context,
      title: 'terms_of_service'.tr,
      content: '''
Finding Buddy Terms of Service

By using Finding Buddy, you agree to these terms:

1. Use
   - The app is provided as-is for personal, non-commercial use
   - You must be at least 13 years old to use this app

2. Limitations
   - Object detection accuracy may vary based on lighting and camera quality
   - Distance estimates are approximations, not precise measurements
   - The app is not a substitute for professional assistance

3. Safety
   - Always be aware of your surroundings when using the app
   - Do not use while driving or in dangerous situations
   - The app is not designed for emergency or safety-critical use

4. Intellectual Property
   - All app content and technology belong to Finding Buddy
   - You may not copy, modify, or reverse engineer the app

5. Disclaimer
   - We are not liable for any damages from app use
   - Features may change with updates

By continuing to use the app, you accept these terms.
      ''',
    );
  }

  void _showInfoSheet(
    BuildContext context, {
    required String title,
    required String content,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    content,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(height: 1.6),
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Get.back(),
                      child: const Text('Close'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        color: AppTheme.textSecondary,
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(children: children),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: AppTheme.spacingMd),
      child: Divider(color: AppTheme.mediumGray, height: 1),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final Function(bool) onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primaryTeal.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppTheme.primaryTeal, size: 22),
          ),
          const SizedBox(width: AppTheme.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppTheme.primaryTeal,
          ),
        ],
      ),
    );
  }
}

class _SliderTile extends StatelessWidget {
  const _SliderTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final double value;
  final double min;
  final double max;
  final Function(double) onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryTeal.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppTheme.primaryTeal, size: 22),
              ),
              const SizedBox(width: AppTheme.spacingMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingSm),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: ((max - min) * 2).toInt(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _NavigationTile extends StatelessWidget {
  const _NavigationTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingMd),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryTeal.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppTheme.primaryTeal, size: 22),
              ),
              const SizedBox(width: AppTheme.spacingMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleSmall),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppTheme.primaryTeal),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primaryTeal.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppTheme.primaryTeal, size: 22),
          ),
          const SizedBox(width: AppTheme.spacingMd),
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleSmall),
          ),
          Text(
            subtitle,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _LanguageOption extends StatelessWidget {
  const _LanguageOption({
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.primaryTeal.withOpacity(0.1)
                : Colors.transparent,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                const Icon(Icons.check_circle, color: AppTheme.primaryTeal),
            ],
          ),
        ),
      ),
    );
  }
}
