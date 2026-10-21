import 'package:flutter_test/flutter_test.dart';
import 'package:domashka/ocr_layout.dart';

CardOcrBox b(String text, double x, double y, double w,
    {double confidence = .98}) =>
    CardOcrBox(text, confidence, x, y, x + w, y + 18);

void main() {
  test('one column keeps the complete multiline question', () {
    final r = CardOcrLayout.parse([
      b('1. В коробке было 24 яблока.', 15, 10, 470),
      b('Добавили ещё 16.', 15, 40, 350),
      b('Сколько всего?', 15, 70, 340),
    ], 600);
    expect(r.twoColumns, false);
    expect(r.exercises.length, 1);
    expect(r.exercises.first.text, contains('Сколько всего?'));
    expect(r.exercises.first.text, contains('24 яблока'));
  });

  test('two columns are read top-to-bottom independently', () {
    final r = CardOcrLayout.parse([
      b('20 + 30 = ?', 20, 20, 130),
      b('70 - 15 = ?', 360, 20, 160),
      b('40 + 10 = ?', 20, 60, 130),
      b('90 - 20 = ?', 360, 60, 160),
      b('60 + 10 = ?', 20, 100, 130),
      b('80 - 40 = ?', 360, 100, 160),
    ], 600);
    expect(r.twoColumns, true);
    expect(r.exercises.length, 2);
    expect(r.exercises.first.text, contains('60 + 10'));
    expect(r.exercises.first.text, isNot(contains('90 - 20')));
    expect(r.exercises.last.text, contains('90 - 20'));
  });

  test('one table row is not mistaken for a two-column page', () {
    final r = CardOcrLayout.parse([
      b('Десятки', 30, 25, 110),
      b('Единицы', 360, 25, 110),
      b('Заполни таблицу', 25, 0, 390),
    ], 600);
    expect(r.twoColumns, false);
    expect(r.exercises.single.text, contains('Десятки'));
    expect(r.exercises.single.text, contains('Единицы'));
  });

  test('low confidence does not turn into fabricated confident text', () {
    final r = CardOcrLayout.parse([
      b('8? + 12 = ?', 20, 20, 220, confidence: .55)
    ], 600);
    expect(r.lowConfidence, true);
    expect(r.exercises.single.text, contains('8?'));
  });

  test('empty detector returns no artificial exercise', () {
    final r = CardOcrLayout.parse([], 600);
    expect(r.exercises, isEmpty);
    expect(r.lowConfidence, true);
  });
}
