import 'package:flutter_test/flutter_test.dart';
import 'package:domashka/worksheet_math.dart';

void main() {
  final card = [
    'Фамилия',
    'Подготовка к ПО №2 по математике',
    '1. Сравни.',
    '80 см ... 8 дм 5 см',
    '1 ц ... 10 кг',
    '9 дм 9 см ... 1 м',
    '78 л ... 87 л',
    '1 м ... 7 дм',
    '43 л ... 34 л',
    '89 см ... 1 м',
    '50 кг ... 1 ц',
    '2. Выполни действия.',
    '19 кг + 81 кг =',
    '1 ц − 48 кг =',
    '6 дм 6 см − 31 см =',
    '5 дм 7 см + 2 дм 3 см =',
    '3 дм 5 см + 4 дм 4 см =',
    '76 см − 3 дм 4 см =',
    '1 м − 3 дм =',
    '1 м − 36 см =',
    '3. Переведи в указанные единицы измерения.',
    '5 дм 3 см = ... см',
    '1 ц = ... кг',
    '20 дм = ... м',
    '100 кг = ... ц',
    '90 см = ... дм',
    '500 кг = ... ц',
    '58 см = ... дм ... см',
    '7 дм 7 см = ... см',
  ].join('\n');

  const answers = [
    '80 см < 8 дм 5 см',
    '1 ц > 10 кг',
    '9 дм 9 см < 1 м',
    '78 л < 87 л',
    '1 м > 7 дм',
    '43 л > 34 л',
    '89 см < 1 м',
    '50 кг < 1 ц',
    '100 кг', '52 кг', '35 см', '80 см',
    '79 см', '42 см', '7 дм', '64 см',
    '53 см', '100 кг', '2 м', '1 ц',
    '9 дм', '5 ц', '5 дм 8 см', '77 см',
  ];

  test('Все 24 пункта реальной карточки: точные ответы без сети', () {
    final result = WorksheetBatch.solve(card)!;
    expect(result.solved.length, 24);
    expect(result.unresolved, isEmpty);
    expect(result.complete, isTrue);
    for (var i = 0; i < answers.length; i++) {
      expect(result.solved[i].answer, answers[i],
          reason: 'Неправильный пункт ' + (i + 1).toString());
    }
  });

  test('Перевод величин проверяется независимо от значения', () {
    expect(WorksheetUnitMath.solve('12 дм 8 см = ... см')?.answer, '128 см');
    expect(WorksheetUnitMath.solve('9 ц = ... кг')?.answer, '900 кг');
    expect(WorksheetUnitMath.solve('58 см = ... дм ... см')?.answer, '5 дм 8 см');
    expect(WorksheetUnitMath.solve('20 дм = ... м')?.answer, '2 м');
  });

  test('Отклоняем смешение длины с массой', () {
    expect(WorksheetUnitMath.solve('10 кг ... 1 м'), isNull);
    expect(WorksheetUnitMath.solve('10 см + 3 кг ='), isNull);
  });

  test('Отклоняем выдуманный отрицательный остаток', () {
    expect(WorksheetUnitMath.solve('10 кг − 22 кг ='), isNull);
  });

  test('Отклоняем потерянные единицы и смешанные колонки', () {
    expect(WorksheetUnitMath.solve('80 см... 8м 5 см 1м... 7дм'), isNull);
    expect(WorksheetUnitMath.solve('19 кг + 81 кг = 1 м − 3 дм ='), isNull);
    expect(WorksheetUnitMath.solve('це Ors 43 л... 34 л'), isNull);
  });

  test('Не прячем неразобранную строку: частичный ответ помечается', () {
    final result = WorksheetBatch.solve('19 кг + 81 кг =\n19 кг 81 г 5мм')!;
    expect(result.solved.length, 1);
    expect(result.unresolved, ['19 кг 81 г 5мм']);
    expect(result.complete, isFalse);
    expect(result.notebook, contains('НУЖНО СВЕРИТЬ'));
  });

  test('Отдельный пример в сантиметрах не требует карточку', () {
    expect(WorksheetUnitMath.solve('1 м − 36 см =')?.answer, '64 см');
  });

  test('Не выдаём готовый результат из одного мусорного OCR', () {
    expect(WorksheetBatch.solve('78 1 ...87 0 50 Вы,'), isNull);
  });
}
