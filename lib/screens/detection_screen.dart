import 'package:finding_buddy/controller/detection_controller.dart';
import 'package:finding_buddy/screens/bounding_box.dart';
import 'package:finding_buddy/screens/object_picker.dart';
import 'package:finding_buddy/service/guidance_service.dart';
import 'package:finding_buddy/service/storage_service.dart';
import 'package:finding_buddy/theme/app_theme.dart';
import 'package:finding_buddy/widgets/clock_face_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:camera/camera.dart';
import 'package:get/get.dart';

class DetectionScreen extends GetView<DetectionController> {
  const DetectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _DetectionScreenWrapper(child: _buildContent(context));
  }

  Widget _buildContent(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera Preview with Boxes
          Obx(
            () => controller.showCameraView.value
                ? _buildCameraView(context)
                : _buildBlindModeView(),
          ),

          // ✅ NEW: Camera Quality Overlay
          Obx(() => _buildQualityOverlay(context)),

          // Overlay UI
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(context),
                const Spacer(),
                Obx(
                  () => controller.isDetecting.value
                      ? _buildDetectionInfo(context)
                      : const SizedBox.shrink(),
                ),
                const SizedBox(height: AppTheme.spacingXl),
                _buildControlButtons(context),
                const SizedBox(height: AppTheme.spacingXl),
              ],
            ),
          ),

          // Success Overlay
          Obx(
            () => controller.isObjectReached.value
                ? _buildSuccessOverlay(context)
                : const SizedBox.shrink(),
          ),

          // Error Snackbar
          Obx(() {
            if (controller.errorMessage.value.isNotEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                Get.snackbar(
                  'error'.tr,
                  controller.errorMessage.value,
                  snackPosition: SnackPosition.TOP,
                  backgroundColor: Colors.red.withOpacity(0.8),
                  colorText: Colors.white,
                );
                controller.errorMessage.value = '';
              });
            }
            return const SizedBox.shrink();
          }),
          Obx(() {
            if (controller.isCountdownActive.value) {
              return _buildCountdownOverlay();
            }
            return const SizedBox.shrink();
          }),
        ],
      ),
    );
  }

  Widget _buildCountdownOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.7),
      child: Center(
        child: Obx(
          () => AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              '${controller.countdownValue.value}',
              key: ValueKey(controller.countdownValue.value),
              style: const TextStyle(
                fontSize: 120,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// ✅ NEW: Quality Overlay
  Widget _buildQualityOverlay(BuildContext context) {
    if (!controller.isQualityPoor.value) {
      return const SizedBox.shrink();
    }

    final quality = controller.cameraQuality.value;
    if (quality == null) {
      return const SizedBox.shrink();
    }

    return Container(
      color: Colors.black.withOpacity(0.85),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
                  quality.isDark ? Icons.wb_sunny_outlined : Icons.block,
                  size: 100,
                  color: Colors.orange,
                )
                .animate(onPlay: (c) => c.repeat())
                .fadeIn(duration: 800.ms)
                .then()
                .fadeOut(duration: 800.ms),
            const SizedBox(height: 30),
            Text(
              quality.message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                quality.isDark
                    ? 'Turn on lights or move to a brighter area'
                    : 'Check if camera lens is covered or blocked',
                style: const TextStyle(color: Colors.white70, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 30),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withOpacity(0.5)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.info_outline, color: Colors.orange, size: 20),
                  SizedBox(width: 10),
                  Text(
                    'Detection paused',
                    style: TextStyle(
                      color: Colors.orange,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildCameraView(BuildContext context) {
    return Obx(() {
      if (!controller.isCameraInitialized.value ||
          controller.cameraController == null) {
        return Container(
          color: Colors.grey[900],
          child: const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryTeal),
            ),
          ),
        );
      }

      final previewSize = controller.cameraController!.value.previewSize;
      if (previewSize == null) {
        return Container(color: Colors.grey[900]);
      }

      final screenSize = MediaQuery.of(context).size;
      final cameraSize = Size(previewSize.height, previewSize.width);

      return Stack(
        fit: StackFit.expand,
        children: [
          // Camera Preview
          ClipRect(
            child: OverflowBox(
              alignment: Alignment.center,
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: previewSize.height,
                  height: previewSize.width,
                  child: CameraPreview(controller.cameraController!),
                ),
              ),
            ),
          ),

          // Grid overlay
          CustomPaint(size: Size.infinite, painter: _CameraGridPainter()),

          // Scanning animation
          if (controller.isDetecting.value &&
              !controller.isObjectVisible.value &&
              !controller.isQualityPoor.value)
            _ScanningOverlay(),

          // ✅ Real-time bounding boxes for ALL objects
          Obx(() {
            final allDetections = GuidanceService.to.allDetections;

            if (allDetections.isEmpty ||
                !controller.isDetecting.value ||
                controller.isQualityPoor.value) {
              return const SizedBox.shrink();
            }

            return BoundingBoxOverlay(
              detections: allDetections,
              cameraSize: cameraSize,
              targetObject: controller.targetObject.value,
            );
          }),
        ],
      );
    });
  }

  Widget _buildBlindModeView() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.grey[900]!, Colors.black],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.visibility_off,
              size: 80,
              color: Colors.white.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'camera_preview_off'.tr.isEmpty
                  ? 'Camera Preview Off'
                  : 'camera_preview_off'.tr,
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Back Button
          _TopBarButton(
            icon: Icons.arrow_back,
            onTap: () {
              controller.stopDetection();
              Get.back();
            },
          ),

          // Target Display
          Obx(
            () => Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.primaryTeal.withOpacity(0.5),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.search,
                    color: AppTheme.primaryTeal,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    controller.targetObject.value.isEmpty
                        ? 'finding'.tr
                        : '${'finding'.tr} ${controller.targetObject.value}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // View Toggle
          _TopBarButton(
            icon: controller.showCameraView.value
                ? Icons.visibility_off
                : Icons.visibility,
            onTap: controller.toggleCameraView,
          ),
        ],
      ),
    );
  }

  Widget _buildDetectionInfo(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingLg),
      child: Column(
        children: [
          // Clock Face Direction
          Obx(
            () => ClockFaceWidget(
              activeHour: controller.clockPosition.value,
              size: 180,
              showDirection: true,
            ),
          ),

          const SizedBox(height: AppTheme.spacingXl),

          // Distance Info with ACCURATE display
          Obx(
            () => _DistanceCard(
              distance: controller.estimatedDistance.value,
              isVisible: controller.isObjectVisible.value,
              detection: controller.currentDetection.value,
            ),
          ),

          const SizedBox(height: AppTheme.spacingMd),

          // Guidance Message
          Obx(() {
            if (controller.guidanceMessage.value.isEmpty) {
              return const SizedBox.shrink();
            }
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                controller.guidanceMessage.value,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            );
          }),

          // ✅ Show count of all detected objects
          Obx(() {
            final allDetections = GuidanceService.to.allDetections;
            if (allDetections.length <= 1) {
              return const SizedBox.shrink();
            }

            return Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppTheme.primaryTeal.withOpacity(0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.visibility,
                    color: AppTheme.primaryTeal,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${allDetections.length} objects detected',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.2, end: 0);
  }

  Widget _buildControlButtons(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingLg),
      child: Obx(() {
        if (controller.isDetecting.value) {
          return _StopButton(onTap: controller.stopDetection);
        }
        return _StartButton(onTap: () => _showObjectPicker(context));
      }),
    );
  }

  void _showObjectPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => CompleteObjectPickerSheet(
        enableSpeech: true,
        onObjectSelected: (objectName) {
          Get.back();
          controller.startDetectionForObject(objectName);
        },
      ),
    );
  }

  Widget _buildSuccessOverlay(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.8),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(AppTheme.spacingXl),
          padding: const EdgeInsets.all(AppTheme.spacingXxl),
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryTeal.withOpacity(0.5),
                blurRadius: 40,
                spreadRadius: 10,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 80)
                  .animate()
                  .scale(duration: 600.ms, curve: Curves.elasticOut)
                  .fadeIn(),
              const SizedBox(height: AppTheme.spacingLg),
              Text(
                'object_found'.tr,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                ),
              ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.3, end: 0),
              const SizedBox(height: AppTheme.spacingSm),
              Text(
                'youve_reached'.tr,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ).animate().fadeIn(delay: 500.ms),
              const SizedBox(height: AppTheme.spacingXl),
              ElevatedButton(
                    onPressed: () {
                      controller.resetAfterFound();
                      Get.back();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppTheme.primaryTeal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 48,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      'done'.tr,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                  .animate()
                  .fadeIn(delay: 700.ms)
                  .scale(begin: const Offset(0.8, 0.8)),
            ],
          ),
        ),
      ),
    );
  }
}

// ... REST OF THE FILE (helper widgets) ...
// [Copy all helper widgets from previous detection_screen.dart]

class _DetectionScreenWrapper extends StatefulWidget {
  final Widget child;
  const _DetectionScreenWrapper({required this.child});
  @override
  State<_DetectionScreenWrapper> createState() =>
      _DetectionScreenWrapperState();
}

class _DetectionScreenWrapperState extends State<_DetectionScreenWrapper>
    with WidgetsBindingObserver {
  DetectionController? _controller;
  bool _wasDetecting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _controller = Get.find<DetectionController>();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (_controller == null) return;

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
    if (_controller == null) return;
    _wasDetecting = _controller!.isDetecting.value;
    if (_wasDetecting) {
      _controller!.stopDetection();
    }
    _controller!.cameraController?.pausePreview();
  }

  void _handleAppForeground() {
    if (_controller == null) return;
    _controller!.cameraController?.resumePreview();
    if (_wasDetecting && _controller!.targetObject.value.isNotEmpty) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && _controller != null) {
          _controller!.startDetectionForObject(_controller!.targetObject.value);
        }
      });
      _wasDetecting = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _TopBarButton extends StatelessWidget {
  const _TopBarButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
        ),
      ),
    );
  }
}

class _DistanceCard extends StatelessWidget {
  const _DistanceCard({
    required this.distance,
    required this.isVisible,
    this.detection,
  });

  final double distance;
  final bool isVisible;
  final dynamic detection;

  @override
  Widget build(BuildContext context) {
    final isArabic = StorageService.to.isArabic;
    String distanceText;

    // Use ACCURATE distance from DetectedObjectDm if available
    if (detection != null && detection.distanceMeters != null) {
      final accurateDist = detection.distanceMeters;
      if (accurateDist < 0.5) {
        distanceText = isArabic
            ? 'قريب جداً - ${accurateDist.toStringAsFixed(1)}م'
            : 'Very close - ${accurateDist.toStringAsFixed(1)}m';
      } else if (accurateDist < 1.0) {
        distanceText = isArabic
            ? 'قريب - ${accurateDist.toStringAsFixed(1)}م'
            : 'Close - ${accurateDist.toStringAsFixed(1)}m';
      } else {
        distanceText = '${accurateDist.toStringAsFixed(1)}m';
      }
    } else {
      // Fallback
      if (!isVisible) {
        distanceText = isArabic ? 'غير مرئي' : 'Not visible';
      } else if (distance < 0.5) {
        distanceText = isArabic ? 'قريب جداً' : 'Very close';
      } else if (distance < 1.0) {
        distanceText = isArabic ? 'قريب' : 'Close';
      } else {
        distanceText = '${distance.toStringAsFixed(1)}m';
      }
    }

    return Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isVisible
                  ? AppTheme.primaryTeal.withOpacity(0.3)
                  : Colors.orange.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isVisible ? Icons.straighten : Icons.search_off,
                color: isVisible ? AppTheme.primaryTeal : Colors.orange,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                '${'distance'.tr}: $distanceText',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .fadeIn(duration: 800.ms)
        .then()
        .fadeOut(duration: 800.ms);
  }
}

class _StopButton extends StatelessWidget {
  const _StopButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.red.withOpacity(0.5), width: 1.5),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.stop, color: Colors.red, size: 24),
                  const SizedBox(width: 12),
                  Text(
                    'stop'.tr,
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StartButton extends StatelessWidget {
  const _StartButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.primaryGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryTeal.withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.play_arrow, color: Colors.white, size: 28),
                  const SizedBox(width: 12),
                  Text(
                    'start_detection'.tr,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ScanningOverlay extends StatefulWidget {
  @override
  State<_ScanningOverlay> createState() => _ScanningOverlayState();
}

class _ScanningOverlayState extends State<_ScanningOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Positioned(
          top: MediaQuery.of(context).size.height * _controller.value,
          left: 0,
          right: 0,
          child: Container(
            height: 2,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  AppTheme.primaryTeal.withOpacity(0.8),
                  Colors.transparent,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryTeal.withOpacity(0.5),
                  blurRadius: 20,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CameraGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..strokeWidth = 0.5;

    for (int i = 1; i < 3; i++) {
      final x = size.width * i / 3;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    for (int i = 1; i < 3; i++) {
      final y = size.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
