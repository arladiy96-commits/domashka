import 'dart:math' as math;
import 'package:image/image.dart' as img;

/// Fast, conservative preprocessing for photographs of printed worksheets.
/// This never rewrites recognized digits or mathematical signs.
///
/// A clearly brighter centered sheet may be trimmed. When contrast between
/// paper and background is weak, the original image is preserved.
class OcrPhotoPreprocessor {
  static img.Image normalize(img.Image source) => img.bakeOrientation(source);

  static img.Image cropPaper(img.Image photo) {
    if (photo.width < 400 || photo.height < 400) return photo;
    final scan = photo.width > 420
        ? img.copyResize(photo, width: 420, interpolation: img.Interpolation.linear)
        : photo;
    final w = scan.width;
    final h = scan.height;

    double brightness(int x, int y) {
      final pixel = scan.getPixel(x, y);
      return (pixel.r + pixel.g + pixel.b).toDouble() / 3.0;
    }

    double mean(double x0, double y0, double x1, double y1) {
      var sum = 0.0;
      var count = 0;
      final ax = (x0 * w).round().clamp(0, w - 1);
      final bx = (x1 * w).round().clamp(ax + 1, w);
      final ay = (y0 * h).round().clamp(0, h - 1);
      final by = (y1 * h).round().clamp(ay + 1, h);
      for (var y = ay; y < by; y += 4) {
        for (var x = ax; x < bx; x += 4) {
          sum += brightness(x, y);
          count++;
        }
      }
      return count == 0 ? 0 : sum / count;
    }

    final outer = (mean(.03, .03, .13, .13) +
        mean(.87, .03, .97, .13) +
        mean(.03, .87, .13, .97) +
        mean(.87, .87, .97, .97)) / 4;
    final inner = mean(.42, .42, .58, .58);
    // Do not auto-crop under weak illumination or a white tabletop.
    if (inner - outer < 26) return photo;
    final threshold = outer + (inner - outer) * .48;

    bool paperColumn(int x) {
      var hit = 0, seen = 0;
      for (var y = h ~/ 3; y < h * 2 ~/ 3; y += 3) {
        if (brightness(x, y) > threshold) hit++;
        seen++;
      }
      return seen > 0 && hit / seen >= .65;
    }

    bool paperRow(int y) {
      var hit = 0, seen = 0;
      for (var x = w ~/ 3; x < w * 2 ~/ 3; x += 3) {
        if (brightness(x, y) > threshold) hit++;
        seen++;
      }
      return seen > 0 && hit / seen >= .65;
    }

    int findEdge(int center, int limit, int step, bool Function(int) contains) {
      var misses = 0;
      var lastGood = center;
      for (var p = center; (step < 0 ? p >= limit : p <= limit); p += step) {
        if (contains(p)) {
          lastGood = p;
          misses = 0;
        } else {
          misses++;
          if (misses >= 4) break;
        }
      }
      return lastGood;
    }

    final left = findEdge(w ~/ 2, 0, -1, paperColumn);
    final right = findEdge(w ~/ 2, w - 1, 1, paperColumn);
    final top = findEdge(h ~/ 2, 0, -1, paperRow);
    final bottom = findEdge(h ~/ 2, h - 1, 1, paperRow);
    final fractionWidth = (right - left) / w;
    final fractionHeight = (bottom - top) / h;
    if (fractionWidth < .22 || fractionWidth > .94 ||
        fractionHeight < .25 || fractionHeight > .94) return photo;

    // Add safety margins to avoid trimming edge-most exercise characters.
    final ax = (math.max(0, left / w - .025) * photo.width).floor();
    final bx = (math.min(1, right / w + .025) * photo.width).ceil();
    final ay = (math.max(0, top / h - .025) * photo.height).floor();
    final by = (math.min(1, bottom / h + .025) * photo.height).ceil();
    if (bx - ax < 200 || by - ay < 200) return photo;
    return img.copyCrop(photo, x: ax, y: ay, width: bx - ax, height: by - ay);
  }

  /// Page preprocessing without irreversible thresholding of small glyphs.
  static img.Image improve(img.Image image) {
    final desiredWidth = image.width < 1050
        ? math.min(1600, image.width * 2) : image.width;
    final resized = desiredWidth > image.width
        ? img.copyResize(image, width: desiredWidth,
            interpolation: img.Interpolation.cubic)
        : image;
    // Grayscale removes colored wood texture; moderate contrast keeps
    // faint strokes (e.g., 1, ц, = and decimal dots) recognizable.
    return img.adjustColor(img.grayscale(resized),
        contrast: 1.35, brightness: 1.03);
  }

  static img.Image decodePage(List<int> bytes) {
    final raw = img.decodeImage(bytes);
    if (raw == null) throw StateError('Не удалось открыть снимок карточки.');
    return cropPaper(normalize(raw));
  }

  static List<img.Image> splitColumns(img.Image image) {
    final middle = image.width ~/ 2;
    if (middle < 120 || image.height < 180) {
      throw StateError('Фотография слишком мала для раздельного чтения.');
    }
    final margin = (image.width * .015).round();
    return [
      img.copyCrop(image, x: 0, y: 0,
          width: middle + margin, height: image.height),
      img.copyCrop(image, x: middle - margin, y: 0,
          width: image.width - middle + margin, height: image.height),
    ];
  }
}
