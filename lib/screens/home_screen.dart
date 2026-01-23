import 'package:finding_buddy/controller/setting_controller.dart';
import 'package:finding_buddy/painters/grid_background.dart';
import 'package:finding_buddy/routes/app_routes.dart';
import 'package:finding_buddy/screens/image_detections.dart';
import 'package:finding_buddy/service/speech_service.dart';
import 'package:finding_buddy/service/storage_service.dart';
import 'package:finding_buddy/service/tts_service.dart';
import 'package:finding_buddy/theme/app_theme.dart';
import 'package:finding_buddy/widgets/animated_button.dart';
import 'package:finding_buddy/widgets/glass_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _pulseController;

  // Local UI state
  final RxBool _isListening = false.obs;

  // Navigation tracking
  bool _isNavigating = false;

  // Worker for state listening - MUST dispose
  Worker? _stateWorker;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    final con = Get.put(SettingsController());
    con.setLanguage(con.selectedLanguage.value);

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    // Initialize speech after frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeSpeech();
    });
  }

  /// Initialize speech with callbacks
  Future<void> _initializeSpeech() async {
    print('🏠 ═══════════════════════════════════════');
    print('🏠 Initializing speech for home');

    if (!StorageService.to.isVoiceEnabled) {
      print('🏠 Voice disabled in settings');
      return;
    }

    final speech = SpeechService.to;

    // 1. Acquire ownership
    await speech.acquireOwnership(SpeechOwner.home);

    // 2. Register HOME's callbacks (separate from detection)
    _registerHomeCallbacks();

    // 3. Setup state listener (dispose old one first)
    _setupStateListener();

    // 4. Start listening
    await speech.startListeningForWakeWord(SpeechOwner.home);
    _isListening.value = speech.isActivelyListening;

    print('🏠 Speech initialized, listening: ${_isListening.value}');
    print('🏠 ═══════════════════════════════════════');
  }

  /// Register callbacks specifically for HOME screen
  void _registerHomeCallbacks() {
    print('🏠 Registering home callbacks');

    SpeechService.to.registerCallbacks(
      owner: SpeechOwner.home,
      onCommandRecognized: (objectName) {
        print('🏠 Callback: Object recognized: $objectName');
        if (!_isNavigating) {
          _navigateToDetection(objectName);
        }
      },
      onMultipleObjectsDetected: (objects) {
        print('🏠 Callback: Multiple objects: $objects');
        if (!_isNavigating) {
          _showObjectSelectionDialog(objects);
        }
      },
      onError: (error) {
        print('🏠 Callback: Error: $error');
        if (error.startsWith('unsupported:')) {
          final obj = error.replaceFirst('unsupported:', '');
          TtsService.to.speakUnsupported(obj);
        }
      },
    );
  }

  /// Setup state listener (dispose previous first)
  void _setupStateListener() {
    // Dispose old worker
    _stateWorker?.dispose();
    _stateWorker = null;

    final speech = SpeechService.to;

    // Create new worker
    _stateWorker = ever(speech.state, (SpeechState state) {
      // Only update if home owns speech and not navigating
      if (!_isNavigating && speech.currentOwner.value == SpeechOwner.home) {
        _isListening.value = state == SpeechState.listening;
        print('🏠 State changed: $state, listening: ${_isListening.value}');
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _handleAppBackground();
        break;
      case AppLifecycleState.resumed:
        _handleAppForeground();
        break;
    }
  }

  void _handleAppBackground() {
    print('🏠 App going to background');

    final speech = SpeechService.to;

    if (speech.currentOwner.value == SpeechOwner.home) {
      speech.pauseForNavigation();
      _isListening.value = false;
    }
  }

  void _handleAppForeground() {
    print('🏠 App coming to foreground');

    if (!_isNavigating) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && !_isNavigating) {
          _resumeAfterBackground();
        }
      });
    }
  }

  Future<void> _resumeAfterBackground() async {
    print('🏠 Resuming after background');

    final speech = SpeechService.to;

    // Re-register callbacks (they might have been overwritten)
    _registerHomeCallbacks();

    // Resume
    await speech.resumeAfterNavigation(SpeechOwner.home);
    _isListening.value = speech.isActivelyListening;
  }

  void _showObjectSelectionDialog(List<String> objects) {
    final speech = SpeechService.to;

    speech.pauseForNavigation();
    _isListening.value = false;

    Get.dialog(
      AlertDialog(
        title: Text(
          'select_object'.tr.isEmpty ? 'Select Object' : 'select_object'.tr,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: objects
              .map(
                (obj) => ListTile(
                  title: Text(obj),
                  onTap: () {
                    Get.back();
                    _navigateToDetection(obj);
                  },
                ),
              )
              .toList(),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Get.back();
              Future.delayed(const Duration(milliseconds: 300), () {
                if (mounted) {
                  _resumeListeningAfterNavigation();
                }
              });
            },
            child: Text('cancel'.tr.isEmpty ? 'Cancel' : 'cancel'.tr),
          ),
        ],
      ),
      barrierDismissible: false,
    );
  }

  /// Toggle listening - USER CONTROLLED
  void _toggleListening() async {
    if (_isNavigating) return;

    final speech = SpeechService.to;
    await speech.toggleListening(SpeechOwner.home);
    _isListening.value = speech.isActivelyListening;

    print('🏠 Toggled, listening: ${_isListening.value}');
  }

  /// Resume after navigation
  Future<void> _resumeListeningAfterNavigation() async {
    print('🏠 ═══════════════════════════════════════');
    print('🏠 Resuming after navigation');
    _isNavigating = false;

    final speech = SpeechService.to;

    // CRITICAL: Re-register home callbacks
    _registerHomeCallbacks();

    // Re-setup state listener
    _setupStateListener();

    // Resume
    await speech.resumeAfterNavigation(SpeechOwner.home);
    _isListening.value = speech.isActivelyListening;

    print('🏠 Resumed, listening: ${_isListening.value}');
    print('🏠 ═══════════════════════════════════════');
  }

  // ═══════════════════════════════════════════════════════════════════
  // NAVIGATION METHODS
  // ═══════════════════════════════════════════════════════════════════

  void _navigateToDetection([String? objectName]) {
    if (_isNavigating) return;

    print('🏠 Navigating to detection: $objectName');
    _isNavigating = true;
    _isListening.value = false;

    // Release ownership - detection will take over
    SpeechService.to.releaseOwnership(SpeechOwner.home);

    final arguments = objectName != null ? {'target': objectName} : null;

    Get.toNamed(AppRoutes.detection, arguments: arguments)?.then((_) {
      _onReturnFromNavigation();
    });
  }

  void _navigateToImageDetection() {
    if (_isNavigating) return;

    print('🏠 Navigating to image detection');
    _isNavigating = true;
    _isListening.value = false;

    SpeechService.to.pauseForNavigation();

    Get.to(() => const ImageDetectionScreen())?.then((_) {
      _onReturnFromNavigation();
    });
  }

  void _navigateToSettings() {
    if (_isNavigating) return;

    print('🏠 Navigating to settings');
    _isNavigating = true;
    _isListening.value = false;

    SpeechService.to.pauseForNavigation();

    Get.toNamed(AppRoutes.settings)?.then((_) {
      _onReturnFromNavigation();
    });
  }

  void _navigateToTutorial() {
    if (_isNavigating) return;

    print('🏠 Navigating to tutorial');
    _isNavigating = true;
    _isListening.value = false;

    SpeechService.to.pauseForNavigation();

    Get.toNamed(AppRoutes.tutorial)?.then((_) {
      _onReturnFromNavigation();
    });
  }

  void _onReturnFromNavigation() {
    print('🏠 Returned from navigation');

    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        _resumeListeningAfterNavigation();
      }
    });
  }

  @override
  void dispose() {
    print('🏠 Disposing home screen');

    WidgetsBinding.instance.removeObserver(this);
    _pulseController.dispose();

    // Dispose worker
    _stateWorker?.dispose();
    _stateWorker = null;

    // Clear home callbacks
    SpeechService.to.clearCallbacks(SpeechOwner.home);

    // Release if we own it
    if (SpeechService.to.currentOwner.value == SpeechOwner.home) {
      SpeechService.to.releaseOwnership(SpeechOwner.home);
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundSecondary,
      body: GridBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppTheme.spacingLg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context),
                const SizedBox(height: AppTheme.spacingXl),
                _buildVoiceSection(context),
                const SizedBox(height: AppTheme.spacingXl),
                _buildImageDetectionSection(context),
                const SizedBox(height: AppTheme.spacingXl),
                _buildStatsSection(context),
                const SizedBox(height: AppTheme.spacingXl),
                _buildFeaturesSection(context),
                const SizedBox(height: AppTheme.spacingXl),
                _buildQuickActions(context),
                const SizedBox(height: AppTheme.spacingXl),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  Widget _buildImageDetectionSection(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(
                Icons.image_search_outlined,
                size: 26,
                color: AppTheme.primaryTeal,
              ),
              const SizedBox(width: AppTheme.spacingSm),
              Expanded(
                child: Text(
                  'image_detection'.tr,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primaryTeal.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'new'.tr,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppTheme.primaryTeal,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingSm),
          Text(
            'image_detection_desc'.tr,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: AppTheme.spacingLg),
          Row(
            children: [
              Expanded(
                child: AnimatedSecondaryButton(
                  text: 'choose_from_gallery'.tr,
                  icon: Icons.photo_library_outlined,
                  onPressed: _navigateToImageDetection,
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: 650.ms, duration: 600.ms).slideY(begin: 0.08);
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'hello'.tr,
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
            ).animate().fadeIn(duration: 500.ms).slideX(begin: -0.2, end: 0),
            const SizedBox(height: 4),
            Text(
              'ready_to_find'.tr,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: AppTheme.textSecondary),
            ).animate().fadeIn(delay: 200.ms, duration: 500.ms),
          ],
        ),
        GestureDetector(
          onTap: _navigateToSettings,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.cardBackground,
              borderRadius: BorderRadius.circular(16),
              boxShadow: AppTheme.cardShadow,
            ),
            child: const Icon(
              Icons.settings_outlined,
              color: AppTheme.textPrimary,
            ),
          ),
        ).animate().fadeIn(delay: 300.ms).scale(),
      ],
    );
  }

  Widget _buildVoiceSection(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(AppTheme.spacingXl),
      child: Column(
        children: [
          // Microphone Button
          Obx(() {
            final isActive = _isListening.value;
            return GestureDetector(
              onTap: _toggleListening,
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: isActive ? AppTheme.primaryGradient : null,
                      color: isActive ? null : AppTheme.lightGray,
                      boxShadow: isActive
                          ? [
                              BoxShadow(
                                color: AppTheme.primaryTeal.withOpacity(
                                  0.3 + (_pulseController.value * 0.2),
                                ),
                                blurRadius: 20 + (_pulseController.value * 20),
                                spreadRadius: _pulseController.value * 10,
                              ),
                            ]
                          : null,
                    ),
                    child: Center(
                      child: Icon(
                        Icons.mic,
                        size: 48,
                        color: isActive ? Colors.white : AppTheme.textSecondary,
                      ),
                    ),
                  );
                },
              ),
            );
          }).animate().scale(duration: 600.ms, curve: Curves.easeOutBack),

          const SizedBox(height: AppTheme.spacingLg),

          // Status Text
          Obx(() {
            final isActive = _isListening.value;
            final speech = SpeechService.to;
            final isManuallyPaused = speech.isManuallyPaused.value;

            return Column(
              children: [
                Text(
                  isActive
                      ? 'say_object_name'.tr.isEmpty
                            ? 'Say the object name (e.g., "phone", "laptop")'
                            : 'say_object_name'.tr
                      : isManuallyPaused
                      ? 'voice_paused'.tr.isEmpty
                            ? 'Voice paused - Tap to resume'
                            : 'voice_paused'.tr
                      : 'voice_inactive'.tr.isEmpty
                      ? 'Voice inactive - Tap to activate'
                      : 'voice_inactive'.tr,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: isActive
                        ? AppTheme.primaryTeal
                        : AppTheme.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (isActive) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                              ),
                            )
                            .animate(onPlay: (c) => c.repeat())
                            .fadeIn(duration: 500.ms)
                            .then()
                            .fadeOut(duration: 500.ms),
                        const SizedBox(width: 8),
                        Text(
                          'listening'.tr.isEmpty
                              ? 'Listening...'
                              : 'listening'.tr,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: Colors.green,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'examples'.tr.isEmpty ? 'Examples:' : 'examples'.tr,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '"phone" • "laptop" • "remote" • "keys"',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            );
          }),

          const SizedBox(height: AppTheme.spacingLg),

          AnimatedPrimaryButton(
            text: 'start_finding'.tr,
            icon: Icons.search,
            onPressed: () => _navigateToDetection(),
          ),

          const SizedBox(height: AppTheme.spacingMd),

          Obx(
            () => AnimatedSecondaryButton(
              text: _isListening.value
                  ? 'pause_listening'.tr.isEmpty
                        ? 'Pause Listening'
                        : 'pause_listening'.tr
                  : 'enable_voice'.tr.isEmpty
                  ? 'Enable Voice'
                  : 'enable_voice'.tr,
              icon: _isListening.value ? Icons.pause : Icons.mic_none,
              onPressed: _toggleListening,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 400.ms, duration: 600.ms).slideY(begin: 0.1);
  }

  Widget _buildStatsSection(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: StatusCard(
            title: 'detection_rate'.tr,
            value: '95%',
            icon: Icons.speed,
            color: AppTheme.primaryTeal,
          ).animate().fadeIn(delay: 500.ms).slideX(begin: -0.2),
        ),
        const SizedBox(width: AppTheme.spacingMd),
        Expanded(
          child: StatusCard(
            title: 'objects_found'.tr,
            value: '80+',
            icon: Icons.category,
            color: const Color(0xFF6366F1),
          ).animate().fadeIn(delay: 600.ms).slideX(begin: 0.2),
        ),
      ],
    );
  }

  Widget _buildFeaturesSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'features'.tr,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        ).animate().fadeIn(delay: 700.ms),
        const SizedBox(height: AppTheme.spacingMd),
        FeatureCard(
          icon: Icons.watch_later,
          title: 'clock_face_guidance'.tr,
          description: 'clock_face_desc'.tr,
        ).animate().fadeIn(delay: 800.ms).slideY(begin: 0.1),
        const SizedBox(height: AppTheme.spacingMd),
        FeatureCard(
          icon: Icons.wifi_off,
          title: 'works_offline'.tr,
          description: 'works_offline_desc'.tr,
        ).animate().fadeIn(delay: 900.ms).slideY(begin: 0.1),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'quick_actions'.tr,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        ).animate().fadeIn(delay: 1000.ms),
        const SizedBox(height: AppTheme.spacingMd),
        Row(
          children: [
            Expanded(
              child: _QuickActionCard(
                icon: Icons.help_outline,
                title: 'tutorial'.tr,
                onTap: _navigateToTutorial,
              ).animate().fadeIn(delay: 1100.ms).scale(),
            ),
            const SizedBox(width: AppTheme.spacingMd),
            Expanded(
              child: _QuickActionCard(
                icon: Icons.history,
                title: 'history'.tr,
                onTap: () {
                  Get.snackbar(
                    'Coming Soon',
                    'History feature will be available soon',
                    snackPosition: SnackPosition.BOTTOM,
                  );
                },
              ).animate().fadeIn(delay: 1200.ms).scale(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacingLg,
            vertical: AppTheme.spacingSm,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.home,
                label: 'Home',
                isActive: true,
                onTap: () {},
              ),
              _NavItem(
                icon: Icons.search,
                label: 'Find',
                isActive: false,
                onTap: () => _navigateToDetection(),
              ),
              _NavItem(
                icon: Icons.settings,
                label: 'Settings',
                isActive: false,
                onTap: _navigateToSettings,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: AppTheme.subtleGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppTheme.primaryTeal, size: 28),
          ),
          const SizedBox(height: AppTheme.spacingSm),
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isActive ? AppTheme.primaryTeal : AppTheme.mediumGray,
            size: 26,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isActive ? AppTheme.primaryTeal : AppTheme.mediumGray,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
