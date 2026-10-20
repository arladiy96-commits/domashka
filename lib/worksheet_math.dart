/// Strict elementary-school measurements and unit arithmetic, without AI.
/// Supports only unambiguous, complete expressions; corrupted OCR is rejected.
class WorksheetExample {
  const WorksheetExample(this.question, this.answer, this.working, this.rule);
  final String question, answer, working, rule;
}

class WorksheetBatch {
  const WorksheetBatch(this.solved, this.unresolved);
  final List<WorksheetExample> solved;
  final List<String> unresolved;

  bool get complete => solved.isNotEmpty && unresolved.isEmpty;
  String get answer => 'Решено ' + solved.length.toString() +
      (unresolved.isEmpty ? ' пунктов' :
       ' пунктов; проверить ' + unresolved.length.toString());

  String get notebook => solved.asMap().entries.map((entry) =>
      (entry.key + 1).toString() + ') ' + entry.value.working).join('\n') +
      (unresolved.isEmpty ? '' :
        '\n\nНУЖНО СВЕРИТЬ С ФОТО:\n' +
        unresolved.map((line) => '• ' + line).join('\n'));

  String get explanation =>
      'Сначала переводим величины одного типа в общие единицы, '
      'затем сравниваем или выполняем действие. '
      'Каждая строка проверяется отдельно; нечёткие строки не решаются автоматически.';

  static WorksheetBatch? solve(String source) {
    final solved = <WorksheetExample>[];
    final unresolved = <String>[];
    final lines = source.replaceAll('\r', '').split('\n')
        .map((s) => s.trim()).where((s) => s.isNotEmpty);
    for (final line in lines) {
      if (_isHeading(line)) continue;
      final example = WorksheetUnitMath.solve(line);
      if (example != null) {
        solved.add(example);
      } else {
        unresolved.add(line);
      }
    }
    if (solved.isEmpty) return null;
    return WorksheetBatch(solved, unresolved);
  }

  static bool _isHeading(String input) {
    final s = input.toLowerCase().trim();
    return s.startsWith('фамилия') ||
        s.startsWith('подготовка к') ||
        RegExp(r'^\s*[123]\s*[.)]\s*(?:сравни|выполни|переведи)')
            .hasMatch(s) ||
        s == 'единицы измерения.' ||
        s == 'по математике';
  }
}

class _UnitValue {
  const _UnitValue(this.kind, this.base, this.parts, this.smallestUnit);
  final String kind;
  final int base;
  final List<String> parts;
  final String smallestUnit;
}

class WorksheetUnitMath {
  static const Map<String, int> _size = {
    'см': 1, 'дм': 10, 'м': 100, 'кг': 1, 'ц': 100, 'л': 1,
  };
  static const Map<String, String> _kind = {
    'см': 'длина', 'дм': 'длина', 'м': 'длина',
    'кг': 'масса', 'ц': 'масса', 'л': 'объём',
  };
  static final _token = RegExp(r'(\d{1,4})\s*(см|дм|м|кг|ц|л)');
  static final _placeholder = RegExp(r'(?:\.{2,}|…|_+)\s*(см|дм|м|кг|ц|л)');
  static final _comparison = RegExp(r'^(.+?)\s*(?:\.{2,}|…|[<>])\s*(.+?)$');
  static final _arithmetic = RegExp(r'^(.+?)\s*([+−-])\s*(.+?)\s*=\s*\??$');

  static String _clean(String input) => input.trim().toLowerCase()
      .replaceAll('ё', 'е')
      .replaceAll('–', '−')
      .replaceAll('\u00a0', ' ')
      .replaceAll(RegExp(r'\s+'), ' ');

  static _UnitValue? _read(String text) {
    final input = _clean(text);
    final tokens = _token.allMatches(input).toList();
    if (tokens.isEmpty || tokens.length > 2) return null;
    if (input.replaceAll(_token, '').trim().isNotEmpty) return null;
    final parts = <String>[];
    final used = <String>{};
    String? kind;
    int total = 0;
    int? smallest;
    String? smallestUnit;
    for (final token in tokens) {
      final number = int.tryParse(token.group(1)!);
      final unit = token.group(2)!;
      if (number == null || !used.add(unit)) return null;
      kind ??= _kind[unit];
      if (kind != _kind[unit]) return null;
      final scale = _size[unit]!;
      total += number * scale;
      parts.add(number.toString() + ' ' + unit);
      if (smallest == null || scale < smallest) {
        smallest = scale;
        smallestUnit = unit;
      }
    }
    if (total > 100000) return null;
    return _UnitValue(kind!, total, parts, smallestUnit!);
  }

  static WorksheetExample? solve(String line) {
    final raw = line.trim();
    final text = _clean(raw);
    // Comparisons use printed dots (or an existing inequality symbol).
    final comparison = text.contains('=') ? null : _comparison.firstMatch(text);
    if (comparison != null) {
      final left = _read(comparison.group(1)!);
      final right = _read(comparison.group(2)!);
      if (left == null || right == null || left.kind != right.kind) return null;
      final sign = left.base < right.base ? '<' :
          left.base > right.base ? '>' : '=';
      final lhs = left.parts.join(' ');
      final rhs = right.parts.join(' ');
      final baseUnit = left.kind == 'длина' ? 'см' :
          left.kind == 'масса' ? 'кг' : 'л';
      return WorksheetExample(raw, lhs + ' ' + sign + ' ' + rhs,
          lhs + ' ' + sign + ' ' + rhs +
          '  (' + left.base.toString() + ' ' + baseUnit +
          ' ' + sign + ' ' + right.base.toString() + ' ' + baseUnit + ')',
          'Сравнивай величины в одинаковых единицах измерения.');
    }

    // Operations: both operands must be fully parsed measurements.
    final arithmetic = _arithmetic.firstMatch(text);
    if (arithmetic != null) {
      final left = _read(arithmetic.group(1)!);
      final right = _read(arithmetic.group(3)!);
      if (left == null || right == null || left.kind != right.kind) return null;
      final plus = arithmetic.group(2) == '+';
      final total = plus ? left.base + right.base : left.base - right.base;
      if (total < 0 || total > 100000) return null;
      // Keep the original unit if both quantities use that same single unit;
      // otherwise use the smallest unit needed for an exact calculation.
      final sameSingleUnit = left.parts.length == 1 && right.parts.length == 1 &&
          left.smallestUnit == right.smallestUnit;
      final outputUnit = sameSingleUnit
          ? left.smallestUnit
          : (_size[left.smallestUnit]! < _size[right.smallestUnit]!
              ? left.smallestUnit : right.smallestUnit);
      final outputValue = total ~/ _size[outputUnit]!;
      if (total % _size[outputUnit]! != 0) return null;
      final lhs = left.parts.join(' ');
      final rhs = right.parts.join(' ');
      final sign = plus ? '+' : '−';
      final answer = outputValue.toString() + ' ' + outputUnit;
      final baseUnit = left.kind == 'длина' ? 'см' :
          left.kind == 'масса' ? 'кг' : 'л';
      return WorksheetExample(raw, answer,
          lhs + ' ' + sign + ' ' + rhs + ' = ' + answer +
          '  (' + left.base.toString() + ' ' + baseUnit + ' ' + sign +
          ' ' + right.base.toString() + ' ' + baseUnit +
          ' = ' + total.toString() + ' ' + baseUnit + ')',
          'Перед сложением и вычитанием переведи величины в общие единицы.');
    }

    // Conversions have an explicitly printed target, e.g. 58 см = ... дм ... см.
    final equalAt = text.indexOf('=');
    if (equalAt == -1 || text.indexOf('=', equalAt + 1) != -1) return null;
    final original = _read(text.substring(0, equalAt));
    if (original == null) return null;
    final rhs = text.substring(equalAt + 1).trim();
    final destinations = _placeholder.allMatches(rhs).toList();
    if (destinations.isEmpty || destinations.length > 2 ||
        rhs.replaceAll(_placeholder, '').trim().isNotEmpty) return null;
    final units = destinations.map((m) => m.group(1)!).toList();
    if (units.toSet().length != units.length ||
        units.any((u) => _kind[u] != original.kind)) return null;
    final values = <String>[];
    int remaining = original.base;
    // Mixed units must be ordered from larger to smaller.
    if (units.length == 2 && _size[units[0]]! <= _size[units[1]]!) return null;
    for (final unit in units) {
      final value = remaining ~/ _size[unit]!;
      remaining %= _size[unit]!;
      values.add(value.toString() + ' ' + unit);
    }
    if (remaining != 0) return null;
    final answer = values.join(' ');
    final left = original.parts.join(' ');
    return WorksheetExample(raw, answer, left + ' = ' + answer,
        '1 м = 10 дм = 100 см. 1 ц = 100 кг. Единицы длины и массы не смешиваются.');
  }
}
