import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
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
}

/// Splits only clear task headings. Never guesses numbers or missing text.
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
    if (tasks.isEmpty || prelude.isNotEmpty ||
        tasks.any((task) => task.text.length < 3)) {
      return [Exercise('карточка', lines.join('\n'))];
    }
    return tasks;
  }
}
