import 'dart:math' as math;

import 'models.dart';
import 'offline_card_ocr.dart';

/// Text polygons from an OCR detector, in original image pixel coordinates.
/// The layout stage never invents, substitutes or corrects recognized tokens.
class CardOcrBox {
  const CardOcrBox(this.text, this.confidence, this.left, this.top,
      this.right, this.bottom);
  final String text;
  final double confidence, left, top, right, bottom;
  double get midX => (left + right) / 2;
  double get midY => (top + bottom) / 2;
  double get height => math.max(1, bottom - top);
}

class CardLayoutResult {
  const CardLayoutResult(this.exercises, this.twoColumns, this.lowConfidence);
  final List<Exercise> exercises;
  final bool twoColumns;
  final bool lowConfidence;
}

class CardOcrLayout {
  /// Detect columns from physical text polygons, NOT from OCR's guessed text.
  /// Never split the photo at an arbitrary halfway point.
  static CardLayoutResult parse(List<CardOcrBox> detected, double pageWidth) {
    final boxes = detected.where((b) =>
        b.text.trim().isNotEmpty && b.right > b.left && b.bottom > b.top)
        .toList();
    if (boxes.isEmpty) return const CardLayoutResult([], false, true);
    final confidence = boxes.any((b) => b.confidence < .76);
    final lines = _lines(boxes);
    final cutCandidates = <double>[];
    for (final line in lines) {
      if (line.length < 2) continue;
      final ordered = line.toList()..sort((a, b) => a.left.compareTo(b.left));
      final sortedHeights = line.map((b) => b.height).toList()..sort();
      final height = sortedHeights[sortedHeights.length ~/ 2];
      for (var i = 0; i < ordered.length - 1; i++) {
        final left = ordered[i], right = ordered[i + 1];
        final gap = right.left - left.right;
        // Table cells and word spacing must not masquerade as columns.
        if (gap > math.max(pageWidth * .12, height * 4) &&
            left.midX < pageWidth * .46 &&
            right.midX > pageWidth * .54 &&
            left.right < pageWidth * .61 &&
            right.left > pageWidth * .39) {
          cutCandidates.add((left.right + right.left) / 2);
        }
      }
    }
    cutCandidates.sort();
    final isTwoColumn = cutCandidates.length >= 2 &&
        cutCandidates.last - cutCandidates.first < pageWidth * .15;
    if (!isTwoColumn) {
      return CardLayoutResult(OfflineCardParser.split(_text(boxes)),
          false, confidence);
    }

    final cut = cutCandidates[cutCandidates.length ~/ 2];
    final left = <CardOcrBox>[], right = <CardOcrBox>[], headings = <CardOcrBox>[];
    for (final box in boxes) {
      // Full-width titles/instructions are preserved rather than cropped.
      if (box.left < cut && box.right > cut &&
          box.right - box.left > pageWidth * .48) {
        headings.add(box);
      } else if (box.midX < cut) {
        left.add(box);
      } else {
        right.add(box);
      }
    }
    if (left.isEmpty || right.isEmpty) {
      return CardLayoutResult(OfflineCardParser.split(_text(boxes)),
          false, confidence);
    }
    final exercises = <Exercise>[];
    if (headings.isNotEmpty) {
      exercises.add(Exercise('инструкция', _text(headings)));
    }
    void addColumn(String title, List<CardOcrBox> column) {
      final text = _text(column);
      if (text.isEmpty) return;
      final parts = OfflineCardParser.split(text);
      if (parts.length == 1 && parts.first.number == 'карточка') {
        exercises.add(Exercise(title, text));
      } else {
        // Keep subtask boundaries within each detected column.
        for (final task in parts) {
          exercises.add(Exercise(title + ' · ' + task.number, task.text));
        }
      }
    }
    addColumn('левый столбец', left);
    addColumn('правый столбец', right);
    return CardLayoutResult(exercises, true, confidence);
  }

  static List<List<CardOcrBox>> _lines(List<CardOcrBox> boxes) {
    final sorted = boxes.toList()..sort((a, b) {
      final y = a.midY.compareTo(b.midY);
      return y == 0 ? a.left.compareTo(b.left) : y;
    });
    final lines = <List<CardOcrBox>>[];
    for (final box in sorted) {
      List<CardOcrBox>? target;
      for (final line in lines.reversed) {
        final mid = line.map((b) => b.midY).reduce((a,b) => a + b) / line.length;
        final typical = line.map((b) => b.height).reduce(math.max);
        if ((box.midY - mid).abs() < math.min(box.height, typical) * .52) {
          target = line;
          break;
        }
        if (mid < box.midY - math.max(typical, box.height) * 2) break;
      }
      (target ?? (lines..add(<CardOcrBox>[])).last).add(box);
    }
    return lines;
  }

  static String _text(List<CardOcrBox> boxes) {
    return _lines(boxes).map((line) {
      line.sort((a, b) => a.left.compareTo(b.left));
      return line.map((box) => box.text.trim()).join('   ');
    }).where((line) => line.isNotEmpty).join('\n');
  }
}
