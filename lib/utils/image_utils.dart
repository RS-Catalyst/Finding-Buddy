import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;

class ImageUtils {
  ImageUtils._();

  /// Convert CameraImage to Image package format
  static img.Image? convertCameraImageToImage(CameraImage cameraImage) {
    try {
      return switch (cameraImage.format.group) {
        ImageFormatGroup.yuv420 => _convertYUV420ToImage(cameraImage),
        ImageFormatGroup.bgra8888 => _convertBGRA8888ToImage(cameraImage),
        ImageFormatGroup.jpeg => _convertJPEGToImage(cameraImage),
        ImageFormatGroup.nv21 => _convertNV21ToImage(cameraImage),
        ImageFormatGroup.unknown => null,
      };
    } catch (e) {
      return null;
    }
  }

  /// Convert JPEG format
  static img.Image? _convertJPEGToImage(CameraImage cameraImage) {
    final bytes = cameraImage.planes[0].bytes;
    return img.decodeImage(bytes);
  }

  /// Convert BGRA8888 format (iOS)
  static img.Image _convertBGRA8888ToImage(CameraImage cameraImage) {
    final plane = cameraImage.planes[0];
    return img.Image.fromBytes(
      width: cameraImage.width,
      height: cameraImage.height,
      bytes: plane.bytes.buffer,
      order: img.ChannelOrder.bgra,
    );
  }

  /// Convert YUV420 format (Android)
  static img.Image _convertYUV420ToImage(CameraImage cameraImage) {
    final width = cameraImage.width;
    final height = cameraImage.height;

    final yPlane = cameraImage.planes[0];
    final uPlane = cameraImage.planes[1];
    final vPlane = cameraImage.planes[2];

    final yBuffer = yPlane.bytes;
    final uBuffer = uPlane.bytes;
    final vBuffer = vPlane.bytes;

    final int yRowStride = yPlane.bytesPerRow;
    final int yPixelStride = yPlane.bytesPerPixel ?? 1;
    final int uvRowStride = uPlane.bytesPerRow;
    final int uvPixelStride = uPlane.bytesPerPixel ?? 1;

    final image = img.Image(width: width, height: height);

    for (int h = 0; h < height; h++) {
      final int uvh = h ~/ 2;

      for (int w = 0; w < width; w++) {
        final int uvw = w ~/ 2;

        final yIndex = (h * yRowStride) + (w * yPixelStride);
        final uvIndex = (uvh * uvRowStride) + (uvw * uvPixelStride);

        final y = yBuffer[yIndex];
        final u = uBuffer[uvIndex];
        final v = vBuffer[uvIndex];

        // YUV to RGB conversion
        final int r = (y + 1.402 * (v - 128)).round().clamp(0, 255);
        final int g = (y - 0.344136 * (u - 128) - 0.714136 * (v - 128)).round().clamp(
          0,
          255,
        );
        final int b = (y + 1.772 * (u - 128)).round().clamp(0, 255);

        image.setPixelRgb(w, h, r, g, b);
      }
    }

    return image;
  }

  /// Convert NV21 format
  static img.Image _convertNV21ToImage(CameraImage cameraImage) {
    final width = cameraImage.width;
    final height = cameraImage.height;

    final yPlane = cameraImage.planes[0].bytes;
    final vuPlane = cameraImage.planes[1].bytes;

    final image = img.Image(width: width, height: height);

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final yIndex = y * width + x;
        final uvIndex = (y ~/ 2) * width + (x ~/ 2) * 2;

        final yValue = yPlane[yIndex];
        final vValue = vuPlane[uvIndex];
        final uValue = vuPlane[uvIndex + 1];

        final int r = (yValue + 1.402 * (vValue - 128)).round().clamp(0, 255);
        final int g = (yValue - 0.344136 * (uValue - 128) - 0.714136 * (vValue - 128))
            .round()
            .clamp(0, 255);
        final int b = (yValue + 1.772 * (uValue - 128)).round().clamp(0, 255);

        image.setPixelRgb(x, y, r, g, b);
      }
    }

    return image;
  }

  /// Rotate image for proper orientation
  static img.Image rotateImage(img.Image image, int rotation) {
    switch (rotation) {
      case 90:
        return img.copyRotate(image, angle: 90);
      case 180:
        return img.copyRotate(image, angle: 180);
      case 270:
        return img.copyRotate(image, angle: 270);
      default:
        return image;
    }
  }

  /// Flip image horizontally (for front camera)
  static img.Image flipHorizontal(img.Image image) {
    return img.flipHorizontal(image);
  }

  /// Resize image to target size
  static img.Image resizeImage(img.Image image, int targetSize) {
    return img.copyResize(image, width: targetSize, height: targetSize);
  }

  /// Encode image to JPEG bytes
  static Uint8List encodeToJpeg(img.Image image, {int quality = 85}) {
    return Uint8List.fromList(img.encodeJpg(image, quality: quality));
  }

  /// Decode image from bytes
  static img.Image? decodeFromBytes(Uint8List bytes) {
    return img.decodeImage(bytes);
  }
}
