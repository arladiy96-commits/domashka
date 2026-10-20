import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;
import 'package:tesseract_ocr/tesseract_ocr.dart';
import 'package:tesseract_ocr/ocr_engine_config.dart';
import 'models.dart';

/// Runs locally. Model files ship inside the APK (downloaded only at build).
class OfflineCardOcr {
  static Future<String> recognize(Uint8List bytes) async {
    if (bytes.isEmpty) throw StateError('Изображение пустое.');
    final directory = await getTemporaryDirectory();
    final path = directory.path + '/domashka_ocr_' +
        DateTime.now().microsecondsSinceEpoch.toString() + '.jpg';
    final file = File(path);
    try {
      await file.writeAsBytes(bytes, flush: true);
      final text = await TesseractOcr.extractText(path,
        config: OCRConfig(
          language: 'rus+eng',
          engine: OCREngine.tesseract,
          options: {
            'preserve_interword_spaces': '1',
            'tessedit_pageseg_mode': '3',
          },
        ),
      );
      if (text.trim().isEmpty) {
        throw StateError('Не удалось разобрать текст. Сними карточку ближе и без бликов.');
      }
      return text;
    } finally {
      if (await file.exists()) await file.delete();
    }
  }

  /// Two narrow columns must not be passed to OCR as a single text stream:
  /// Tesseract often joins adjacent lines and corrupts mathematical units.
  /// Split the original bitmap before OCR so each column is independent.
  static Future<List<Exercise>> recognizeColumns(Uint8List imageBytes) async {
    final photo = img.decodeImage(imageBytes);
    if (photo == null) throw StateError('Не удалось открыть фотографию.');
    final middle = photo.width ~/ 2;
    if (middle < 120 || photo.height < 180) {
      throw StateError('Снимок слишком маленький для двух столбцов.');
    }
    final margin = (photo.width * 0.005).round();
    final left = img.copyCrop(photo, x: 0, y: 0,
        width: middle + margin, height: photo.height);
    final right = img.copyCrop(photo, x: middle - margin, y: 0,
        width: photo.width - middle + margin, height: photo.height);
    final tasks = <Exercise>[];
    for (final item in [
      ('левый столбец', left),
      ('правый столбец', right),
    ]) {
      try {
        final bytes = Uint8List.fromList(img.encodeJpg(item.$2, quality: 95));
        final text = await recognize(bytes);
        if (text.trim().isNotEmpty) {
          tasks.add(Exercise(item.$1, text.trim()));
        }
      } catch (_) {
        // Other column is still useful; never substitute invented OCR text.
      }
    }
    if (tasks.isEmpty) {
      throw StateError('Не удалось разобрать ни один столбец. '
          'Попробуй снять карточку ближе, ровнее и при хорошем освещении.');
    }
    return tasks;
  }

  /// Hints at merged side-by-side exercises; never rewrites OCR content.
  static bool looksLikeTwoColumns(String raw) {
    var suspicious = 0;
    for (final line in raw.split('\n')) {
      final dots = RegExp(r'(?:\.{2,}|…)').allMatches(line).length;
      final equals = '='.allMatches(line).length;
      if (dots > 1 || equals > 1) suspicious++;
    }
    return suspicious >= 2;
  }
}

// Splits only clear task headings. Never guesses numbers or missing text.
class OfflineCardParser {
  static final _header = RegExp(r'^\s*(?:№\s*)?(\d{1,2})\s*[.)]\s+(.+)$');

  static List<Exercise> split(String raw) {
    final lines = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n')
        .replaceAll('\u00a0', ' ')
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty).toList();
    if (lines.isEmpty) return const [];

    final tasks = <Exercise>[];
    final prelude = <String>[];
    final content = <String>[];
    String? current;

    void commit() {
      if (current != null && content.isNotEmpty) {
        tasks.add(Exercise(current!, content.join('\n')));
        content.clear();
      }
    }

    for (final line in lines) {
      final heading = _header.firstMatch(line);
      if (heading != null && tasks.length < 14) {
        commit();
        current = heading.group(1);
        content.add(heading.group(2)!.trim());
      } else if (current == null) {
        prelude.add(line);
      } else {
        content.add(line);
      }
    }
    commit();

    // Don't silently drop headings, common instructions, or short tasks.
    if (tasks.isEmpty || tasks.any((task) => task.text.length < 3)) {
      return [Exercise('карточка', lines.join('\n'))];
    }
    // Keep the worksheet's title as a separate item, not in the first
    // problem. This also preserves the three main numbered tasks.
    if (prelude.isNotEmpty) {
      tasks.insert(0, Exercise('инструкция', prelude.join('\n')));
    }
    return tasks;
  }
}
