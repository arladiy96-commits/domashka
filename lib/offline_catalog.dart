import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:sqflite/sqflite.dart';

import 'models.dart';

/// A local textbook package. No API calls are made while importing or searching.
class OfflineCatalog {
  static final RegExp _pageName = RegExp(r'^pages/[0-9]{3}\.jpg

  static Future<BookRecord> install(
    String zipPath,
    Directory appRoot, {
    void Function(double progress)? onProgress,
  }) async {
    final zipFile = File(zipPath);
    if (!await zipFile.exists()) {
      throw StateError('Не удалось открыть выбранный ZIP.');
    }
    if (await zipFile.length() > 80 * 1024 * 1024) {
      throw StateError('Архив слишком большой для импорта.');
    }
    final inputStream = InputFileStream(zipPath);
    try {
    final archive = ZipDecoder().decodeStream(inputStream, verify: true);
    final manifestEntry = archive.files.where((e) => e.name == 'manifest.json' && e.isFile);
    if (manifestEntry.length != 1 || !archive.files.any(
      (e) => e.name == 'catalog.sqlite' && e.isFile,
    )) {
      throw const FormatException('В архиве нет manifest.json или catalog.sqlite.');
    }

    final manifestBytes = manifestEntry.single.readBytes();
    if (manifestBytes == null) {
      throw const FormatException('Не удалось прочитать manifest.json.');
    }
    final manifest = jsonDecode(utf8.decode(manifestBytes)) as Map<String, dynamic>;
    if (manifest['format'] != 'domashka-offline-book' ||
        manifest['format_version'] != 1) {
      throw const FormatException('Неподдерживаемый формат офлайн-учебника.');
    }
    final id = (manifest['book_id'] ?? '').toString();
    if (!RegExp(r'^[a-zA-Z0-9_-]{3,90}$').hasMatch(id)) {
      throw const FormatException('Некорректный идентификатор учебника.');
    }
    final pageCount = (manifest['page_count'] as num?)?.toInt() ?? 0;
    if (pageCount < 1 || pageCount > 999) {
      throw const FormatException('Некорректное количество страниц.');
    }

    final shelf = Directory('${appRoot.path}/offline_books');
    await shelf.create(recursive: true);
    final destination = Directory('${shelf.path}/$id');
    BookRecord makeRecord() => BookRecord(
      id: id,
      title: (manifest['book_title'] ?? 'Учебник').toString(),
      path: '${destination.path}/catalog.sqlite',
      offlineDirectory: destination.path,
      pageCount: pageCount,
    );
    // Re-importing a previously installed package does not erase its data.
    if (await File('${destination.path}/catalog.sqlite').exists()) {
      return makeRecord();
    }

    final stage = Directory(
      '${shelf.path}/.install_${DateTime.now().microsecondsSinceEpoch}',
    );
    await stage.create(recursive: true);
    try {
      var total = 0;
      final entries = archive.files.where((e) => e.isFile && (
        e.name == 'manifest.json' ||
        e.name == 'catalog.sqlite' ||
        _pageName.hasMatch(e.name) ||
        _cropName.hasMatch(e.name)
      )).toList();
      if (entries.length < 3 || entries.length > 1001) {
        throw const FormatException('Неполный или повреждённый каталог.');
      }
      for (var i = 0; i < entries.length; i++) {
        final entry = entries[i];
        total += entry.size;
        if (total > 90 * 1024 * 1024) {
          throw const FormatException('Распакованный архив слишком большой.');
        }
        final target = File('${stage.path}/${entry.name}');
        await target.parent.create(recursive: true);
        final bytes = entry.readBytes();
        if (bytes == null || bytes.length != entry.size) {
          throw FormatException('Повреждённый файл в архиве: ${entry.name}');
        }
        await target.writeAsBytes(bytes, flush: true);
        entry.clear();
        onProgress?.call((i + 1) / (entries.length + 1));
      }
      final dbFile = File('${stage.path}/catalog.sqlite');
      final db = await openDatabase(dbFile.path, readOnly: true);
      try {
        final rows = await db.rawQuery(
          'SELECT COUNT(*) AS count FROM exercises WHERE book_id = ?',
          [id],
        );
        final count = (rows.first['count'] as num?)?.toInt() ?? 0;
        if (count < 1 || count != (manifest['exercise_count'] as num?)?.toInt()) {
          throw const FormatException('Каталог заданий не совпадает с описанием.');
        }
      } finally {
        await db.close();
      }
      if (!await File('${stage.path}/pages/001.jpg').exists()) {
        throw const FormatException('В архиве отсутствуют изображения страниц.');
      }
      if (await destination.exists()) {
        throw FileSystemException('Каталог уже существует.', destination.path);
      }
      await stage.rename(destination.path);
      onProgress?.call(1);
      return makeRecord();
    } catch (_) {
      if (await stage.exists()) await stage.delete(recursive: true);
      rethrow;
    }
    } finally {
      await inputStream.close();
    }
  }

  static Future<OfflineExercise?> find(
    BookRecord book, int printedPage, String number,
  ) async {
    if (!book.isOffline) return null;
    final db = await openDatabase(book.path, readOnly: true);
    try {
      final schema = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'exercise_structures' LIMIT 1",
      );
      final hasStructures = schema.isNotEmpty;
      final rows = await db.rawQuery(
        hasStructures
          ? 'SELECT e.number, e.text_ocr, e.crop_x0, e.crop_y0, '
            'e.crop_x1, e.crop_y1, s.structure_json '
            'FROM exercises e LEFT JOIN exercise_structures s '
            'ON s.exercise_id = e.id '
            'WHERE e.book_id = ? AND e.printed_page = ? AND e.number = ? LIMIT 1'
          : 'SELECT number, text_ocr, crop_x0, crop_y0, crop_x1, crop_y1 '
            'FROM exercises WHERE book_id = ? AND printed_page = ? AND number = ? LIMIT 1',
        [book.id, printedPage, number.trim()],
      );
      if (rows.isEmpty) return null;
      return OfflineExercise.fromRow(rows.first);
    } finally {
      await db.close();
    }
  }
}

class OfflineExercise {
  const OfflineExercise({
    required this.number,
    required this.ocrText,
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
    this.structure,
  });
  final String number, ocrText;
  final double left, top, right, bottom;
  final Map<String, dynamic>? structure;

  bool get firstPassReviewed =>
      structure?['review_status'] == 'first_pass_reviewed';
  String get sourceStatement => (structure?['statement'] ?? '').toString().trim();
  String get sourceCropImage =>
      (structure?['source_crop_image'] ?? '').toString();
  List<Map<String, dynamic>> get blocks =>
      (structure?['blocks'] as List? ?? [])
          .whereType<Map>()
          .map((block) => Map<String, dynamic>.from(block))
          .toList();

  /// Keep every table cell and original figure data in the solver prompt.
  /// Unreviewed OCR must never silently become trusted exercise text.
  String get structuredSolveText {
    if (!firstPassReviewed) return '';
    final lines = <String>[sourceStatement];
    for (final block in blocks) {
      final kind = (block['type'] ?? '').toString();
      if (kind == 'table') {
        final title = (block['title'] ?? '').toString();
        if (title.isNotEmpty) lines.add('Таблица: $title');
        final headers = (block['columns'] as List? ?? []);
        if (headers.isNotEmpty) lines.add(headers.join(' | '));
        for (final row in (block['rows'] as List? ?? [])) {
          if (row is List) {
            lines.add(row.map((cell) => cell.toString().isEmpty
                ? '□' : cell.toString()).join(' | '));
          }
        }
      } else if (kind == 'expressions') {
        lines.addAll((block['items'] as List? ?? []).map((v) => v.toString()));
      } else if (kind == 'figure') {
        lines.add('Описание рисунка: ${(block['description'] ?? '').toString()}');
        if (block['data'] != null) {
          lines.add('Данные рисунка: ${jsonEncode(block['data'])}');
        }
        if (block['requires_math_interpretation'] == true) {
          lines.add('ВНИМАНИЕ: модель рисунка требует проверки. '
              'Не додумывай неоднозначные элементы.');
        }
      }
    }
    final context = structure?['math_context'];
    if (context is Map) {
      lines.add('Учебная тема: ${(context['topic'] ?? '').toString()}.');
      lines.add('Оформление для тетради: '
          '${(context['recommended_notebook_format'] ?? '').toString()}.');
      if (context['visual_check_required'] == true) {
        lines.add('Проверка рисунка обязательна: если данных недостаточно, '
            'не выдумывай ответ.');
      }
    }
    return lines.where((x) => x.trim().isNotEmpty).join('\n');
  }

  factory OfflineExercise.fromRow(Map<String, Object?> row) {
    Map<String, dynamic>? data;
    final raw = row['structure_json'];
    if (raw is String && raw.isNotEmpty) {
      try {
        final parsed = jsonDecode(raw);
        if (parsed is Map) data = Map<String, dynamic>.from(parsed);
      } on FormatException {
        // Older books and incomplete catalogs keep OCR fallback only.
      }
    }
    return OfflineExercise(
      number: (row['number'] ?? '').toString(),
      ocrText: (row['text_ocr'] ?? '').toString(),
      left: (row['crop_x0'] as num?)?.toDouble() ?? 0,
      top: (row['crop_y0'] as num?)?.toDouble() ?? 0,
      right: (row['crop_x1'] as num?)?.toDouble() ?? 1,
      bottom: (row['crop_y1'] as num?)?.toDouble() ?? 1,
      structure: data,
    );
  }
}
