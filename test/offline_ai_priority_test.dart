import 'package:flutter_test/flutter_test.dart';
import 'package:domashka/ai_service.dart';
import 'package:domashka/store.dart';

void main() {
  test('Локальный ответ не использует API даже при сохранённых ключах', () async {
    final store = AppStore();
    store.groqKey = 'invalid-test-token';
    store.geminiKey = 'invalid-test-token';
    final result = await AiService(store).solve(
      'В коробке было 24 яблока. Добавили ещё 16. Сколько всего?',
      source: 'Тест',
    );
    expect(result.answer, '40');
    expect(result.verified, isTrue);
    expect(result.source, contains('автономный'));
    expect(result.notebook, contains('24 + 16 = 40'));
  });
  test('Офлайн-карточка без подходящего правила не отправляется в облако', () async {
    final store = AppStore();
    store.groqKey = 'invalid-test-token';
    store.geminiKey = 'invalid-test-token';
    await expectLater(
      AiService(store).solve(
        'На рисунке изображены три неизвестные фигуры. Найди их площадь.',
        source: 'Карточка',
        offlineOnly: true,
      ),
      throwsA(isA<StateError>()),
    );
  });

}
