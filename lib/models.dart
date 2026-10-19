import 'dart:convert';

class BookRecord {
  BookRecord({required this.id, required this.title, required this.path,
    required this.pageCount, this.offset = 0, Map<String, String>? texts})
      : texts = texts ?? {};
  final String id;
  String title;
  final String path;
  final int pageCount;
  int offset;
  final Map<String, String> texts;
  int pdfPage(int printedPage) => printedPage + offset;
  String textAt(int page) => texts[page.toString()] ?? '';
  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'path': path,
    'pageCount': pageCount, 'offset': offset, 'texts': texts};
  factory BookRecord.fromJson(Map<String, dynamic> data) => BookRecord(
    id: data['id'].toString(), title: data['title'].toString(),
    path: data['path'].toString(), pageCount: (data['pageCount'] as num).toInt(),
    offset: (data['offset'] as num?)?.toInt() ?? 0,
    texts: (data['texts'] as Map? ?? {}).map(
      (key, value) => MapEntry(key.toString(), value.toString())));
}

class Exercise {
  const Exercise(this.number, this.text);
  final String number, text;
}

class PracticeTask {
  const PracticeTask(this.question, this.answer);
  final String question, answer;
  Map<String, dynamic> toJson() => {'question': question, 'answer': answer};
  factory PracticeTask.fromJson(Map<String, dynamic> data) =>
    PracticeTask((data['question'] ?? '').toString(), (data['answer'] ?? '').toString());
}

class StudyResult {
  const StudyResult({required this.id, required this.problem, required this.answer,
    required this.notebook, required this.explanation, required this.rule,
    required this.source, required this.createdAt, this.bookId, this.page,
    this.number, this.verified = false, this.warning = '', this.practice = const []});
  final String id, problem, answer, notebook, explanation, rule, source, createdAt;
  final String? bookId, number;
  final int? page;
  final bool verified;
  final String warning;
  final List<PracticeTask> practice;
  Map<String, dynamic> toJson() => {
    'id': id, 'problem': problem, 'answer': answer,
    'notebook': notebook, 'explanation': explanation, 'rule': rule,
    'source': source, 'createdAt': createdAt, 'bookId': bookId,
    'page': page, 'number': number, 'verified': verified, 'warning': warning,
    'practice': practice.map((e) => e.toJson()).toList()};
  factory StudyResult.fromJson(Map<String, dynamic> data) => StudyResult(
    id: data['id'].toString(), problem: (data['problem'] ?? '').toString(),
    answer: (data['answer'] ?? '').toString(), notebook: (data['notebook'] ?? '').toString(),
    explanation: (data['explanation'] ?? '').toString(),
    rule: (data['rule'] ?? '').toString(), source: (data['source'] ?? '').toString(),
    createdAt: (data['createdAt'] ?? '').toString(), bookId: data['bookId']?.toString(),
    page: (data['page'] as num?)?.toInt(), number: data['number']?.toString(),
    verified: data['verified'] == true, warning: (data['warning'] ?? '').toString(),
    practice: ((data['practice'] as List?) ?? []).whereType<Map>().map(
      (x) => PracticeTask.fromJson(Map<String, dynamic>.from(x))).toList());
}

String prettyJson(Object value) => const JsonEncoder.withIndent('  ').convert(value);