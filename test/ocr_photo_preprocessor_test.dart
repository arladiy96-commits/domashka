import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:domashka/ocr_photo_preprocessor.dart';

void main() {
  test('Обрезаем явно белый лист на тёмной поверхности, не теряя края', () {
    final photo = img.Image(width: 600, height: 800);
    img.fill(photo, color: img.ColorRgb8(110, 95, 85));
    img.fillRect(photo, x1: 145, y1: 120, x2: 455, y2: 690,
        color: img.ColorRgb8(242, 241, 239));
    // A few dark text-like stripes inside the page.
    for (var y = 180; y < 600; y += 20) {
      img.fillRect(photo, x1: 180, y1: y, x2: 410, y2: y + 2,
          color: img.ColorRgb8(35, 35, 35));
    }
    final cropped = OcrPhotoPreprocessor.cropPaper(photo);
    expect(cropped.width, lessThan(photo.width));
    expect(cropped.height, lessThan(photo.height));
    expect(cropped.width, greaterThan(295));
    expect(cropped.height, greaterThan(545));
  });

  test('Не кадрируем однотонный фон, когда границы бумаги сомнительны', () {
    final photo = img.Image(width: 600, height: 800);
    img.fill(photo, color: img.ColorRgb8(210, 210, 210));
    final unchanged = OcrPhotoPreprocessor.cropPaper(photo);
    expect(unchanged.width, photo.width);
    expect(unchanged.height, photo.height);
  });

  test('После выделения страницы столбцы получаются отдельно', () {
    final image = img.Image(width: 600, height: 900);
    final columns = OcrPhotoPreprocessor.splitColumns(image);
    expect(columns, hasLength(2));
    expect(columns[0].width, greaterThan(300));
    expect(columns[1].width, greaterThan(300));
    expect(columns[0].height, 900);
    expect(columns[1].height, 900);
  });

  test('Увеличиваем маленькую колонку перед русским OCR', () {
    final image = img.Image(width: 500, height: 700);
    final prepared = OcrPhotoPreprocessor.improve(image);
    expect(prepared.width, 1000);
    expect(prepared.height, 1400);
  });
}
