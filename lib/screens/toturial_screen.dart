// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:finding_buddy/theme/app_theme.dart';

class TutorialScreen extends StatelessWidget {
  const TutorialScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final steps = [
      _TutorialStep(
        number: 1,
        icon: Icons.mic,
        title: 'tutorial_step_1_title'.tr,
        description: 'tutorial_step_1_desc'.tr,
        color: AppTheme.primaryTeal,
      ),
      _TutorialStep(
        number: 2,
        icon: Icons.record_voice_over,
        title: 'tutorial_step_2_title'.tr,
        description: 'tutorial_step_2_desc'.tr,
        color: const Color(0xFF6366F1),
      ),
      _TutorialStep(
        number: 3,
        icon: Icons.navigation,
        title: 'tutorial_step_3_title'.tr,
        description: 'tutorial_step_3_desc'.tr,
        color: const Color(0xFFF59E0B),
      ),
      _TutorialStep(
        number: 4,
        icon: Icons.check_circle,
        title: 'tutorial_step_4_title'.tr,
        description: 'tutorial_step_4_desc'.tr,
        color: const Color(0xFF10B981),
      ),
    ];

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
          'tutorial'.tr,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppTheme.spacingLg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                        'how_to_use'.tr,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      )
                      .animate()
                      .fadeIn(duration: 400.ms)
                      .slideY(begin: -0.2, end: 0),
                  const SizedBox(height: AppTheme.spacingXl),
                  ...steps.asMap().entries.map((entry) {
                    final index = entry.key;
                    final step = entry.value;
                    return _TutorialStepCard(
                          step: step,
                          isLast: index == steps.length - 1,
                        )
                        .animate()
                        .fadeIn(
                          delay: Duration(milliseconds: 200 + (index * 150)),
                          duration: 400.ms,
                        )
                        .slideX(begin: 0.1, end: 0);
                  }),
                  const SizedBox(height: AppTheme.spacingXl),

                  // Tips Section
                  _TipsSection()
                      .animate()
                      .fadeIn(delay: 800.ms, duration: 400.ms)
                      .slideY(begin: 0.1, end: 0),
                ],
              ),
            ),
          ),

          // Done Button
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacingLg),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () => Get.back(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryTeal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'got_it'.tr,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TutorialStep {
  final int number;
  final IconData icon;
  final String title;
  final String description;
  final Color color;

  const _TutorialStep({
    required this.number,
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });
}

class _TutorialStepCard extends StatelessWidget {
  const _TutorialStepCard({required this.step, required this.isLast});

  final _TutorialStep step;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Timeline
        Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: step.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: step.color.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: Center(
                child: Icon(step.icon, color: step.color, size: 28),
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 60,
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      step.color.withOpacity(0.5),
                      step.color.withOpacity(0.1),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: AppTheme.spacingMd),

        // Content
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : AppTheme.spacingLg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: step.color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Step ${step.number}',
                        style: TextStyle(
                          color: step.color,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  step.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  step.description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TipsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final tips = [
      'Speak clearly when giving voice commands',
      'Hold your phone steadily for better detection',
      'Ensure good lighting for accurate results',
      'Turn slowly when the object is not in view',
    ];

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: AppTheme.primaryTeal.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primaryTeal.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.lightbulb_outline,
                color: AppTheme.primaryTeal,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'Pro Tips',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryTeal,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingMd),
          ...tips.map(
            (tip) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppTheme.primaryTeal,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      tip,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
