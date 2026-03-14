import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image/image.dart' as img;

import 'image_preprocess_service_stub.dart'
    if (dart.library.io) 'image_preprocess_service_mobile.dart' as preprocess_impl;

/// 图像预处理：透视矫正 + 二值化
/// 移动端尝试 OpenCV 透视矫正 + 自适应二值化；Web 或失败时使用 image 包二值化
Future<Uint8List> preprocessForOcr(Uint8List imageBytes) async {
  if (kIsWeb) {
    return _preprocessWithImagePackage(imageBytes);
  }
  try {
    final result = await preprocess_impl.preprocessWithOpenCv(imageBytes);
    if (result != null) return result;
  } catch (_) {
    // OpenCV 不可用时回退
  }
  return _preprocessWithImagePackage(imageBytes);
}

/// 使用 image 包做二值化（Web 或 OpenCV 不可用时的兜底）
Uint8List _preprocessWithImagePackage(Uint8List imageBytes) {
  final image = img.decodeImage(imageBytes);
  if (image == null) return imageBytes;

  final gray = img.grayscale(image);
  final binary = _applyThreshold(gray, 128);
  final out = img.encodeJpg(binary);
  return Uint8List.fromList(out);
}

img.Image _applyThreshold(img.Image gray, int threshold) {
  for (var y = 0; y < gray.height; y++) {
    for (var x = 0; x < gray.width; x++) {
      final c = gray.getPixel(x, y);
      final l = img.getLuminanceRgb(
        img.getRed(c),
        img.getGreen(c),
        img.getBlue(c),
      );
      final v = l < threshold ? 0 : 255;
      gray.setPixelRgba(x, y, v, v, v, 0xff);
    }
  }
  return gray;
}

