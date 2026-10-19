/// Supported GroqCloud models obtained from the official /models endpoint.
class GroqModels {
  static const defaultModel = 'llama-3.3-70b-versatile';
  static final Uri modelsUri = Uri.parse('https://api.groq.com/openai/v1/models');
  static final Uri completionsUri =
      Uri.parse('https://api.groq.com/openai/v1/chat/completions');

  static const recommended = [
    'llama-3.3-70b-versatile',
    'openai/gpt-oss-120b',
    'openai/gpt-oss-20b',
    'llama-3.1-8b-instant',
  ];

  static String normalize(String value) {
    final model = value.trim();
    return model.isEmpty || model.startsWith('grok-') ? defaultModel : model;
  }

  static List<String> availableFromResponse(Map<String, dynamic> payload) {
    final raw = payload['data'];
    if (raw is! List) return [];
    final names = <String>{};
    for (final item in raw) {
      if (item is! Map || item['active'] == false) continue;
      final name = (item['id'] ?? '').toString().trim();
      final lower = name.toLowerCase();
      if (name.isEmpty) continue;
      if (['whisper', 'distil-', 'guard', 'tts', 'audio', 'realtime',
            'speech', 'image', 'video', 'embed', 'vision', 'compound', 'transcri']
          .any(lower.contains)) continue;
      names.add(name);
    }
    return names.toList()..sort(compare);
  }

  static int compare(String a, String b) {
    final ia = recommended.indexOf(a), ib = recommended.indexOf(b);
    if (ia >= 0 && ib < 0) return -1;
    if (ib >= 0 && ia < 0) return 1;
    if (ia >= 0 && ib >= 0) return ia.compareTo(ib);
    return a.compareTo(b);
  }

  static String? fallback(List<String> models, String current) {
    for (final suggested in recommended) {
      if (suggested != current && models.contains(suggested)) return suggested;
    }
    return null;
  }
}
