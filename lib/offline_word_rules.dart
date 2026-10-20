import 'models.dart';

/// Strict, deterministic templates for second-grade word problems.
/// A template is used only if every number and the question match.
/// No AI, network request, or guessing is involved.
class OfflineWordResult {
  const OfflineWordResult({
    required this.ruleId,
    required this.expression,
    required this.value,
    required this.notebook,
    required this.explanation,
    required this.rule,
    required this.practice,
  });

  final String ruleId;
  final String expression;
  final int value;
  final String notebook;
  final String explanation;
  final String rule;
  final List<PracticeTask> practice;
}

class OfflineWordRules {
  static final _twoChanges = RegExp(
    r'^.*?было\s+(\d{1,4})\s+[^.!?]*[.]\s*[^.!?]*(?:вышли|ушли)\s+(\d{1,4})\s*,?\s*(?:а|и)\s+(?:вошли|пришли)\s+(\d{1,4})[^.!?]*[.]\s*сколько[^.!?]*стало[^.!?]*[?]?$',
  );
  static final _readBooks = RegExp(
    r'^.*?(\d{1,4})\s+[^.!?]*?\s+и\s+(\d{1,4})\s+[^.!?]*[.]\s*из них\s+(\d{1,4})\s+[^.!?]*(?:прочитала|прочитал|прочитали)[.]\s*сколько[^.!?]*осталось\s+прочитать[^.!?]*[?]?$',
  );
  static final _decrease = RegExp(
    r'^.*?(?:было|имелось)\s+(\d{1,4})\s+[^.!?]*[.]\s*[^.!?]*(?:отдала|отдал|отдали|взяли|забрали|потратили|израсходовали|ушли|вышли)\s+(\d{1,4})\s*[^.!?]*[.]\s*сколько[^.!?]*(?:осталось|остались)[^.!?]*[?]?$',
  );
  static final _increase = RegExp(
    r'^.*?(?:было|имелось)\s+(\d{1,4})\s+[^.!?]*[.]\s*[^.!?]*(?:добавили|принесли|прибавили|купили|пришли|вошли)\s+(?:еще\s+)?(\d{1,4})\s*[^.!?]*[.]\s*сколько[^.!?]*(?:всего|стало)[^.!?]*[?]?$',
  );
  static final _compare = RegExp(
    r'^.*?(\d{1,4})\s+([а-я]+)\s+и\s+(\d{1,4})\s+([а-я]+)[.]\s*на\s+сколько\s+(меньше|больше)\s+([а-я]+),?\s+чем\s+([а-я]+)[?]?$',
  );
  static final _total = RegExp(
    r'^.*?(\d{1,4})\s+[^.!?]*?\s+и\s+(\d{1,4})\s+[^.!?]*[.]\s*сколько\s+всего[^.!?]*[?]?$',
  );

  static OfflineWordResult? solve(String raw) {
    final text = raw.trim().toLowerCase().replaceAll('ё', 'е')
        .replaceAll(RegExp(r'[«»“”]'), '')
        .replaceAll(RegExp(r'\s+'), ' ');
    // A match containing extra numbers (including a task number) is unsafe.
    final allNumbers = RegExp(r'\d+').allMatches(text).toList();
    if (allNumbers.isEmpty || allNumbers.length > 3 ||
        RegExp(r'(^|[\s(])-+\d').hasMatch(text)) return null;

    final two = _twoChanges.firstMatch(text);
    if (two != null && allNumbers.length == 3) {
      final a = int.parse(two[1]!);
      final b = int.parse(two[2]!);
      final c = int.parse(two[3]!);
      if (b > a || a - b + c > 1000) return null;
      final left = a - b;
      final result = left + c;
      return OfflineWordResult(
        ruleId: 'change_twice',
        expression: '(' + a.toString() + ' − ' + b.toString() + ') + ' + c.toString(),
        value: result,
        notebook: 'Было — ' + a.toString() + '.\n'
            'Вышли — ' + b.toString() + '. Вошли — ' + c.toString() + '.\n'
            '1) ' + a.toString() + ' − ' + b.toString() + ' = ' + left.toString() + ' — осталось после выхода.\n'
            '2) ' + left.toString() + ' + ' + c.toString() + ' = ' + result.toString() + ' — стало.\n'
            'Ответ: ' + result.toString() + '.',
        explanation: 'Сначала вычитаем тех, кто вышел. Затем прибавляем тех, кто вошёл. '
            'Проверка: ' + result.toString() + ' − ' + c.toString() +
            ' + ' + b.toString() + ' = ' + a.toString() + '.',
        rule: 'Когда сначала уходят, а потом приходят, выполни действия по порядку.',
        practice: _twoStepPractice(a, b, c),
      );
    }

    final read = _readBooks.firstMatch(text);
    if (read != null && allNumbers.length == 3) {
      final a = int.parse(read[1]!);
      final b = int.parse(read[2]!);
      final readCount = int.parse(read[3]!);
      final total = a + b;
      if (total > 1000 || readCount > total) return null;
      final left = total - readCount;
      return OfflineWordResult(
        ruleId: 'two_groups_then_remove',
        expression: '(' + a.toString() + ' + ' + b.toString() + ') − ' + readCount.toString(),
        value: left,
        notebook: '1) ' + a.toString() + ' + ' + b.toString() + ' = ' + total.toString() + ' — всего.\n'
            '2) ' + total.toString() + ' − ' + readCount.toString() + ' = ' + left.toString() + ' — осталось.\n'
            'Ответ: ' + left.toString() + '.',
        explanation: 'Находим общее количество, затем вычитаем уже прочитанное. '
            'Проверка: ' + left.toString() + ' + ' + readCount.toString() + ' = ' + total.toString() + '.',
        rule: 'Чтобы найти остаток от двух групп, сначала сложи группы.',
        practice: _twoGroupPractice(a, b, readCount),
      );
    }

    if (allNumbers.length != 2) return null;
    final decrease = _decrease.firstMatch(text);
    if (decrease != null) {
      final a = int.parse(decrease[1]!);
      final b = int.parse(decrease[2]!);
      if (b > a) return null;
      return _single('remainder', a, b, false,
          'Было', 'Забрали', 'Осталось',
          'Чтобы узнать, сколько осталось, из того, что было, вычти то, что забрали.');
    }

    final increase = _increase.firstMatch(text);
    if (increase != null) {
      final a = int.parse(increase[1]!);
      final b = int.parse(increase[2]!);
      if (a + b > 1000) return null;
      return _single('increase', a, b, true,
          'Было', 'Добавили', 'Стало',
          'Чтобы узнать, сколько стало после добавления, сложи количества.');
    }

    final compare = _compare.firstMatch(text);
    if (compare != null) {
      final a = int.parse(compare[1]!);
      final b = int.parse(compare[3]!);
      final nounA = compare[2]!;
      final nounB = compare[4]!;
      final direction = compare[5]!;
      final target = compare[6]!;
      final other = compare[7]!;
      final asksA = _sameNoun(target, nounA) && _sameNoun(other, nounB);
      final asksB = _sameNoun(target, nounB) && _sameNoun(other, nounA);
      if (asksA == asksB) return null;
      final targetValue = asksA ? a : b;
      final otherValue = asksA ? b : a;
      if ((direction == 'меньше' && targetValue >= otherValue) ||
          (direction == 'больше' && targetValue <= otherValue)) return null;
      final bigger = a > b ? a : b;
      final smaller = a > b ? b : a;
      return _single('difference', bigger, smaller, false,
          'Больше', 'Меньше', 'Разница',
          'Чтобы узнать, на сколько одно количество больше или меньше другого, вычти меньшее из большего.');
    }

    final total = _total.firstMatch(text);
    if (total != null && !RegExp(r'на\s+\d+\s+(?:больше|меньше)').hasMatch(text)) {
      final a = int.parse(total[1]!);
      final b = int.parse(total[2]!);
      if (a + b > 1000) return null;
      return _single('total', a, b, true,
          'Первая группа', 'Вторая группа', 'Всего',
          'Чтобы узнать, сколько всего предметов в двух группах, сложи их количества.');
    }
    return null;
  }

  static bool _sameNoun(String a, String b) {
    // Very conservative lexical check. Uncertain inflections are unsupported.
    final x = a.length >= 3 ? a.substring(0, 3) : a;
    final y = b.length >= 3 ? b.substring(0, 3) : b;
    return x.length == 3 && x == y;
  }

  static OfflineWordResult _single(String id, int a, int b, bool plus,
      String first, String second, String outcome, String rule) {
    final result = plus ? a + b : a - b;
    final sign = plus ? ' + ' : ' − ';
    return OfflineWordResult(
      ruleId: id,
      expression: a.toString() + sign + b.toString(),
      value: result,
      notebook: first + ' — ' + a.toString() + '.\n'
          + second + ' — ' + b.toString() + '.\n'
          + outcome + ' — ?\n'
          + a.toString() + sign + b.toString() + ' = ' + result.toString() + '\n'
          'Ответ: ' + result.toString() + '.',
      explanation: 'Выбираем действие по смыслу вопроса: ' +
          a.toString() + sign + b.toString() + ' = ' + result.toString() + '. '
          'Проверка: ' + (plus
              ? result.toString() + ' − ' + b.toString() + ' = ' + a.toString()
              : result.toString() + ' + ' + b.toString() + ' = ' + a.toString()) + '.',
      rule: rule,
      practice: _simplePractice(a, b, plus),
    );
  }

  static List<PracticeTask> _simplePractice(int a, int b, bool plus) {
    final tasks = <PracticeTask>[];
    for (var i = 1; i <= 3; i++) {
      var x = a + i * 3;
      final y = b + i;
      if (!plus && x < y) x = y + i;
      final value = plus ? x + y : x - y;
      if (value > 1000) continue;
      tasks.add(PracticeTask(
          x.toString() + (plus ? ' + ' : ' − ') + y.toString() + ' = ?',
          value.toString()));
    }
    return tasks;
  }

  static List<PracticeTask> _twoStepPractice(int a, int b, int c) {
    final tasks = <PracticeTask>[];
    for (var i = 1; i <= 3; i++) {
      final x = a + i * 3;
      final y = b + i;
      final z = c + i;
      final value = x - y + z;
      if (x < y || value > 1000) continue;
      tasks.add(PracticeTask(
          '(' + x.toString() + ' − ' + y.toString() + ') + ' + z.toString() + ' = ?',
          value.toString()));
    }
    return tasks;
  }

  static List<PracticeTask> _twoGroupPractice(int a, int b, int used) {
    final tasks = <PracticeTask>[];
    for (var i = 1; i <= 3; i++) {
      final x = a + i;
      final y = b + i;
      final z = used + i;
      final value = x + y - z;
      if (value < 0 || x + y > 1000) continue;
      tasks.add(PracticeTask(
          '(' + x.toString() + ' + ' + y.toString() + ') − ' + z.toString() + ' = ?',
          value.toString()));
    }
    return tasks;
  }
}
