import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:domashka/models.dart';
import 'package:domashka/offline_catalog.dart';
import 'package:domashka/prepared_solution.dart';

void main() {
  final book = BookRecord(id: 'pilot-book', title: 'Учебник',
    path: '/tmp/catalog.sqlite', pageCount: 10,
    offlineDirectory: '/tmp/offline');

  OfflineExercise exerciseWithStatus(String status) => OfflineExercise.fromRow({
    'number': '2', 'text_ocr': 'OCR',
    'crop_x0': 0, 'crop_y0': 0, 'crop_x1': 1, 'crop_y1': 1,
    'structure_json': jsonEncode({
      'review_status': status, 'statement': '10 + 2',
      'ready_solution': {
        'answer': '12', 'notebook': '10 + 2 = 12',
        'explanation': 'Один десяток и две единицы.',
        'rule': '10 единиц = 1 десяток.',
        'math_verified': true,
        'practice': [{'question': '10 + 3', 'answer': '13'}],
        'diagram_blocks': [{'type': 'base_ten', 'tens': 1, 'ones': 2}],
      },
    }),
  });

  test('prepared solution is available without an AI key', () {
    final exercise = exerciseWithStatus('first_pass_reviewed');
    final result = exercise.toPreparedResult(book, 4);
    expect(result, isNotNull);
    expect(result!.answer, '12');
    expect(result.notebook, '10 + 2 = 12');
    expect(result.verified, isTrue);
    expect(result.practice.single.answer, '13');
    expect(result.solutionBlocks.single['ones'], 2);
    final restored = StudyResult.fromJson(result.toJson());
    expect(restored.solutionBlocks.single['tens'], 1);
  });

  test('unreviewed OCR cannot expose a precomputed solution', () {
    final exercise = exerciseWithStatus('ocr_unverified');
    expect(exercise.preparedSolution, isNull);
    expect(exercise.toPreparedResult(book, 4), isNull);
  });

  test('incomplete precomputed solutions fall back to the regular path', () {
    final exercise = OfflineExercise.fromRow({
      'number': '2', 'text_ocr': 'OCR',
      'structure_json': jsonEncode({
        'review_status': 'first_pass_reviewed',
        'statement': '10 + 2',
        'ready_solution': {'answer': '12', 'notebook': ''},
      }),
    });
    expect(exercise.preparedSolution, isNull);
  });
}
