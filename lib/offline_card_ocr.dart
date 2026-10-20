import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/foundation.dart';
import 'package:tesseract_ocr/tesseract_ocr.dart';
import 'package:tesseract_ocr/ocr_engine_config.dart';
import 'models.dart';
import 'ocr_photo_preprocessor.dart';

/// Runs locally. Model files ship inside the APK (downloaded only at build).
class OfflineCardOcr {
  /// Scanning, perspective correction and image enhancement run in a
  /// background isolate so large phone photos never freeze the screen.
  static Future<String> recognize(Uint8List bytes) async {
    final prepared = await compute(_prepareFullPage, bytes);
    return _recognizePrepared(prepared);
  }

  static Future<String> _recognizePrepared(Uint8List preparedPng) async {
    final directory = await getTemporaryDirectory();
    final path = directory.path + '/domashka_ocr_' +
        DateTime.now().microsecondsSinceEpoch.toString() + '.png';
    final file = File(path);
    try {
      await file.writeAsBytes(preparedPng, flush: true);
      final result = await TesseractOcr.extractText(path,
        config: OCRConfig(
          language: 'rus',
          engine: OCREngine.tesseract,
          options: {
            'preserve_interword_spaces': '1',
            'tessedit_pageseg_mode': '6',
          },
        ),
      );
      if (result.trim().isEmpty) {
        throw StateError('Не удалось прочитать карточку. '
            'Попробуй снять лист ровнее, ближе и без бликов.');
      }
      return result;
    } finally {
      if (await file.exists()) await file.delete();
    }
  }

  static Future<List<Exercise>> recognizeColumns(Uint8List bytes) async {
    final columns = await compute(_preparePageColumns, bytes);
    final tasks = <Exercise>[];
    for (var i = 0; i < columns.length; i++) {
      final name = i == 0 ? 'левый столбец' : 'правый столбец';
      try {
        final result = await _recognizePrepared(columns[i]);
        tasks.add(Exercise(name, result.trim()));
      } catch (_) {
        // Never silently omit part of a student's worksheet.
        tasks.add(Exercise(name, 'Не удалось распознать этот столбец. '
            'Сверь с фотографией и введи задания вручную.'));
      }
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


/// Pure, transferable image operations invoked by Flutter's compute().
Uint8List _prepareFullPage(Uint8List original) {
  final page = OcrPhotoPreprocessor.decodePage(original);
  return Uint8List.fromList(
      img.encodePng(OcrPhotoPreprocessor.improve(page)));
}

List<Uint8List> _preparePageColumns(Uint8List original) {
  final page = OcrPhotoPreprocessor.decodePage(original);
  return OcrPhotoPreprocessor.splitColumns(page)
      .map((column) => Uint8List.fromList(
          img.encodePng(OcrPhotoPreprocessor.improve(column))))
      .toList();
}
