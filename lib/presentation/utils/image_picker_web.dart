// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:html' as html;

/// Compresses and resizes an image (data URL / base64) to JPEG with max 1280px width and quality between 80-85%.
Future<String> compressAndConvertToJpeg(
  String dataUrl, {
  int maxWidth = 1280,
  double quality = 0.82,
}) async {
  final completer = Completer<String>();
  final img = html.ImageElement();

  img.onLoad.listen((_) {
    try {
      int width = img.naturalWidth;
      if (width <= 0 && img.width != null) width = img.width!;
      int height = img.naturalHeight;
      if (height <= 0 && img.height != null) height = img.height!;

      if (width <= 0 || height <= 0) {
        completer.complete(dataUrl);
        return;
      }

      if (width > maxWidth) {
        height = (height * (maxWidth / width)).round();
        width = maxWidth;
      }

      final canvas = html.CanvasElement(width: width, height: height);
      final ctx = canvas.context2D;
      // Paint opaque background in case source has transparency
      ctx.fillStyle = '#FFFFFF';
      ctx.fillRect(0, 0, width, height);
      ctx.drawImageScaled(img, 0, 0, width, height);

      final jpegData = canvas.toDataUrl('image/jpeg', quality);
      completer.complete(jpegData);
    } catch (_) {
      completer.complete(dataUrl);
    }
  });

  img.onError.listen((_) {
    completer.complete(dataUrl);
  });

  img.src = dataUrl;
  return completer.future;
}

/// Web implementation using HTML FileUploadInputElement and FileReader with client-side compression.
Future<String?> pickImageAsBase64() async {
  final completer = Completer<String?>();
  final uploadInput = html.FileUploadInputElement()
    ..accept = 'image/*,.heic,.heif,.png,.jpg,.jpeg,.webp';
  uploadInput.click();

  uploadInput.onChange.listen((e) {
    final files = uploadInput.files;
    if (files != null && files.isNotEmpty) {
      final file = files[0];
      final reader = html.FileReader();
      reader.onLoadEnd.listen((e) async {
        final result = reader.result;
        if (result is String) {
          final compressed = await compressAndConvertToJpeg(result);
          completer.complete(compressed);
        } else {
          completer.complete(null);
        }
      });
      reader.onError.listen((e) {
        completer.complete(null);
      });
      reader.readAsDataUrl(file);
    } else {
      completer.complete(null);
    }
  });

  return completer.future;
}
