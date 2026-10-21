import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_paddle_ocr_v5/flutter_paddle_ocr_v5.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import 'ocr_layout.dart';
import 'ocr_photo_preprocessor.dart';

/// Completely offline PP-OCRv5 Cyrillic, with text boxes for safe reading order.
/// The recognition and detection models are shipped in the APK by CI.
class PaddleCardOcr {
  static Future<CardLayoutResult> recognize(Uint8List original) async {
    final scanned = await compute(_scan, original);
    final source = await _localModels();
    final engine = await PaddleOcr.create(
      source: source,
      cpuThreadNum: 4,
      useSpaceChar: true,
    );
    try {
      final results = await engine.recognize(scanned.bytes,
        maxSideLen: 1600, runDetection: true,
        runClassification: false, runRecognition: true);
      final boxes = <CardOcrBox>[];
      for (final item in results) {
        if (item.points.isEmpty || item.text.trim().isEmpty) continue;
        final xs = item.points.map((p) => p.dx);
        final ys = item.points.map((p) => p.dy);
        boxes.add(CardOcrBox(item.text,
            item.confidence.clamp(0.0, 1.0).toDouble(),
            xs.reduce(math.min), ys.reduce(math.min),
            xs.reduce(math.max), ys.reduce(math.max)));
      }
      return CardOcrLayout.parse(boxes, scanned.width.toDouble());
    } finally {
      await engine.dispose();
    }
  }

  static Future<ModelSource> _localModels() async {
    final root = await getApplicationSupportDirectory();
    final dir = Directory(root.path + '/paddle_ocr_v5_cyrillic');
    await dir.create(recursive: true);
    Future<String> unpack(String name, int minimumSize) async {
      final file = File(dir.path + '/' + name);
      if (!await file.exists() || await file.length() < minimumSize) {
        late final ByteData asset;
        try {
          asset = await rootBundle.load('assets/paddle_models/' + name);
        } catch (_) {
          throw StateError('В APK не найдена модель PP-OCRv5: ' + name +
              '. Требуется сборка с включёнными OCR-моделями.');
        }
        final bytes = asset.buffer.asUint8List(
            asset.offsetInBytes, asset.lengthInBytes);
        if (bytes.length < minimumSize) {
          throw StateError('В APK повреждена модель PP-OCRv5: ' + name);
        }
        // Write into a temporary file first; never leave half a model on disk.
        final temp = File(file.path + '.tmp');
        await temp.writeAsBytes(bytes, flush: true);
        if (await file.exists()) await file.delete();
        await temp.rename(file.path);
      }
      return file.path;
    }
    final det = await unpack('det.onnx', 1000000);
    final rec = await unpack('rec.onnx', 1000000);
    final dict = await unpack('dict.txt', 1000);
    return ModelSource.filePaths(det: det, rec: rec, dict: dict);
  }
}

class _ScannedPhoto {
  const _ScannedPhoto(this.bytes, this.width);
  final Uint8List bytes;
  final int width;
}

_ScannedPhoto _scan(Uint8List original) {
  final page = OcrPhotoPreprocessor.decodePage(original);
  // Preserve delicate signs and dots; the ONNX detector handles luminance.
  return _ScannedPhoto(Uint8List.fromList(img.encodePng(page)), page.width);
}
