import 'package:flutter/material.dart';

import 'models.dart';
import 'offline_catalog.dart';

/// A reviewed solution stored in the local SQLite catalog: no API call.
extension PreparedExercise on OfflineExercise {
  Map<String, dynamic>? get preparedSolution {
    if (!firstPassReviewed) return null;
    final raw = structure?['ready_solution'];
    if (raw is! Map) return null;
    final data = Map<String, dynamic>.from(raw);
    if ((data['answer'] ?? '').toString().trim().isEmpty ||
        (data['notebook'] ?? '').toString().trim().isEmpty ||
        (data['explanation'] ?? '').toString().trim().isEmpty) return null;
    return data;
  }

  StudyResult? toPreparedResult(BookRecord book, int page) {
    final ready = preparedSolution;
    if (ready == null) return null;
    final practice = (ready['practice'] as List? ?? []).whereType<Map>()
        .map((item) => PracticeTask((item['question'] ?? '').toString(),
            (item['answer'] ?? '').toString())).toList();
    final drawings = (ready['diagram_blocks'] as List? ?? [])
        .whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
    return StudyResult(
      id: 'prepared-' + book.id + '-' + page.toString() + '-' + number +
          '-' + DateTime.now().microsecondsSinceEpoch.toString(),
      problem: sourceStatement.isEmpty ? ocrText : sourceStatement,
      answer: (ready['answer'] ?? '').toString(),
      notebook: (ready['notebook'] ?? '').toString(),
      explanation: (ready['explanation'] ?? '').toString(),
      rule: (ready['rule'] ?? '').toString(),
      source: 'Готовая база: ' + book.title,
      createdAt: DateTime.now().toIso8601String(),
      bookId: book.id, page: page, number: number,
      verified: ready['math_verified'] == true,
      practice: practice, solutionBlocks: drawings,
    );
  }
}

/// Responsive diagrams: number lines, base-ten squares and full tables.
class PreparedSolutionView extends StatelessWidget {
  const PreparedSolutionView({super.key, required this.blocks});
  final List<Map<String, dynamic>> blocks;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final block in blocks) ...[
        _block(block),
        const SizedBox(height: 10),
      ],
    ],
  );

  Widget _block(Map<String, dynamic> block) {
    final type = (block['type'] ?? '').toString();
    Widget? child;
    if (type == 'base_ten') child = _baseTen(block);
    if (type == 'number_sequence') child = _sequence(block['values']);
    if (type == 'expressions') child = _sequence(block['items']);
    if (type == 'table') child = _table(block);
    if (child == null) return const SizedBox.shrink();
    final label = (block['label'] ?? block['title'] ?? '').toString();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xffeff6ff),
          borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (label.isNotEmpty) ...[
          Text(label, style: const TextStyle(fontWeight: FontWeight.w800,
              color: Color(0xff234776))),
          const SizedBox(height: 9),
        ],
        child,
      ]),
    );
  }

  Widget _square(Color color, double size) => Container(
    width: size, height: size,
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
  );

  Widget _baseTen(Map<String, dynamic> data) {
    final tens = ((data['tens'] as num?)?.toInt() ?? 0).clamp(0, 10);
    final ones = ((data['ones'] as num?)?.toInt() ?? 0).clamp(0, 9);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (var i = 0; i < tens; i++)
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xff55ada1)),
              borderRadius: BorderRadius.circular(5)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              for (var n = 0; n < 10; n++) ...[
                _square(const Color(0xff2fb4a1), 10),
                if (n < 9) const SizedBox(width: 2),
              ],
            ]),
          ),
      ]),
      if (ones > 0) ...[
        const SizedBox(height: 8),
        Wrap(spacing: 5, runSpacing: 5, children: [
          for (var i = 0; i < ones; i++) _square(const Color(0xffe7a344), 14),
        ]),
      ],
      const SizedBox(height: 7),
      Text(tens.toString() + ' дес. + ' + ones.toString() + ' ед. = ' +
          (tens * 10 + ones).toString(),
          style: const TextStyle(fontWeight: FontWeight.w800,
              color: Color(0xff234776))),
    ]);
  }

  Widget _sequence(Object? values) {
    final items = (values as List? ?? []).map((item) => item.toString()).toList();
    return Wrap(spacing: 5, runSpacing: 7, crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(color: Colors.white,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: const Color(0xffb8d3ed))),
            child: Text(items[i], style: const TextStyle(
              fontWeight: FontWeight.w700, color: Color(0xff244b77))),
          ),
          if (i < items.length - 1)
            const Text('→', style: TextStyle(color: Color(0xff5887b9))),
        ],
      ],
    );
  }

  Widget _table(Map<String, dynamic> block) {
    final columns = (block['columns'] as List? ?? [])
        .map((e) => e.toString()).toList();
    if (columns.isEmpty) return const SizedBox.shrink();
    final rows = (block['rows'] as List? ?? []).whereType<List>().toList();
    const width = 136.0;
    Widget cell(String value, bool heading) => Container(
      padding: const EdgeInsets.all(8),
      constraints: const BoxConstraints(minHeight: 38),
      alignment: Alignment.center,
      color: heading ? const Color(0xffd7e9fb) : Colors.white,
      child: Text(value, textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12,
          fontWeight: heading ? FontWeight.w800 : FontWeight.w500,
          color: const Color(0xff204468))),
    );
    return SingleChildScrollView(scrollDirection: Axis.horizontal,
      child: SizedBox(width: width * columns.length,
        child: Table(
          defaultColumnWidth: const FixedColumnWidth(width),
          border: TableBorder.all(color: const Color(0xffbbd1e7)),
          children: [
            TableRow(children: [for (final c in columns) cell(c, true)]),
            for (final row in rows) TableRow(children: [
              for (var i = 0; i < columns.length; i++)
                cell(i < row.length ? row[i].toString() : '', false),
            ]),
          ],
        ),
      ),
    );
  }
}
