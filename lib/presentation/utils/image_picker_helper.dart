import 'package:flutter/services.dart';
import 'image_picker_stub.dart'
    if (dart.library.html) 'image_picker_web.dart' as platform_picker;

class ImagePickerHelper {
  /// Test hook to simulate file selection in automated tests.
  static Future<String?> Function()? customPicker;

  /// Test hook to simulate clipboard reads in automated tests.
  static Future<String?> Function()? customClipboardReader;

  /// Prompts the user to pick an image file.
  /// On Web, opens the native file dialog and reads as base64 data URL.
  /// On VM/mobile/desktop fallback, returns null so caller can prompt for clipboard or text.
  static Future<String?> pickImage() async {
    if (customPicker != null) {
      return await customPicker!();
    }
    return await platform_picker.pickImageAsBase64();
  }

  /// Attempts to read an image or base64 data URL from the system clipboard.
  static Future<String?> readFromClipboard() async {
    if (customClipboardReader != null) {
      return await customClipboardReader!();
    }
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain)
          .timeout(const Duration(milliseconds: 150));
      final text = data?.text?.trim();
      if (text == null || text.isEmpty) return null;

      // Check if it's already a data URI or base64 string
      if (text.startsWith('data:image/') || (text.length > 50 && !text.contains(' '))) {
        return text;
      }
    } catch (_) {
      // In test or restricted environments, gracefully fallback to null
    }
    return null;
  }

  /// Compresses an image (data URL or base64) to JPEG with max 1280px width and quality 0.82.
  static Future<String> compressImage(
    String dataUrl, {
    int maxWidth = 1280,
    double quality = 0.82,
  }) async {
    return await platform_picker.compressAndConvertToJpeg(
      dataUrl,
      maxWidth: maxWidth,
      quality: quality,
    );
  }
}

