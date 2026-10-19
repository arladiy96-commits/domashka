import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:http/http.dart' as http;
import 'package:pdfrx/pdfrx.dart';
import 'models.dart';
import 'math_engine.dart';
import 'store.dart';

class AiService {
  AiService(this.store);
  final AppStore store;

  Future<String> _gemini(String prompt, {Uint8List? image, String mime = 'image/jpeg'}) async {
    if (store.geminiKey.isEmpty) throw StateError('Добавьте ключ Gemini в настройках.');
    final parts = <Map<String, dynamic>>[{'text': prompt}];
    if (image != null) {
      parts.add({'inline_data': {'mime_type': mime, 'data': base64Encode(image)}});
    }
    final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/'
      '${Uri.encodeComponent(store.geminiModel)}:generateContent');
    final response = await http.post(url, headers: {
      'Content-Type': 'application/json', 'x-goog-api-key': store.geminiKey,
    }, body: jsonEncode({'contents': [{'parts': parts}],
      'generationConfig': {'temperature': 0.1}})).timeout(const Duration(seconds: 65));
    if (response.statusCode != 200) {
      throw StateError('Gemini: HTTP ${response.statusCode}. ${_safeError(response.body)}');
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = decoded['candidates'] as List? ?? [];
    if (candidates.isEmpty) throw StateError('Gemini не смог прочитать задание.');
    final content = (candidates.first as Map)['content'] as Map?;
    final textParts = content?['parts'] as List? ?? [];
    final text = textParts.whereType<Map>().map((p) => (p['text'] ?? '').toString()).join('\n');
    if (text.trim().isEmpty) throw StateError('Gemini вернул пустой результат.');
    return text;
  }

  Future<String> _grok(String prompt) async {
    if (store.grokKey.isEmpty) throw StateError('Добавьте ключ Grok в настройках.');
    final response = await http.post(Uri.parse('https://api.x.ai/v1/chat/completions'),
      headers: {'Authorization': 'Bearer ${store.grokKey}',
        'Content-Type': 'application/json'},
      body: jsonEncode({'model': store.grokModel,
        'messages': [
          {'role': 'system', 'content': 'Ты опытный учитель начальных классов русскоязычной школы Казахстана. '
            'Строго придерживайся программы второго класса; не вводи сложные методы. '
            'Точно вычисляй, не выдумывай отсутствующее условие, выдавай только JSON.'},
          {'role': 'user', 'content': prompt},
        ]})).timeout(const Duration(seconds: 80));
    if (response.statusCode != 200) {
      throw StateError('Grok: HTTP ${response.statusCode}. ${_safeError(response.body)}');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = data['choices'] as List? ?? [];
    if (choices.isEmpty) throw StateError('Grok не предоставил ответ.');
    return (((choices.first as Map)['message'] as Map?)?['content'] ?? '').toString();
  }

  static String _safeError(String raw) {
    // Avoid showing full provider responses with potentially sensitive data.
    try {
      final obj = jsonDecode(raw) as Map;
      final error = obj['error'];
      if (error is Map) {
        final detail = (error['message'] ?? 'Ошибка API').toString();
        return detail.length > 220 ? detail.substring(0, 220) : detail;
      }
    } catch (_) {}
    return 'Проверьте ключ, выбранную модель и квоту.';
  }

  static dynamic _json(String raw) {
    var text = raw.trim();
    if (text.startsWith('```')) {
      text = text.replaceFirst(RegExp(r'^```(?:json)?\s*'), '').replaceFirst(RegExp(r'```\s*$'), '').trim();
    }
    try { return jsonDecode(text); } catch (_) {}
    final objectStart = text.indexOf('{');
    final objectEnd = text.lastIndexOf('}');
    if (objectStart >= 0 && objectEnd > objectStart) {
      return jsonDecode(text.substring(objectStart, objectEnd + 1));
    }
    final listStart = text.indexOf('[');
    final listEnd = text.lastIndexOf(']');
    if (listStart >= 0 && listEnd > listStart) {
      return jsonDecode(text.substring(listStart, listEnd + 1));
    }
    throw const FormatException('Модель вернула ответ в неверном формате.');
  }

  Future<List<Exercise>> readImage(Uint8List image, {String mime = 'image/jpeg'}) async {
    final text = await _gemini('Прочитай ВЕСЬ текст школьной карточки или страницы для 2 класса. '
      'Сохраняй арифметические знаки, числа, условия и разбивку на пункты. '
      'НЕ решай ничего. Не угадывай неразборчивое. '
      'Ответ дай JSON-массивом объектов {"number":"1","text":"точное условие"}. '
      'Отдельные упражнения разделяй, но единое условие не дроби. '
      'Для неразборчивых слов используй пометку [неразборчиво].', image: image, mime: mime);
    final decoded = _json(text);
    final list = decoded is List ? decoded : (decoded is Map ? decoded['tasks'] : null);
    if (list is! List) throw const FormatException('Не удалось выделить упражнения.');
    return list.whereType<Map>().map((e) => Exercise((e['number'] ?? '—').toString(),
      (e['text'] ?? '').toString())).where((e) => e.text.trim().isNotEmpty).toList();
  }

  Future<List<Exercise>> readPdfPage(String path, int number) async {
    final document = await PdfDocument.openFile(path);
    PdfImage? img;
    ui.Image? raster;
    try {
      if (number < 1 || number > document.pages.length) {
        throw RangeError('Страница вне учебника.');
      }
      final page = document.pages[number - 1];
      final width = 1300;
      final height = (width * page.height / page.width).round();
      img = await page.render(width: width, height: height);
      if (img == null) throw StateError('Не удалось открыть изображение страницы.');
      raster = await img.createImage();
      final png = await raster.toByteData(format: ui.ImageByteFormat.png);
      if (png == null) throw StateError('Не удалось сохранить изображение страницы.');
      return readImage(png.buffer.asUint8List(), mime: 'image/png');
    } finally {
      raster?.dispose(); img?.dispose(); await document.dispose();
    }
  }

  Future<StudyResult> solve(String problem, {String source = 'Вручную',
      String? bookId, int? page, String? number}) async {
    final engine = MathEngine.solve(problem);
    String answer = engine?.value.toString() ?? '';
    String notebook = engine?.notebook ?? '';
    String explanation = engine?.explanation ?? '';
    String rule = engine?.rule ?? '';
    var practice = engine?.practice ?? <PracticeTask>[];
    bool verified = engine != null;
    final warnings = <String>[];

    if (store.grokKey.isNotEmpty) {
      try {
        final raw = await _grok('Реши задание для второго класса и объясни маме, как учить ребёнка. '
          'Условие: $problem\n'
          'Верни СТРОГО JSON объект: '
          '{"answer":"краткий ответ","notebook":"решение в тетрадь",'
          '"explanation":"пошагово и доступно","rule":"правило",'
          '"practice":[{"question":"аналогичное задание","answer":"точный ответ"}]}. '
          'Для текстовой задачи сначала короткая запись, затем действия и ответ. '
          'Не делай сложнее программы второго класса. Дай ровно три полезных похожих задания.');
        final decoded = _json(raw);
        if (decoded is! Map) throw const FormatException('Неправильный JSON от Grok.');
        final aiAnswer = (decoded['answer'] ?? '').toString();
        final aiNotebook = (decoded['notebook'] ?? '').toString();
        final aiExplanation = (decoded['explanation'] ?? '').toString();
        final aiRule = (decoded['rule'] ?? '').toString();
        if (engine != null && !MathEngine.sameValue(engine, aiAnswer)) {
          warnings.add('Ответ Grok отличается от независимого вычисления. '
            'Показан проверенный расчёт; объяснение ИИ требует внимания.');
        } else {
          if (aiAnswer.isNotEmpty) answer = aiAnswer;
          if (aiNotebook.isNotEmpty) notebook = aiNotebook;
        }
        if (aiExplanation.isNotEmpty) explanation = aiExplanation;
        if (aiRule.isNotEmpty) rule = aiRule;
        if (decoded['practice'] is List) {
          final items = (decoded['practice'] as List).whereType<Map>().map((e) =>
            PracticeTask((e['question'] ?? '').toString(), (e['answer'] ?? '').toString()))
              .where((e) => e.question.isNotEmpty && e.answer.isNotEmpty).toList();
          if (items.isNotEmpty) practice = items;
        }
      } catch (error) {
        warnings.add('Grok: $error');
      }
    } else if (engine == null) {
      warnings.add('Нужно подключить Grok: задача не относится к поддерживаемым локальным примерам.');
    }

    if (engine == null && answer.isNotEmpty && store.checkWithGemini && store.geminiKey.isNotEmpty) {
      try {
        final raw = await _gemini('Независимо проверь ответ по заданию 2 класса. '
          'Условие: $problem\nПредлагаемый ответ: $answer\n'
          'Верни JSON {"ok":true/false,"note":"краткая причина","correct":"правильный ответ"}. '
          'Не соглашайся с ошибкой.');
        final value = _json(raw);
        if (value is Map && value['ok'] == true) verified = true;
        if (value is Map && value['ok'] == false) {
          warnings.add('Gemini не подтвердил решение: ${value['note'] ?? ''}. '
            'Предложение проверки: ${value['correct'] ?? ''}.');
        }
      } catch (error) { warnings.add('Независимая проверка Gemini недоступна: $error'); }
    }

    return StudyResult(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      problem: problem, answer: answer, notebook: notebook,
      explanation: explanation, rule: rule, source: source,
      createdAt: DateTime.now().toIso8601String(), bookId: bookId,
      page: page, number: number, verified: verified,
      warning: warnings.join('\n'), practice: practice);
  }
}