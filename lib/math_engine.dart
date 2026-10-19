import 'models.dart';

class MathAnswer {
  const MathAnswer(this.expression, this.value, this.notebook,
      this.explanation, this.rule, this.practice);
  final String expression, notebook, explanation, rule;
  final int value;
  final List<PracticeTask> practice;
}

class MathEngine {
  static final _arithmetic = RegExp(r'(?<!\d)(\d{1,5})\s*([+\-−×*÷/:])\s*(\d{1,5})(?!\d)');
  static final _equation = RegExp(r'[xхXХ]\s*([+\-−])\s*(\d+)\s*=\s*(\d+)');
  static final _equation2 = RegExp(r'(\d+)\s*([+\-−])\s*[xхXХ]\s*=\s*(\d+)');

  static MathAnswer? solve(String problem) {
    final text = problem.replaceAll('–', '−');
    final eq = _equation.firstMatch(text);
    if (eq != null) {
      final n = int.parse(eq.group(2)!);
      final total = int.parse(eq.group(3)!);
      final add = eq.group(1) == '+';
      final x = add ? total - n : total + n;
      return MathAnswer('x ${add ? '+' : '−'} $n = $total', x,
        'x = $total ${add ? '−' : '+'} $n\nx = $x\nПроверка: подставляем x = $x.',
        'Находим неизвестное при помощи обратного действия.',
        add ? 'Чтобы найти слагаемое, из суммы вычти известное слагаемое.'
            : 'Чтобы найти уменьшаемое, к разности прибавь вычитаемое.', []);
    }
    final eq2 = _equation2.firstMatch(text);
    if (eq2 != null) {
      final n = int.parse(eq2.group(1)!);
      final total = int.parse(eq2.group(3)!);
      final add = eq2.group(2) == '+';
      final x = add ? total - n : n - total;
      return MathAnswer('$n ${add ? '+' : '−'} x = $total', x,
        'x = ${add ? '$total − $n' : '$n − $total'}\nx = $x\nПроверка: подставляем x = $x.',
        'Находим неизвестное при помощи обратного действия.',
        add ? 'Чтобы найти слагаемое, из суммы вычти известное.'
            : 'Чтобы найти вычитаемое, из уменьшаемого вычти разность.', []);
    }
    final found = _arithmetic.allMatches(text).toList();
    if (found.length != 1 || !RegExp(
      r'^\s*(?:Вычисли[:.]?\s*)?\d{1,5}\s*[+\-−×*÷/:]\s*\d{1,5}\s*(?:=\s*\??|\?)?\s*$',
      caseSensitive: false,
    ).hasMatch(text.trim())) return null;
    final a = int.parse(found.single.group(1)!);
    final b = int.parse(found.single.group(3)!);
    final sign = _sign(found.single.group(2)!);
    final value = calculate(a, b, sign);
    if (value == null) return null;
    final rule = switch (sign) {
      '+' => 'Сложение помогает объединять части в целое.',
      '−' => 'Вычитание помогает найти остаток или разницу.',
      '×' => 'Умножение — это сложение одинаковых групп.',
      _ => 'Деление помогает распределить предметы поровну.'
    };
    final tasks = <PracticeTask>[];
    for (var i = 1; i <= 3; i++) {
      var x = a + i * 2;
      final y = b + i;
      if (sign == '−' && x < y) x = y + i;
      if (sign == '÷') x = y * (i + 2);
      final answer = calculate(x, y, sign);
      if (answer != null) tasks.add(PracticeTask('$x $sign $y = ?', '$answer'));
    }
    return MathAnswer('$a $sign $b', value,
      '$a $sign $b = $value\nОтвет: $value.',
      'Выполняем действие $a $sign $b. Получаем $value.', rule, tasks);
  }

  static String _sign(String value) => switch (value) {
    '−' || '-' => '−', '*' || '×' => '×',
    '/' || ':' || '÷' => '÷', _ => '+'
  };

  static int? calculate(int a, int b, String sign) {
    switch (_sign(sign)) {
      case '+': return a + b;
      case '−': return a - b;
      case '×': return a * b;
      default:
        if (b == 0 || a % b != 0) return null;
        return a ~/ b;
    }
  }

  static bool sameValue(MathAnswer expected, String actual) {
    final match = RegExp(r'-?\d+').firstMatch(actual);
    return match != null && int.tryParse(match.group(0)!) == expected.value;
  }
}