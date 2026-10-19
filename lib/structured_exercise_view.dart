import 'package:flutter/material.dart';
import 'offline_catalog.dart';

/// Visual rendering of the textbook's typed cells, exercises and diagrams.
/// This never sends a request to Gemini/Groq; all content is local SQLite.
class StructuredExerciseView extends StatelessWidget {
  const StructuredExerciseView({super.key, required this.exercise});
  final OfflineExercise exercise;

  @override
  Widget build(BuildContext context) {
    if (!exercise.firstPassReviewed || exercise.blocks.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final block in exercise.blocks) ...[
        _renderBlock(context, block),
        const SizedBox(height: 12),
      ],
    ]);
  }

  Widget _renderBlock(BuildContext context, Map<String, dynamic> block) {
    final kind = (block['type'] ?? '').toString();
    if (kind == 'table') return _buildTable(block);
    if (kind == 'expressions') return _buildExpressions(block);
    if (kind == 'figure') {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xffeef5ff),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.account_tree_outlined, size: 19, color: Color(0xff246af3)),
            SizedBox(width: 8),
            Expanded(child: Text('Рисунок или схема из учебника',
                style: TextStyle(fontWeight: FontWeight.w700))),
          ]),
          const SizedBox(height: 8),
          Text((block['description'] ?? '').toString(),
              style: const TextStyle(fontSize: 14, height: 1.5)),
          if (block['requires_math_interpretation'] == true) ...[
            const SizedBox(height: 8),
            const Text('Неоднозначные элементы схемы требуют сверки '
                'с оригиналом выше.', style: TextStyle(
                color: Color(0xff9b5c11), fontSize: 12)),
          ],
        ]),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildTable(Map<String, dynamic> block) {
    final headers = (block['columns'] as List? ?? [])
        .map((value) => value.toString()).toList();
    if (headers.isEmpty) return const SizedBox.shrink();
    final rows = (block['rows'] as List? ?? [])
        .whereType<List>().toList();
    const colWidth = 148.0;
    final width = colWidth * headers.length;
    Widget cell(String text, {bool header = false}) => Container(
      constraints: const BoxConstraints(minHeight: 42),
      padding: const EdgeInsets.all(8),
      alignment: Alignment.center,
      color: header ? const Color(0xffe9f3ff) : Colors.white,
      child: Text(text.isEmpty ? '□' : text, textAlign: TextAlign.center,
        style: TextStyle(fontSize: 13,
          fontWeight: header ? FontWeight.w700 : FontWeight.w500,
          color: const Color(0xff142b50))),
    );
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if ((block['title'] ?? '').toString().isNotEmpty) ...[
        Text((block['title'] ?? '').toString(), style: const TextStyle(
            fontSize: 15, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
      ],
      ClipRRect(borderRadius: BorderRadius.circular(10),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(width: width,
            child: Table(
              defaultColumnWidth: const FixedColumnWidth(colWidth),
              border: TableBorder.all(
                color: const Color(0xffbbcade), width: 1.0),
              children: [
                TableRow(children: [
                  for (final head in headers) cell(head, header: true),
                ]),
                for (final row in rows)
                  TableRow(children: [
                    for (var index = 0; index < headers.length; index++)
                      cell(index < row.length ? row[index].toString() : ''),
                  ]),
              ],
            ),
          ),
        ),
      ),
    ]);
  }

  Widget _buildExpressions(Map<String, dynamic> block) {
    final items = (block['items'] as List? ?? [])
        .map((value) => value.toString()).toList();
    if (items.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 8, runSpacing: 8, children: [
      for (final expression in items)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(color: const Color(0xfff2f6fe),
            border: Border.all(color: const Color(0xffd5e2fb)),
            borderRadius: BorderRadius.circular(10)),
          child: Text(expression, style: const TextStyle(
              fontWeight: FontWeight.w700, color: Color(0xff142b50))),
        ),
    ]);
  }
}
