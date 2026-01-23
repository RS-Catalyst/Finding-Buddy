import 'dart:io';
import 'package:finding_buddy/models/detected_object/detected_object_dm.dart';
import 'package:finding_buddy/service/storage_service.dart';
import 'package:finding_buddy/service/synonyms_service.dart';
import 'package:finding_buddy/service/tensorflow_helper.dart';
import 'package:finding_buddy/service/tensorflow_service.dart';
import 'package:finding_buddy/service/tts_service.dart';
import 'package:finding_buddy/utils/app_constants.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'dart:ui';

class ImageDetectionController extends GetxController {
  final RxBool isProcessing = false.obs;
  final RxString targetObject = ''.obs;
  final RxList<DetectedObjectDm> detections = <DetectedObjectDm>[].obs;
  final Rx<File?> selectedImage = Rx<File?>(null);
  final RxString errorMessage = ''.obs;
  final Rx<img.Image?> processedImage = Rx<img.Image?>(null);
  final Rx<Size?> imageSize = Rx<Size?>(null);

  final ImagePicker _picker = ImagePicker();

  @override
  void onInit() {
    super.onInit();
    _ensureModelInitialized();
  }

  Future<void> _ensureModelInitialized() async {
    if (!TensorflowService.yolov8.isInitialized) {
      await TensorflowService.yolov8.initialize();
    }
  }

  /// Pick image from camera
  Future<void> pickFromCamera({String? targetClass}) async {
    try {
      isProcessing.value = true;
      update();
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 85,
      );

      if (image != null) {
        isProcessing.value = true;
        update();
        selectedImage.value = File(image.path);

        _processImage(targetClass: targetClass).catchError((e) {
          errorMessage.value = 'Failed to process image: $e';
          isProcessing.value = false;
          update();
        });
      } else {
        isProcessing.value = false;
        update();
      }
    } catch (e) {
      errorMessage.value = 'Failed to capture image: $e';
      isProcessing.value = false;
      update();
    } finally {
      isProcessing.value = true;
      update();
    }
  }

  /// Pick image from gallery
  Future<void> pickFromGallery({String? targetClass}) async {
    try {
      isProcessing.value = true;
      update();
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (image != null) {
        selectedImage.value = File(image.path);

        _processImage(targetClass: targetClass).catchError((e) {
          errorMessage.value = 'Failed to process image: $e';
          isProcessing.value = false;
          update();
        });
      } else {
        isProcessing.value = false;
        update();
      }
    } catch (e) {
      errorMessage.value = 'Failed to pick image: $e';
      isProcessing.value = false;
    } finally {
      isProcessing.value = true;
      update();
    }
  }

  /// Process the selected image - using ORIGINAL TensorflowHelper (accurate!)
  Future<void> _processImage({String? targetClass}) async {
    if (selectedImage.value == null) {
      isProcessing.value = false;
      return;
    }

    detections.clear();
    targetObject.value = targetClass ?? '';

    try {
      // Load image
      final imageBytes = await selectedImage.value!.readAsBytes();
      final image = img.decodeImage(imageBytes);

      if (image == null) {
        errorMessage.value = 'Failed to decode image';
        isProcessing.value = false;
        return;
      }

      processedImage.value = image;
      imageSize.value = Size(image.width.toDouble(), image.height.toDouble());

      print('🖼️ Processing image: ${image.width}x${image.height}');

      // Run detection using ORIGINAL TensorflowHelper
      final result = TensorflowHelper.analyseImage(
        image,
        interpreter: TensorflowService.yolov8.interpreter,
        labels: TensorflowService.yolov8.labels,
        targetClass: targetClass,
        minConfidence: AppConstants.confidenceThreshold,
        sensorOrientation: 0,
        isFrontCamera: false,
      );

      print('🎯 Detection result: ${result.detectedObjects.length} objects');

      // Filter by confidence
      final filtered = result.detectedObjects
          .where((e) => e.score >= 0.20)
          .toList();

      // Remove duplicates by label (keep highest confidence)
      final Map<String, DetectedObjectDm> uniqueDetections = {};
      for (var det in filtered) {
        if (!uniqueDetections.containsKey(det.label) ||
            det.score > uniqueDetections[det.label]!.score) {
          uniqueDetections[det.label] = det;
        }
      }

      detections.value = uniqueDetections.values.toList();

      // Sort by confidence
      detections.sort((a, b) => b.score.compareTo(a.score));

      print('📦 Final detections: ${detections.length}');
      for (var det in detections) {
        print(
          '   - ${det.label}: ${(det.score * 100).toStringAsFixed(1)}% at ${det.location}',
        );
      }

      // Announce results
      await _announceResults(targetClass);
    } catch (e) {
      errorMessage.value = 'Failed to process image: $e';
      print('❌ Processing error: $e');
    } finally {
      isProcessing.value = false;
    }
  }

  /// Announce detection results via TTS
  Future<void> _announceResults(String? targetClass) async {
    final isArabic = StorageService.to.isArabic;

    if (detections.isEmpty) {
      final message = targetClass != null && targetClass.isNotEmpty
          ? (isArabic
                ? 'لم يتم العثور على $targetClass في الصورة'
                : 'No $targetClass found in the image')
          : (isArabic ? 'لم يتم العثور على أي شيء' : 'No objects found');
      await TtsService.to.speak(message);
      return;
    }

    // Build announcement message
    String message;
    if (isArabic) {
      if (detections.length == 1) {
        final det = detections.first;
        final direction = det.getDirectionString(isArabic: true);
        final distance = det.distanceString;
        message = 'تم العثور على ${det.label}. $direction، $distance';
      } else {
        message = 'تم العثور على ${detections.length} أشياء. ';
        for (int i = 0; i < detections.length && i < 3; i++) {
          final det = detections[i];
          final direction = det.getDirectionString(isArabic: true);
          message += '${det.label} $direction، ';
        }
      }
    } else {
      if (detections.length == 1) {
        final det = detections.first;
        final direction = det.getDirectionString(isArabic: false);
        final distance = det.distanceString;
        message = 'Found ${det.label}. $direction, $distance';
      } else {
        message = 'Found ${detections.length} objects. ';
        for (int i = 0; i < detections.length && i < 3; i++) {
          final det = detections[i];
          final direction = det.getDirectionString(isArabic: false);
          final separator = i == detections.length - 1 || i == 2 ? '' : ', ';
          final prefix = i == detections.length - 1 && i > 0 ? 'and ' : '';
          message += '$prefix${det.label} $direction$separator';
        }
      }
    }

    await TtsService.to.speak(message);
  }

  /// Start detection with object selection
  Future<void> startDetectionWithObject(String objectName) async {
    final modelClass = SynonymService.instance.resolveToModelClass(objectName);
    if (modelClass == null) {
      await TtsService.to.speakUnsupported(objectName);
      return;
    }

    targetObject.value = modelClass;
  }

  /// Reset state
  void reset() {
    selectedImage.value = null;
    detections.clear();
    targetObject.value = '';
    processedImage.value = null;
    imageSize.value = null;
    errorMessage.value = '';
    isProcessing.value = false;
  }

  /// Get supported objects list
  List<String> get supportedObjects => AppConstants.supportedClasses;
}
