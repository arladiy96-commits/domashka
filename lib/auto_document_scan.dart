import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Quiet, on-device "photograph -> scan" conversion.
///
/// Searches for a single light sheet against a darker background, estimates
/// its four corners and flattens perspective. If there is not enough evidence
/// for a safe crop, returns null. In particular, no text or mathematical
/// symbol is ever reconstructed or guessed by this step.
class AutoDocumentScan {
  static img.Image? rectify(img.Image photo) {
    if (photo.width < 400 || photo.height < 400) return null;

    // Work on a small bitmap to keep page finding quick on a phone.
    final preview = img.copyResize(photo, width: 360,
        interpolation: img.Interpolation.linear);
    final w = preview.width, h = preview.height;
    if (h < 160 || h > 1100) return null;

    int luminance(int x, int y) {
      final pixel = preview.getPixel(x, y);
      return ((pixel.r + pixel.g + pixel.b) / 3).round();
    }

    double regionMean(double x0, double y0, double x1, double y1) {
      final xa = (x0 * w).floor(), xb = (x1 * w).ceil();
      final ya = (y0 * h).floor(), yb = (y1 * h).ceil();
      var sum = 0;
      var count = 0;
      for (var y = ya; y < yb; y += 3) {
        for (var x = xa; x < xb; x += 3) {
          sum += luminance(x, y);
          count++;
        }
      }
      return count == 0 ? 0 : sum / count;
    }

    final background = (
      regionMean(.02, .02, .12, .12) +
      regionMean(.88, .02, .98, .12) +
      regionMean(.02, .88, .12, .98) +
      regionMean(.88, .88, .98, .98)) / 4;

    // Pick a bright seed close to the center without assuming the exact
    // center pixel is white (it may coincide with black printed text).
    final centerX = w ~/ 2, centerY = h ~/ 2;
    var seedX = -1, seedY = -1, peak = 0;
    var seedDistance = double.infinity;
    for (var y = h ~/ 4; y < h * 3 ~/ 4; y += 2) {
      for (var x = w ~/ 4; x < w * 3 ~/ 4; x += 2) {
        final light = luminance(x, y);
        final dx = (x - centerX) / w, dy = (y - centerY) / h;
        final distance = dx * dx + dy * dy;
        if (light > peak) peak = light;
        // Consider only bright central pixels; choose closest to center.
        if (light > background + 36 &&
            (distance < seedDistance ||
             (distance == seedDistance && light > luminance(seedX, seedY)))) {
          seedDistance = distance;
          seedX = x;
          seedY = y;
        }
      }
    }
    if (seedX < 0 || peak - background < 40) return null;
    final threshold = background + (peak - background) * .53;
    if (luminance(seedX, seedY) < threshold) {
      // Center seed might be lightly colored; find bright alternative.
      seedX = -1;
      seedDistance = double.infinity;
      for (var y = h ~/ 4; y < h * 3 ~/ 4; y += 2) {
        for (var x = w ~/ 4; x < w * 3 ~/ 4; x += 2) {
          final dx = (x - centerX) / w, dy = (y - centerY) / h;
          final distance = dx * dx + dy * dy;
          if (luminance(x, y) >= threshold && distance < seedDistance) {
            seedDistance = distance;
            seedX = x;
            seedY = y;
          }
        }
      }
      if (seedX < 0) return null;
    }

    // Flood-fill the connected bright paper, treating text pixels as holes.
    final visited = Uint8List(w * h);
    final queue = Int32List(w * h);
    var head = 0, tail = 0;
    final start = seedY * w + seedX;
    queue[tail++] = start;
    visited[start] = 1;

    var minX = w, maxX = 0, minY = h, maxY = 0, pixels = 0;
    var tlScore = double.infinity, trScore = -double.infinity;
    var brScore = -double.infinity, blScore = double.infinity;
    var tl = _Point(0, 0), tr = _Point(0, 0);
    var br = _Point(0, 0), bl = _Point(0, 0);

    void visit(int x, int y) {
      if (x < 0 || x >= w || y < 0 || y >= h) return;
      final index = y * w + x;
      if (visited[index] != 0) return;
      visited[index] = 1;
      if (luminance(x, y) >= threshold) queue[tail++] = index;
    }

    while (head < tail) {
      final index = queue[head++];
      final x = index % w, y = index ~/ w;
      pixels++;
      minX = math.min(minX, x); maxX = math.max(maxX, x);
      minY = math.min(minY, y); maxY = math.max(maxY, y);
      final sum = (x + y).toDouble();
      final difference = (x - y).toDouble();
      if (sum < tlScore) { tlScore = sum; tl = _Point(x.toDouble(), y.toDouble()); }
      if (difference > trScore) { trScore = difference; tr = _Point(x.toDouble(), y.toDouble()); }
      if (sum > brScore) { brScore = sum; br = _Point(x.toDouble(), y.toDouble()); }
      if (difference < blScore) { blScore = difference; bl = _Point(x.toDouble(), y.toDouble()); }
      visit(x - 1, y);
      visit(x + 1, y);
      visit(x, y - 1);
      visit(x, y + 1);
    }

    final boxWidth = maxX - minX, boxHeight = maxY - minY;
    final coverage = boxWidth > 0 && boxHeight > 0
        ? pixels / (boxWidth * boxHeight) : 0.0;
    if (boxWidth < .19 * w || boxHeight < .22 * h ||
        boxWidth > .95 * w || boxHeight > .95 * h ||
        pixels < .06 * w * h || coverage < .50) return null;

    // Enforce a sensible, clockwise quadrilateral rather than trusting a
    // nearly degenerate or self-intersecting boundary.
    final polygon = [tl, tr, br, bl];
    final area = _polygonArea(polygon);
    if (area <= .055 * w * h ||
        tr.x <= tl.x || br.x <= bl.x ||
        bl.y <= tl.y || br.y <= tr.y) return null;

    final sx = photo.width / w, sy = photo.height / h;
    final corners = polygon.map((p) => _Point(p.x * sx, p.y * sy)).toList();

    // Slightly expand from the center to preserve border-most characters.
    final cx = corners.map((p) => p.x).reduce((a, b) => a + b) / 4;
    final cy = corners.map((p) => p.y).reduce((a, b) => a + b) / 4;
    final expanded = corners.map((p) => _Point(
      (cx + (p.x - cx) * 1.023).clamp(0, photo.width - 1),
      (cy + (p.y - cy) * 1.023).clamp(0, photo.height - 1),
    )).toList();

    final outputWidth = math.max(_distance(expanded[0], expanded[1]),
        _distance(expanded[3], expanded[2])).round();
    final outputHeight = math.max(_distance(expanded[0], expanded[3]),
        _distance(expanded[1], expanded[2])).round();
    if (outputWidth < 200 || outputHeight < 200) return null;
    // Avoid enormous 24MP documents: Tesseract works well with a ~2k scan.
    final scale = math.min(1.0, 2300 / math.max(outputWidth, outputHeight));
    final outputW = (outputWidth * scale).round();
    final outputH = (outputHeight * scale).round();

    return _warp(photo, expanded, outputW, outputH);
  }

  static double _distance(_Point a, _Point b) =>
      math.sqrt(math.pow(a.x - b.x, 2) + math.pow(a.y - b.y, 2));

  static double _polygonArea(List<_Point> vertices) {
    var doubled = 0.0;
    for (var i = 0; i < vertices.length; i++) {
      final a = vertices[i], b = vertices[(i + 1) % vertices.length];
      doubled += a.x * b.y - a.y * b.x;
    }
    return doubled / 2;
  }

  static img.Image? _warp(img.Image source, List<_Point> p, int width, int height) {
    final tl = p[0], tr = p[1], br = p[2], bl = p[3];
    // Destination (u,v) -> source homography; solve projective g/h.
    final ax = br.x - tr.x, bx = br.x - bl.x;
    final ay = br.y - tr.y, by = br.y - bl.y;
    final rx = tr.x + bl.x - tl.x - br.x;
    final ry = tr.y + bl.y - tl.y - br.y;
    final det = ax * by - bx * ay;
    if (det.abs() < .0001) return null;
    final g = (rx * by - bx * ry) / det;
    final h = (ax * ry - rx * ay) / det;
    final a = tr.x * (g + 1) - tl.x;
    final b = bl.x * (h + 1) - tl.x;
    final d = tr.y * (g + 1) - tl.y;
    final e = bl.y * (h + 1) - tl.y;

    final result = img.Image(width: width, height: height, numChannels: 3);
    for (var y = 0; y < height; y++) {
      final v = y / math.max(1, height - 1);
      for (var x = 0; x < width; x++) {
        final u = x / math.max(1, width - 1);
        final denominator = g * u + h * v + 1;
        if (denominator.abs() < .000001) return null;
        final xx = ((a * u + b * v + tl.x) / denominator)
            .clamp(0.0, (source.width - 1).toDouble());
        final yy = ((d * u + e * v + tl.y) / denominator)
            .clamp(0.0, (source.height - 1).toDouble());
        final ix = xx.floor(), iy = yy.floor();
        final nx = math.min(source.width - 1, ix + 1);
        final ny = math.min(source.height - 1, iy + 1);
        final fx = xx - ix, fy = yy - iy;
        final p00 = source.getPixel(ix, iy);
        final p10 = source.getPixel(nx, iy);
        final p01 = source.getPixel(ix, ny);
        final p11 = source.getPixel(nx, ny);
        int blend(num a00, num a10, num a01, num a11) =>
            (a00 * (1 - fx) * (1 - fy) +
              a10 * fx * (1 - fy) +
              a01 * (1 - fx) * fy +
              a11 * fx * fy).round().clamp(0, 255);
        result.setPixelRgb(x, y,
          blend(p00.r, p10.r, p01.r, p11.r),
          blend(p00.g, p10.g, p01.g, p11.g),
          blend(p00.b, p10.b, p01.b, p11.b));
      }
    }
    return result;
  }
}

class _Point {
  const _Point(this.x, this.y);
  final double x, y;
}
