import 'package:flutter_test/flutter_test.dart';
import 'package:domashka/math_engine.dart';

void main() {
  test('Базовые примеры и уравнения', () {
    expect(MathEngine.solve('37 + 25')?.value, 62);
    expect(MathEngine.solve('64 − 28')?.value, 36);
    expect(MathEngine.solve('48 ÷ 6')?.value, 8);
    expect(MathEngine.solve('x + 17 = 42')?.value, 25);
  });

  test('Карточка: остаток', () {
    final result = MathEngine.solve(
        'В коробке было 34 карандаша. Из неё взяли 12 карандашей. Сколько осталось?');
    expect(result?.value, 22);
    expect(result?.notebook, contains('34 − 12 = 22'));
    expect(result?.practice.length, 3);
  });

  test('Карточка: отдала карандаши', () {
    expect(MathEngine.solve(
        'У Маши было 15 карандашей. Она отдала 6 карандашей. Сколько осталось?')?.value, 9);
  });

  test('Карточка: добавили предметы', () {
    final result = MathEngine.solve(
        'В коробке было 24 яблока. Добавили ещё 16. Сколько всего?');
    expect(result?.value, 40);
    expect(result?.notebook, contains('24 + 16 = 40'));
  });

  test('Карточка: две группы', () {
    expect(MathEngine.solve(
        'В классе 15 девочек и 16 мальчиков. Сколько всего детей?')?.value, 31);
  });

  test('Карточка: вышли, потом вошли', () {
    final result = MathEngine.solve(
        'В автобусе было 18 пассажиров. На остановке вышли 7, а вошли 5. Сколько пассажиров стало?');
    expect(result?.value, 16);
    expect(result?.notebook, contains('18 − 7 = 11'));
    expect(result?.notebook, contains('11 + 5 = 16'));
  });

  test('Карточка: две группы и прочитанные книги', () {
    final result = MathEngine.solve(
        'У Айжан 14 книг со сказками и 7 энциклопедий. '
        'Из них 8 она прочитала. Сколько книг осталось прочитать?');
    expect(result?.value, 13);
    expect(result?.notebook, contains('14 + 7 = 21'));
    expect(result?.notebook, contains('21 − 8 = 13'));
  });

  test('Карточка: сравнение количеств', () {
    expect(MathEngine.solve(
        'На участке 52 липы и 43 берёзы. На сколько меньше берёз, чем лип?')?.value, 9);
  });

  test('Неверное направление сравнения не принимается', () {
    expect(MathEngine.solve(
        'На участке 52 липы и 43 берёзы. На сколько меньше лип, чем берёз?'), isNull);
  });

  test('Не решаем при нехватке данных', () {
    expect(MathEngine.solve(
        'В одну кастрюлю помещается 3 бидона, а в другую 6 банок. Какая вместительнее?'), isNull);
  });

  test('Не решаем отрицательный остаток', () {
    expect(MathEngine.solve(
        'В коробке было 5 карандашей. Из неё взяли 12 карандашей. Сколько осталось?'), isNull);
  });

  test('Не решаем несколько выражений произвольно', () {
    expect(MathEngine.solve('37 + 25 и 64 − 28'), isNull);
  });

  test('Не принимает лишние числа в условии', () {
    expect(MathEngine.solve(
        'В коробке было 24 яблока. Добавили ещё 16. Сколько всего? 7 + 4'), isNull);
  });

  test('Сверка значения', () {
    final math = MathEngine.solve('35 + 7')!;
    expect(MathEngine.sameValue(math, '41'), isFalse);
    expect(MathEngine.sameValue(math, '42'), isTrue);
  });
}
