import 'package:finding_buddy/controller/image_detection_controller.dart';
import 'package:finding_buddy/models/detected_object/detected_object_dm.dart';
import 'package:finding_buddy/painters/grid_background.dart';
import 'package:finding_buddy/theme/app_theme.dart';
import 'package:finding_buddy/widgets/clock_face_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';

class ImageDetectionScreen extends GetView<ImageDetectionController> {
  const ImageDetectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<ImageDetectionController>(
      init: ImageDetectionController(),
      builder: (controller) {
        return Scaffold(
          backgroundColor: Colors.white,
          body: Stack(
            children: [
              SafeArea(
                child: Column(
                  children: [
                    _buildTopBar(context),
                    Expanded(child: _buildContent(context)),
                  ],
                ),
              ),

              Obx(
                () => controller.isProcessing.value
                    ? _buildProcessingOverlay()
                    : const SizedBox.shrink(),
              ),

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
            ],
          ),
        );
      },
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _TopBarButton(
            icon: Icons.arrow_back,
            onTap: () {
              controller.reset();
              Get.back();
            },
          ),

          Obx(
            () => Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
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
                    Icons.image_search,
                    color: AppTheme.primaryTeal,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    controller.targetObject.value.isEmpty
                        ? 'image_detection'.tr
                        : '${'finding'.tr} ${controller.targetObject.value}',
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),

          Obx(
            () => controller.selectedImage.value != null
                ? _TopBarButton(icon: Icons.refresh, onTap: controller.reset)
                : const SizedBox(width: 48),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return GridBackground(
      child: Obx(() {
        if (controller.selectedImage.value == null) {
          return _buildStartView(context);
        }

        return _buildResultsView(context);
      }),
    );
  }

  Widget _buildStartView(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingXl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
                  Icons.image_search,
                  size: 100,
                  color: AppTheme.primaryTeal.withOpacity(0.5),
                )
                .animate()
                .fadeIn(duration: 600.ms)
                .scale(curve: Curves.elasticOut),
            const SizedBox(height: AppTheme.spacingXl),
            Text(
              'detect_from_image'.tr,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2, end: 0),
            const SizedBox(height: AppTheme.spacingMd),
            Text(
              'detect_image_subtitle'.tr,
              style: TextStyle(
                color: Colors.black.withOpacity(0.6),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ).animate().fadeIn(delay: 400.ms),
            const SizedBox(height: AppTheme.spacingXxl),
            _buildActionButtons(
              context,
            ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.3, end: 0),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        _ActionButton(
          label: 'detect_all_objects'.tr,
          icon: Icons.grid_view,
          gradient: AppTheme.primaryGradient,
          onTap: () => _showImageSourceDialog(context, targetClass: null),
        ),
        const SizedBox(height: AppTheme.spacingMd),
        _ActionButton(
          label: 'detect_specific_object'.tr,
          icon: Icons.center_focus_strong,
          gradient: LinearGradient(
            colors: [Colors.purple[600]!, Colors.purple[400]!],
          ),
          onTap: () => _showObjectPicker(context),
        ),
      ],
    );
  }

  void _showImageSourceDialog(BuildContext context, {String? targetClass}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _ImageSourceSheet(
        onCameraSelected: () {
          Get.back();
          controller.pickFromCamera(targetClass: targetClass);
        },
        onGallerySelected: () {
          Get.back();
          controller.pickFromGallery(targetClass: targetClass);
        },
      ),
    );
  }

  void _showObjectPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _ObjectPickerSheet(
        onObjectSelected: (object) {
          Get.back();
          controller.startDetectionWithObject(object);
          _showImageSourceDialog(context, targetClass: object);
        },
      ),
    );
  }

  Widget _buildResultsView(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Image Preview WITH BOUNDING BOXES
          Obx(() => _buildImageWithBoxes(context)),
          const SizedBox(height: AppTheme.spacingXl),

          // Detection Results
          Obx(() => _buildDetectionsList(context)),
          const SizedBox(height: AppTheme.spacingXl),
        ],
      ),
    );
  }

  /// Image with bounding boxes overlay - FIXED
  Widget _buildImageWithBoxes(BuildContext context) {
    final imageFile = controller.selectedImage.value!;
    final detections = controller.detections;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacingLg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryTeal.withOpacity(0.3),
          width: 2,
        ),
        color: Colors.black12,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.file(
          imageFile,
          fit: BoxFit.contain,
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (frame == null) return child;

            // Image loaded - now overlay boxes
            return Stack(
              children: [
                child,

                // Bounding boxes overlay
                if (detections.isNotEmpty)
                  Positioned.fill(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        // IMPORTANT: Get actual display size
                        return CustomPaint(
                          size: Size(
                            constraints.maxWidth,
                            constraints.maxHeight,
                          ),
                          painter: _BoundingBoxPainter(
                            detections: detections,
                            displaySize: Size(
                              constraints.maxWidth,
                              constraints.maxHeight,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.9, 0.9));
  }

  Widget _buildDetectionsList(BuildContext context) {
    if (controller.detections.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppTheme.spacingXl),
        child: Column(
          children: [
            Icon(
              Icons.search_off,
              size: 60,
              color: Colors.orange.withOpacity(0.5),
            ),
            const SizedBox(height: AppTheme.spacingMd),
            Text(
              'no_objects_detected'.tr,
              style: TextStyle(
                color: Colors.black.withOpacity(0.7),
                fontSize: 16,
              ),
            ),
          ],
        ),
      ).animate().fadeIn();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingLg),
          child: Row(
            children: [
              const Icon(
                Icons.check_circle,
                color: AppTheme.primaryTeal,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                '${'detected'.tr} ${controller.detections.length} ${'objects'.tr}',
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.spacingLg),

        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingLg),
          itemCount: controller.detections.length,
          itemBuilder: (context, index) {
            final detection = controller.detections[index];

            return _DetectionCard(detection: detection, index: index)
                .animate()
                .fadeIn(delay: (100 * index).ms)
                .slideX(begin: 0.2, end: 0);
          },
        ),
      ],
    );
  }

  Widget _buildProcessingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.8),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'processing'.tr,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// CUSTOM PAINTER FOR BOUNDING BOXES - FIXED
// ============================================================================

class _BoundingBoxPainter extends CustomPainter {
  final List<DetectedObjectDm> detections;
  final Size displaySize;

  _BoundingBoxPainter({required this.detections, required this.displaySize});

  @override
  void paint(Canvas canvas, Size size) {
    print('=== PAINTER DEBUG ===');
    print('Display size: ${size.width}x${size.height}');
    print('Number of detections: ${detections.length}');

    for (int i = 0; i < detections.length; i++) {
      final detection = detections[i];
      final imageSize = detection.imageSize;
      final location = detection.location;

      print('\n--- Detection $i: ${detection.label} ---');
      print('Image size: ${imageSize.width}x${imageSize.height}');
      print(
        'Original box: ${location.left}, ${location.top}, ${location.right}, ${location.bottom}',
      );

      // Calculate scale factors
      final scaleX = size.width / imageSize.width;
      final scaleY = size.height / imageSize.height;

      print('Scale factors: scaleX=$scaleX, scaleY=$scaleY');

      // Scale bounding box to display size
      final left = location.left * scaleX;
      final top = location.top * scaleY;
      final right = location.right * scaleX;
      final bottom = location.bottom * scaleY;

      print('Scaled box: $left, $top, $right, $bottom');

      final rect = Rect.fromLTRB(left, top, right, bottom);

      // Draw bounding box
      final boxPaint = Paint()
        ..color = _getColorForIndex(i)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.0; // Thicker for visibility

      canvas.drawRect(rect, boxPaint);

      // Draw label background
      final labelBgPaint = Paint()
        ..color = _getColorForIndex(i)
        ..style = PaintingStyle.fill;

      final labelText =
          '${detection.label} ${(detection.score * 100).toStringAsFixed(0)}%';
      final textSpan = TextSpan(
        text: labelText,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      );

      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );

      textPainter.layout();

      final labelRect = Rect.fromLTWH(
        left,
        top - textPainter.height - 8,
        textPainter.width + 12,
        textPainter.height + 8,
      );

      canvas.drawRect(labelRect, labelBgPaint);

      // Draw label text
      textPainter.paint(canvas, Offset(left + 6, top - textPainter.height - 4));

      print('Box drawn successfully');
    }
  }

  Color _getColorForIndex(int index) {
    final colors = [
      Colors.green,
      Colors.blue,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
      Colors.pink,
      Colors.cyan,
    ];
    return colors[index % colors.length];
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ============================================================================
// HELPER WIDGETS - UNCHANGED
// ============================================================================

class _TopBarButton extends StatelessWidget {
  const _TopBarButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withOpacity(0.2), width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Icon(icon, color: Colors.black, size: 24),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.gradient,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Gradient gradient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: Container(
        decoration: BoxDecoration(
          gradient: gradient,
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
                  Icon(icon, color: Colors.white, size: 28),
                  const SizedBox(width: 12),
                  Text(
                    label,
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

class _ImageSourceSheet extends StatelessWidget {
  const _ImageSourceSheet({
    required this.onCameraSelected,
    required this.onGallerySelected,
  });

  final VoidCallback onCameraSelected;
  final VoidCallback onGallerySelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
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
              'select_image_source'.tr,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _SourceOption(
                  icon: Icons.camera_alt,
                  label: 'camera'.tr,
                  onTap: onCameraSelected,
                ),
                _SourceOption(
                  icon: Icons.photo_library,
                  label: 'gallery'.tr,
                  onTap: onGallerySelected,
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _SourceOption extends StatelessWidget {
  const _SourceOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 140,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.primaryTeal.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Icon(icon, color: AppTheme.primaryTeal, size: 48),
              const SizedBox(height: 12),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ObjectPickerSheet extends StatelessWidget {
  const _ObjectPickerSheet({required this.onObjectSelected});

  final Function(String) onObjectSelected;

  @override
  Widget build(BuildContext context) {
    final commonObjects = [
      {'name': 'cell phone', 'icon': Icons.phone_android, 'label': 'Phone'},
      {'name': 'remote', 'icon': Icons.settings_remote, 'label': 'Remote'},
      {'name': 'bottle', 'icon': Icons.local_drink, 'label': 'Bottle'},
      {'name': 'cup', 'icon': Icons.coffee, 'label': 'Cup'},
      {'name': 'laptop', 'icon': Icons.laptop, 'label': 'Laptop'},
      {'name': 'backpack', 'icon': Icons.backpack, 'label': 'Backpack'},
      {'name': 'book', 'icon': Icons.book, 'label': 'Book'},
      {'name': 'keyboard', 'icon': Icons.keyboard, 'label': 'Keyboard'},
    ];

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
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
              'what_to_find'.tr,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 20),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                childAspectRatio: 0.9,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: commonObjects.length,
              itemBuilder: (context, index) {
                final obj = commonObjects[index];
                return _ObjectTile(
                  icon: obj['icon'] as IconData,
                  label: obj['label'] as String,
                  onTap: () => onObjectSelected(obj['name'] as String),
                );
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _ObjectTile extends StatelessWidget {
  const _ObjectTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.primaryTeal.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: AppTheme.primaryTeal, size: 28),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetectionCard extends StatelessWidget {
  const _DetectionCard({required this.detection, required this.index});

  final DetectedObjectDm detection;
  final int index;

  @override
  Widget build(BuildContext context) {
    // Debug print
    print('\n=== CARD DEBUG for ${detection.label} ===');
    print(
      'Image size: ${detection.imageSize.width}x${detection.imageSize.height}',
    );
    print('Center: ${detection.center.dx}, ${detection.center.dy}');
    print('Clock position: ${detection.clockPosition}');
    print('Distance: ${detection.distanceMeters}m');
    print('Horizontal position: ${detection.horizontalPosition}');

    final clockPos = detection.clockPosition;
    final distance = detection.distanceString;
    final direction = detection.getDirectionString(isArabic: false);

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingMd),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primaryTeal, Colors.purple[400]!],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppTheme.spacingMd),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    detection.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${'confidence'.tr}: ${(detection.score * 100).toStringAsFixed(1)}%',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    direction,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    distance,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            Column(
              children: [
                ClockFaceWidget(
                  activeHour: clockPos,
                  size: 40,
                  showDirection: false,
                ),
                const SizedBox(height: 4),
                Text(
                  '$clockPos ${"oclock".tr}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
