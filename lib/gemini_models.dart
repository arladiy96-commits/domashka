/// Lightweight Gemini model catalog selection shared between UI and AI.
class GeminiModels {
  static const defaultModel = 'gemini-3.8-flash';

  static String normalize(String value) {
    final result = value.trim();
    return result.startsWith('models/') ? result.substring(7) : result;
  }

  static List<String> availableFromResponse(Map<String, dynamic> response) {
    final items = response['models'];
    if (items is! List) return [];
    final names = <String>{};
    for (final item in items) {
      if (item is! Map) continue;
      final methods = item['supportedGenerationMethods'] ?? item['supportedActions'];
      if (methods is! List || !methods.contains('generateContent')) continue;
      final name = normalize((item['name'] ?? '').toString());
      if (!name.startsWith('gemini-') || !name.contains('flash')) continue;
      if (name.contains('image') || name.contains('tts') ||
          name.contains('live') || name.contains('audio') ||
          name.contains('preview') || name.contains('embedding') ||
          name.contains('experimental')) continue;
      names.add(name);
    }
    return names.toList()..sort(compare);
  }

  static int compare(String a, String b) {
    if (a == defaultModel && b != defaultModel) return -1;
    if (b == defaultModel && a != defaultModel) return 1;
    return b.compareTo(a);
  }
}
