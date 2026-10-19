import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';
import 'models.dart';
import 'gemini_models.dart';
import 'groq_models.dart';

class AppStore extends ChangeNotifier {
  final _secure = const FlutterSecureStorage();
  final books = <BookRecord>[];
  final history = <StudyResult>[];
  String geminiKey = '', groqKey = '';
  String geminiModel = GeminiModels.defaultModel, groqModel = GroqModels.defaultModel;
  bool checkWithGemini = true, busy = false;
  String activity = '';
  double importProgress = 0;
  Directory? _root;

  Future<void> init() async {
    _root = await getApplicationDocumentsDirectory();
    var migratedModel = false;
    final file = File('${_root!.path}/domashka.json');
    if (await file.exists()) {
      try {
        final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        books.addAll(((data['books'] as List?) ?? []).whereType<Map>()
            .map((v) => BookRecord.fromJson(Map<String, dynamic>.from(v))));
        books.removeWhere((b) => !File(b.path).existsSync());
        history.addAll(((data['history'] as List?) ?? []).whereType<Map>()
            .map((v) => StudyResult.fromJson(Map<String, dynamic>.from(v))));
        geminiModel = GeminiModels.normalize((data['geminiModel'] ?? geminiModel).toString());
        if (geminiModel == 'gemini-2.5-flash' || geminiModel.isEmpty) {
          geminiModel = GeminiModels.defaultModel;
          migratedModel = true;
        }
        groqModel = GroqModels.normalize((data['groqModel'] ?? data['grokModel'] ?? groqModel).toString());
        checkWithGemini = data['checkWithGemini'] != false;
      } catch (e) { debugPrint('Database load: $e'); }
    }
    try {
      geminiKey = await _secure.read(key: 'gemini_key') ?? '';
      groqKey = await _secure.read(key: 'groq_key') ?? '';
      if (groqKey.isEmpty) {
        // Migrate the Groq key placed in the mislabeled Grok field.
        final legacyKey = await _secure.read(key: 'grok_key') ?? '';
        if (legacyKey.trim().startsWith('gsk_')) {
          groqKey = legacyKey.trim();
          await _secure.write(key: 'groq_key', value: groqKey);
        }
      }
    } catch (e) { debugPrint('Secure storage: $e'); }
    if (migratedModel) await save();
    notifyListeners();
  }

  Future<void> save() async {
    if (_root == null) return;
    final json = const JsonEncoder.withIndent('  ').convert({
      'books': books.map((e) => e.toJson()).toList(),
      'history': history.map((e) => e.toJson()).toList(),
      'geminiModel': geminiModel, 'groqModel': groqModel,
      'checkWithGemini': checkWithGemini,
    });
    final file = File('${_root!.path}/domashka.json');
    final temp = File('${_root!.path}/domashka.tmp');
    await temp.writeAsString(json);
    if (await file.exists()) await file.delete();
    await temp.rename(file.path);
    notifyListeners();
  }

  Future<void> updateSettings(String gemini, String groq, String gm, String xm, bool verify) async {
    geminiKey = gemini.trim(); groqKey = groq.trim();
    geminiModel = GeminiModels.normalize(gm.isEmpty ? GeminiModels.defaultModel : gm); groqModel = GroqModels.normalize(xm.trim().isEmpty ? GroqModels.defaultModel : xm.trim()); checkWithGemini = verify;
    await _secure.write(key: 'gemini_key', value: geminiKey);
    await _secure.write(key: 'groq_key', value: groqKey);
    await save();
  }

  Future<BookRecord?> importBook() async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom, allowedExtensions: ['pdf']);
    if (picked.isEmpty) return null;
    final source = picked.first.path;
    if (source == null) throw StateError('Не удалось прочитать выбранный файл.');
    busy = true; importProgress = 0; activity = 'Читаем учебник'; notifyListeners();
    PdfDocument? doc;
    File? target;
    try {
      final folder = Directory('${_root!.path}/books');
      await folder.create(recursive: true);
      final id = DateTime.now().microsecondsSinceEpoch.toString();
      target = await File(source).copy('${folder.path}/$id.pdf');
      doc = await PdfDocument.openFile(target.path);
      final book = BookRecord(id: id,
        title: picked.first.name.replaceFirst(RegExp(r'\.pdf$', caseSensitive: false), ''),
        path: target.path, pageCount: doc.pages.length);
      for (var i = 0; i < doc.pages.length; i++) {
        try {
          final text = await doc.pages[i].loadText();
          if (text != null && text.fullText.trim().isNotEmpty) {
            book.texts['${i + 1}'] = text.fullText.trim();
          }
        } catch (e) { debugPrint('Page extraction $i: $e'); }
        importProgress = (i + 1) / doc.pages.length;
        if (i % 3 == 0 || i == doc.pages.length - 1) notifyListeners();
      }
      books.insert(0, book); await save(); return book;
    } catch (_) {
      if (target != null && await target.exists()) await target.delete();
      rethrow;
    } finally {
      await doc?.dispose();
      busy = false; activity = ''; importProgress = 0; notifyListeners();
    }
  }

  Future<void> deleteBook(BookRecord book) async {
    books.remove(book); await save();
    if (await File(book.path).exists()) await File(book.path).delete();
  }

  Future<void> remember(StudyResult result) async {
    history.insert(0, result);
    if (history.length > 250) history.removeRange(250, history.length);
    await save();
  }
}