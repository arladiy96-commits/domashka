import 'package:flutter_test/flutter_test.dart';
import 'package:domashka/offline_card_ocr.dart';

void main() {
  test('Разделяем пронумерованные задания', () {
    final tasks = OfflineCardParser.split(
      '1. 34 + 25 = ?\n'
      '2) В коробке было 24 яблока.\n'
      'Добавили ещё 16.\n'
      'Сколько всего?',
    );
    expect(tasks.length, 2);
    expect(tasks[0].number, '1');
    expect(tasks[0].text, '34 + 25 = ?');
    expect(tasks[1].number, '2');
    expect(tasks[1].text, contains('Сколько всего?'));
  });

  test('Сохраняем полный текст без номеров', () {
    final tasks = OfflineCardParser.split('В классе 15 девочек и 16 мальчиков.\nСколько всего детей?');
    expect(tasks.length, 1);
    expect(tasks[0].number, 'карточка');
    expect(tasks[0].text, contains('15 девочек'));
  });

  test('Общий заголовок остаётся отдельным, задания не склеиваются', () {
    final tasks = OfflineCardParser.split('Вариант 1\n1. 20 + 30 = ?\n2. 50 − 15 = ?');
    expect(tasks.length, 3);
    expect(tasks[0].number, 'инструкция');
    expect(tasks[0].text, contains('Вариант 1'));
    expect(tasks[1].number, '1');
    expect(tasks[2].number, '2');
  });

  test('Определяем случайно склеенные два столбца', () {
    expect(OfflineCardOcr.looksLikeTwoColumns(
      '80 см...8дм 5 см 1м...7дм\n'
      '1 ц...10 кг 43л...34л\n'
      '19 кг+81 кг=1м-3дм='), isTrue);
    expect(OfflineCardOcr.looksLikeTwoColumns(
      'В коробке было 24 яблока.\nДобавили ещё 16.\nСколько всего?'), isFalse);
  });

  test('Строки одного задания не разбиваются', () {
    final tasks = OfflineCardParser.split('1. Вычисли:\n18 + 3 = ?\n14 − 6 = ?');
    expect(tasks.length, 1);
    expect(tasks[0].text, contains('14 − 6'));
  });

  test('Пустой снимок не рождает заданий', () {
    expect(OfflineCardParser.split(' \n \t '), isEmpty);
  });

  test('Короткие обрывки сохраняются как неразобранная карточка', () {
    final tasks = OfflineCardParser.split('1. а\n2. 24 + 3 = ?');
    expect(tasks.length, 1);
    expect(tasks[0].text, contains('1. а'));
  });
}
