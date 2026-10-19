/// Reads the xAI /v1/models result, independently of networking.
class GrokModels {
  static const defaultModel = 'grok-4.3';
  // Documented comparable API pricing. Expensive models require a user choice.
  static const samePriceModels = [
    'grok-4.3',
    'grok-4.20-0309-reasoning',
    'grok-4.20-0309-non-reasoning',
  ];

  static String normalize(String raw) {
    final model = raw.trim();
    return model.startsWith('models/') ? model.substring(7) : model;
  }

  static List<String> availableFromResponse(Map<String, dynamic> response) {
    final data = response['data'];
    if (data is! List) return [];
    final models = <String>{};
    for (final entry in data) {
      if (entry is! Map) continue;
      final id = normalize((entry['id'] ?? '').toString());
      if (!id.startsWith('grok-')) continue;
      if (['imagine', 'image', 'video', 'voice', 'audio',
           'realtime', 'multi-agent', 'code'].any(id.contains)) continue;
      final output = entry['output_modalities'];
      if (output is List && output.isNotEmpty && !output.contains('text')) continue;
      models.add(id);
    }
    return models.toList()..sort(compare);
  }

  static int compare(String a, String b) {
    final ia = samePriceModels.indexOf(a);
    final ib = samePriceModels.indexOf(b);
    if (ia >= 0 && ib < 0) return -1;
    if (ib >= 0 && ia < 0) return 1;
    if (ia >= 0 && ib >= 0) return ia.compareTo(ib);
    return b.compareTo(a);
  }

  static String? samePriceFallback(List<String> available, String current) {
    for (final candidate in samePriceModels) {
      if (candidate != current && available.contains(candidate)) return candidate;
    }
    return null;
  }
}
