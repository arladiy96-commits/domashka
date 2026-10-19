import 'package:flutter_test/flutter_test.dart';
import 'package:domashka/models.dart';
import 'package:domashka/offline_catalog.dart';

void main() {
  test('offline book survives local app state serialization', () {
    final book = BookRecord(
      id: 'os_math2_2022_ch1',
      title: 'Математика. 2 класс. Часть 1',
      path: '/local/books/os_math2_2022_ch1/catalog.sqlite',
      pageCount: 144,
      offlineDirectory: '/local/books/os_math2_2022_ch1',
    );
    final restored = BookRecord.fromJson(book.toJson());
    expect(restored.isOffline, isTrue);
    expect(restored.pageImagePath(4), '/local/books/os_math2_2022_ch1/pages/004.jpg');
    expect(restored.pageCount, 144);
    expect(restored.pdfPage(67), 67);
  });

  test('existing PDF books remain PDF after state load', () {
    final restored = BookRecord.fromJson({
      'id': 'old',
      'title': 'PDF',
      'path': '/local/book.pdf',
      'pageCount': 12,
      'texts': <String, String>{},
    });
    expect(restored.isOffline, isFalse);
  });

  test('offline exercise maps normalized highlight coordinates', () {
    final task = OfflineExercise.fromRow({
      'number': '2', 'text_ocr': 'Задание',
      'crop_x0': 0.045, 'crop_y0': 0.2522,
      'crop_x1': 0.948, 'crop_y1': 0.6696,
    });
    expect(task.number, '2');
    expect(task.ocrText, 'Задание');
    expect(task.right, greaterThan(task.left));
    expect(task.bottom, greaterThan(task.top));
  });

  test('structured exercise preserves full table cells in solving prompt', () {
    final exercise = OfflineExercise.fromRow({
      'number': '8',
      'text_ocr': '8. Дополни до 9',
      'crop_x0': 0.1,
      'crop_y0': 0.1,
      'crop_x1': 0.9,
      'crop_y1': 0.8,
      'structure_json': '''
{
  "review_status": "first_pass_reviewed",
  "statement": "8. Дополни до 9. Уменьши на 3.",
  "source_crop_image": "crops/test.jpg",
  "blocks": [
    {"type":"table","title":"Дополни до 9","columns":["7","6","5","4","3"],"rows":[]},
    {"type":"table","title":"Уменьши на 3","columns":["9","13","5","17","4"],"rows":[]}
  ]
}''',
    });
    expect(exercise.firstPassReviewed, isTrue);
    expect(exercise.sourceCropImage, 'crops/test.jpg');
    expect(exercise.blocks.length, 2);
    expect(exercise.structuredSolveText, contains('7 | 6 | 5 | 4 | 3'));
    expect(exercise.structuredSolveText, contains('9 | 13 | 5 | 17 | 4'));
  });

  test('unreviewed OCR is never passed as verified solving prompt', () {
    final exercise = OfflineExercise.fromRow({
      'number':'8', 'text_ocr':'возможно неверные числа 7 9',
      'structure_json': '{"review_status":"ocr_unverified","statement":"","blocks":[]}',
    });
    expect(exercise.firstPassReviewed, isFalse);
    expect(exercise.structuredSolveText, isEmpty);
  });
}
