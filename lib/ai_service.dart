import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:pdfrx/pdfrx.dart';
import 'models.dart';
import 'math_engine.dart';
import 'gemini_models.dart';
import 'groq_models.dart';
import 'store.dart';
import 'offline_catalog.dart';

class AiService {
  AiService(this.store);
  final AppStore store;


  /// Returns only Flash models that explicitly support generateContent.
  /// The list comes from the user's own API key, not a hard-coded catalog.
  Future<List<String>> listGeminiModels({String? apiKey}) async {
    final key = (apiKey ?? store.geminiKey).trim();
    if (key.isEmpty) throw StateError('Сначала укажите ключ Gemini.');
    final choices = <String>{};
    String? nextPage;
    for (var page = 0; page < 5; page++) {
      final uri = Uri.https('generativelanguage.googleapis.com', '/v1beta/models', {
        'pageSize': '100',
        if (nextPage != null) 'pageToken': nextPage,
      });
      final response = await http.get(
        uri, headers: {'x-goog-api-key': key},
      ).timeout(const Duration(seconds: 25));
      if (response.statusCode != 200) {
        if (response.statusCode == 401 || response.statusCode == 403) {
          throw StateError('Ключ Gemini отклонён. Проверьте его в Google AI Studio.');
        }
        throw StateError('Не удалось получить модели Gemini: HTTP '
            '${response.statusCode}. ${_safeError(response.body)}');
      }
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      choices.addAll(GeminiModels.availableFromResponse(body));
      final token = (body['nextPageToken'] ?? '').toString();
      if (token.isEmpty) break;
      nextPage = token;
    }
    final result = choices.toList()..sort(GeminiModels.compare);
    return result;
  }

  Future<http.Response> _geminiRequest(
    String model, String prompt, Uint8List? image, String mime,
  ) {
    final parts = <Map<String, dynamic>>[{'text': prompt}];
    if (image != null) {
      parts.add({'inline_data': {'mime_type': mime, 'data': base64Encode(image)}});
    }
    final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/'
      '${Uri.encodeComponent(model)}:generateContent');
    return http.post(url, headers: {
      'Content-Type': 'application/json', 'x-goog-api-key': store.geminiKey,
    }, body: jsonEncode({'contents': [{'parts': parts}]}))
      .timeout(const Duration(seconds: 90));
  }

  static String _geminiText(http.Response response) {
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = decoded['candidates'] as List? ?? [];
    if (candidates.isEmpty) throw StateError('Gemini не смог прочитать задание.');
    final content = (candidates.first as Map)['content'] as Map?;
    final textParts = content?['parts'] as List? ?? [];
    final text = textParts.whereType<Map>().map((part) =>
        (part['text'] ?? '').toString()).join('\n');
    if (text.trim().isEmpty) {
      throw StateError('Gemini вернул пустой результат. Попробуйте ещё раз.');
    }
    return text;
  }

  Future<String> _gemini(String prompt, {
    Uint8List? image, String mime = 'image/jpeg',
  }) async {
    if (store.geminiKey.isEmpty) throw StateError('Добавьте ключ Gemini в настройках.');
    final requested = GeminiModels.normalize(store.geminiModel);
    var response = await _geminiRequest(requested, prompt, image, mime);
    if (response.statusCode == 404) {
      // A retired model may remain persisted in an older installation.
      // Look up compatible models and retry once, avoiding premium/pro models.
      try {
        final models = await listGeminiModels();
        final alternative = models.where((m) => m != requested).firstOrNull;
        if (alternative != null) {
          final retried = await _geminiRequest(alternative, prompt, image, mime);
          if (retried.statusCode == 200) {
            store.geminiModel = alternative;
            await store.save();
            return _geminiText(retried);
          }
          response = retried;
        }
      } catch (_) {
        // Original 404 message below gives the user a recoverable action.
      }
      if (response.statusCode == 404) {
        throw StateError('Модель Gemini «$requested» недоступна. '
          'Откройте Настройки → Gemini → «Получить доступные модели» '
          'и выберите подходящую модель.');
      }
    }
    if (response.statusCode == 429) {
      throw StateError('Исчерпан лимит запросов Gemini. '
        'Попробуйте позже или проверьте квоту API.');
    }
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw StateError('Доступ Gemini отклонён. Проверьте ключ и разрешения модели.');
    }
    if (response.statusCode != 200) {
      throw StateError('Gemini: HTTP ${response.statusCode}. ${_safeError(response.body)}');
    }
    return _geminiText(response);
  }



  /// Fetch active models from the user's GroqCloud account without inference.
  Future<List<String>> listGroqModels({String? apiKey}) async {
    final key = (apiKey ?? store.groqKey).trim();
    if (key.isEmpty) throw StateError('Сначала укажите ключ Groq Cloud.');
    if (key.startsWith('xai-')) {
      throw StateError('Это ключ xAI, а нужен ключ из console.groq.com.');
    }
    final response = await http.get(GroqModels.modelsUri,
      headers: {'Authorization': 'Bearer $key'},
    ).timeout(const Duration(seconds: 25));
    _checkGroqResponse(response);
    return GroqModels.availableFromResponse(
      jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<http.Response> _groqRequest(String model, String prompt) {
    return http.post(GroqModels.completionsUri,
      headers: {'Authorization': 'Bearer ${store.groqKey}',
        'Content-Type': 'application/json'},
      body: jsonEncode({
        'model': model,
        'temperature': 0.2,
        'messages': [
          {'role': 'system', 'content': 'Ты опытный учитель начальных классов '
            'русскоязычной школы Казахстана. Строго придерживайся программы '
            'второго класса; не вводи сложные методы. Точно вычисляй, '
            'не выдумывай отсутствующее условие, выдавай только JSON.'},
          {'role': 'user', 'content': prompt},
        ],
      }),
    ).timeout(const Duration(seconds: 80));
  }

  void _checkGroqResponse(http.Response response) {
    final status = response.statusCode;
    if (status == 200) return;
    if (status == 401) {
      throw StateError('Groq отклонил API-ключ. Проверьте ключ в console.groq.com.');
    }
    if (status == 403) {
      throw StateError('У ключа нет разрешения на выбранную модель Groq. '
        'Проверьте ограничения проекта.');
    }
    if (status == 404) {
      throw StateError('Выбранная модель Groq недоступна. '
        'Откройте настройки → Groq Cloud → Получить доступные модели.');
    }
    if (status == 429) {
      throw StateError('Исчерпан текущий лимит Groq Cloud. '
        'Попробуйте позже. Платные запросы автоматически не включаются.');
    }
    if (status == 413) {
      throw StateError('Слишком длинное задание. Попробуйте разделить его на пункты.');
    }
    if (status == 402) {
      throw StateError('Недостаточно доступного баланса или квоты Groq.');
    }
    if (status >= 500) {
      throw StateError('Groq временно недоступен (HTTP $status). Повторите позже.');
    }
    throw StateError('Groq HTTP $status: ${_safeError(response.body)}');
  }

  static String _groqText(http.Response response) {
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = data['choices'] as List? ?? [];
    if (choices.isEmpty) throw StateError('Groq не вернул решение.');
    final reply = ((choices.first as Map)['message'] as Map?)?['content'];
    final text = (reply ?? '').toString().trim();
    if (text.isEmpty) throw StateError('Groq вернул пустой ответ.');
    return text;
  }

  Future<String> _groq(String prompt) async {
    if (store.groqKey.isEmpty) {
      throw StateError('Добавьте ключ Groq Cloud в настройках.');
    }
    final current = GroqModels.normalize(store.groqModel);
    var response = await _groqRequest(current, prompt);
    if (response.statusCode == 404) {
      // Retry once only with a known production text model on a missing
      // model, never on rate limit or billing errors.
      try {
        final list = await listGroqModels();
        final alternative = GroqModels.fallback(list, current);
        if (alternative != null) {
          final attempt = await _groqRequest(alternative, prompt);
          if (attempt.statusCode == 200) {
            store.groqModel = alternative;
            await store.save();
            return _groqText(attempt);
          }
          response = attempt;
        }
      } catch (_) {
        // Present the original 404 if discovery is unavailable.
      }
    }
    _checkGroqResponse(response);
    return _groqText(response);
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

  /// Read only the already located task from the original image. Search stays offline.
  /// The output is a draft; user confirms and edits before it is saved.
  Future<String> readOfflineExercise(String pageImagePath, OfflineExercise task) async {
    if (store.geminiKey.isEmpty) {
      throw StateError('Добавьте ключ Gemini в настройках для чтения изображения.');
    }
    final bytes = await File(pageImagePath).readAsBytes();
    final page = img.decodeImage(bytes);
    if (page == null) throw StateError('Не удалось прочитать страницу учебника.');

    final left = (task.left.clamp(0.0, 1.0) * page.width).floor();
    final top = (task.top.clamp(0.0, 1.0) * page.height).floor();
    final right = (task.right.clamp(0.0, 1.0) * page.width).ceil();
    final bottom = (task.bottom.clamp(0.0, 1.0) * page.height).ceil();
    final paddingX = (page.width * 0.012).ceil();
    final paddingY = (page.height * 0.012).ceil();
    final x0 = (left - paddingX).clamp(0, page.width - 1);
    final y0 = (top - paddingY).clamp(0, page.height - 1);
    final x1 = (right + paddingX).clamp(x0 + 1, page.width);
    final y1 = (bottom + paddingY).clamp(y0 + 1, page.height);
    final crop = img.copyCrop(page, x: x0, y: y0,
      width: x1 - x0, height: y1 - y0);
    final jpeg = Uint8List.fromList(img.encodeJpg(crop, quality: 94));

    final result = await _gemini(
      'На изображении только одно упражнение №${task.number} из учебника математики '
      'за 2 класс. Дословно перепиши ПОЛНОЕ условие без решения. '
      'Обязательно сохрани ВСЕ числа, арифметические знаки, подзадания и варианты. '
      'Если есть таблицы, перепиши КАЖДУЮ ячейку в виде понятной Markdown-таблицы '
      'с правильным порядком строк и столбцов. '
      'Если условие зависит от рисунка, кратко опиши сам рисунок и все значения '
      'на нём, не придумывая отсутствующие элементы. '
      'Не переписывай соседние упражнения. Не угадывай: если цифра не читается, '
      'обозначь [неразборчиво]. Верни только условие задания, без комментариев.',
      image: jpeg, mime: 'image/jpeg',
    );
    final value = result.trim();
    if (value.isEmpty) throw StateError('Gemini не смог прочитать условие.');
    return value;
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

    if (store.groqKey.isNotEmpty) {
      try {
        final raw = await _groq('Реши задание для второго класса и объясни маме, как учить ребёнка. '
          'Условие: $problem\n'
          'Верни СТРОГО JSON объект: '
          '{"answer":"краткий ответ","notebook":"решение в тетрадь",'
          '"explanation":"пошагово и доступно","rule":"правило",'
          '"practice":[{"question":"аналогичное задание","answer":"точный ответ"}]}. '
          'Для текстовой задачи сначала короткая запись, затем действия и ответ. '
          'Не делай сложнее программы второго класса. Дай ровно три полезных похожих задания.');
        final decoded = _json(raw);
        if (decoded is! Map) throw const FormatException('Неправильный JSON от Groq.');
        final aiAnswer = (decoded['answer'] ?? '').toString();
        final aiNotebook = (decoded['notebook'] ?? '').toString();
        final aiExplanation = (decoded['explanation'] ?? '').toString();
        final aiRule = (decoded['rule'] ?? '').toString();
        if (engine != null && !MathEngine.sameValue(engine, aiAnswer)) {
          warnings.add('Ответ Groq отличается от независимого вычисления. '
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
        warnings.add('Groq: $error');
      }
    } else if (engine == null) {
      warnings.add('Нужно подключить Groq: задача не относится к поддерживаемым локальным примерам.');
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