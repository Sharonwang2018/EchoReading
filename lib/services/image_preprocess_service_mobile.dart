import 'dart:typed_data';

import 'package:opencv_dart/opencv_dart.dart' as cv;

/// 移动端 OpenCV 预处理：透视矫正 + 自适应二值化
/// 透视矫正需检测文档轮廓，失败时仅做二值化
Future<Uint8List?> preprocessWithOpenCv(Uint8List imageBytes) async {
  try {
    final src = cv.imdecode(imageBytes, cv.IMREAD_COLOR);
    if (src.isEmpty) return null;

    final gray = cv.cvtColor(src, cv.COLOR_BGR2GRAY);
    cv.Mat? warped = _tryPerspectiveCorrect(gray);
    final toProcess = warped ?? gray;

    final binary = cv.adaptiveThreshold(
      toProcess,
      255,
      cv.ADAPTIVE_THRESH_GAUSSIAN_C,
      cv.THRESH_BINARY,
      11,
      2,
    );

    final (ok, outBytes) = cv.imencode('.jpg', binary);
    src.dispose();
    gray.dispose();
    if (warped != null) warped.dispose();
    binary.dispose();

    return ok ? outBytes : null;
  } catch (_) {
    return null;
  }
}

/// 尝试透视矫正：检测最大四边形轮廓
cv.Mat? _tryPerspectiveCorrect(cv.Mat gray) {
  try {
    final blurred = cv.gaussianBlur(gray, (5, 5), 0);
    final edges = cv.canny(blurred, 50, 150);
    final (contours, _) = cv.findContours(
      edges,
      cv.RETR_EXTERNAL,
      cv.CHAIN_APPROX_SIMPLE,
    );

    cv.Mat? largestQuad;
    double maxArea = 0;

    for (var i = 0; i < contours.length; i++) {
      final cnt = contours[i];
      final area = cv.contourArea(cnt);
      if (area < 1000) continue;

      final epsilon = 0.02 * cv.arcLength(cnt, true);
      final approx = cv.approxPolyDP(cnt, epsilon, true);
      if (approx.length != 4) continue;

      final pts = _orderPoints(approx);
      if (pts == null) continue;

      const dstW = 800.0;
      const dstH = 1100.0;
      final dstPts = cv.VecPoint.fromList([
        cv.Point(0, 0),
        cv.Point(dstW.toInt(), 0),
        cv.Point(dstW.toInt(), dstH.toInt()),
        cv.Point(0, dstH.toInt()),
      ]);
      final srcPts = cv.VecPoint.fromList(
        pts.map((p) => cv.Point(p[0].toInt(), p[1].toInt())).toList(),
      );
      final M = cv.getPerspectiveTransform(srcPts, dstPts);
      final warped = cv.warpPerspective(
        gray,
        M,
        (dstW.toInt(), dstH.toInt()),
      );
      if (area > maxArea) {
        if (largestQuad != null) largestQuad.dispose();
        largestQuad = warped;
        maxArea = area;
      } else {
        warped.dispose();
      }
    }

    blurred.dispose();
    edges.dispose();
    return largestQuad;
  } catch (_) {
    return null;
  }
}

List<List<double>>? _orderPoints(cv.VecPoint approx) {
  try {
    final pts = <List<double>>[];
    for (var i = 0; i < 4; i++) {
      final p = approx[i];
      pts.add([p.x.toDouble(), p.y.toDouble()]);
    }
    pts.sort((a, b) => (a[1] + a[0]).compareTo(b[1] + b[0]));
    final tl = pts[0];
    final tr = pts[1];
    final br = pts[2][0] > pts[3][0] ? pts[2] : pts[3];
    final bl = pts[2][0] > pts[3][0] ? pts[3] : pts[2];
    return [tl, tr, br, bl];
  } catch (_) {
    return null;
  }
}
