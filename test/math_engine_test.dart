import 'package:flutter_test/flutter_test.dart';
import 'package:domashka/math_engine.dart';

void main() {
  test('Сложение', () => expect(MathEngine.solve('37 + 25')?.value, 62));
  test('Вычитание', () => expect(MathEngine.solve('64 − 28')?.value, 36));
  test('Деление', () => expect(MathEngine.solve('48 ÷ 6')?.value, 8));
  test('Уравнение', () => expect(MathEngine.solve('x + 17 = 42')?.value, 25));
  test('Не выдумываем решение сложной текстовой задачи', () =>
    expect(MathEngine.solve('В коробке было 24 яблока. Добавили ещё 16. Сколько всего?'), isNull));
  test('Не решаем произвольно одно из двух выражений', () =>
    expect(MathEngine.solve('37 + 25 и 64 − 28'), isNull));
  test('Ответ модели отличается', () {
    final math = MathEngine.solve('35 + 7')!;
    expect(MathEngine.sameValue(math, '41'), isFalse);
    expect(MathEngine.sameValue(math, '42'), isTrue);
  });
}