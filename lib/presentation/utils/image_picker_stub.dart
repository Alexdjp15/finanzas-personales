/// Stub implementation for non-web environments (tests, VM, desktop).
Future<String?> pickImageAsBase64() async {
  return null;
}

Future<String> compressAndConvertToJpeg(
  String dataUrl, {
  int maxWidth = 1280,
  double quality = 0.82,
}) async {
  return dataUrl;
}

