import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:domashka/auto_document_scan.dart';
import 'package:domashka/ocr_photo_preprocessor.dart';

void main() {
  test('Находим и выравниваем белый прямоугольный лист на столе', () {
    final src = img.Image(width: 720, height: 960);
    img.fill(src, color: img.ColorRgb8(115, 95, 82));
    img.fillRect(src, x1: 175, y1: 145, x2: 525, y2: 820,
        color: img.ColorRgb8(246, 245, 243));
    final scan = AutoDocumentScan.rectify(src);
    expect(scan, isNotNull);
    expect(scan!.width, inInclusiveRange(320, 390));
    expect(scan.height, inInclusiveRange(630, 720));
    final center = scan.getPixel(scan.width ~/ 2, scan.height ~/ 2);
    expect(center.r, greaterThan(220));
  });

  test('Ровняем перспективу трапециевидного листа', () {
    final src = img.Image(width: 720, height: 960);
    img.fill(src, color: img.ColorRgb8(108, 85, 72));
    const corners = [
      [175.0, 170.0], [465.0, 145.0],
      [565.0, 845.0], [120.0, 820.0]
    ];
    bool inside(int x, int y) {
      var isInside = false;
      for (var i = 0, j = corners.length - 1; i < corners.length; j = i++) {
        final xi = corners[i][0], yi = corners[i][1];
        final xj = corners[j][0], yj = corners[j][1];
        if ((yi > y) != (yj > y) &&
            x < (xj - xi) * (y - yi) / (yj - yi) + xi) {
          isInside = !isInside;
        }
      }
      return isInside;
    }
    for (var y = 0; y < 960; y++) {
      for (var x = 0; x < 720; x++) {
        if (inside(x, y)) src.setPixelRgb(x, y, 248, 247, 245);
      }
    }
    final scan = AutoDocumentScan.rectify(src);
    expect(scan, isNotNull);
    expect(scan!.width, inInclusiveRange(330, 470));
    expect(scan.height, inInclusiveRange(625, 735));
    for (final pos in [0.15, 0.50, 0.85]) {
      final y = (scan.height * pos).floor();
      final rowCenter = scan.getPixel(scan.width ~/ 2, y);
      expect(rowCenter.r, greaterThan(210));
    }
  });

  test('Не выдумываем границы листа на белом столе', () {
    final src = img.Image(width: 720, height: 960);
    img.fill(src, color: img.ColorRgb8(220, 220, 218));
    final scan = AutoDocumentScan.rectify(src);
    expect(scan, isNull);
    final fallback = OcrPhotoPreprocessor.cropPaper(src);
    expect(fallback.width, 720);
    expect(fallback.height, 960);
  });

  test('Отказываемся обрезать страницу, занимающую весь кадр', () {
    final src = img.Image(width: 720, height: 960);
    img.fill(src, color: img.ColorRgb8(248, 247, 246));
    final scan = AutoDocumentScan.rectify(src);
    expect(scan, isNull);
  });
}
