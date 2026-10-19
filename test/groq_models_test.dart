import 'package:flutter_test/flutter_test.dart';
import 'package:domashka/groq_models.dart';

void main() {
  test('Migration of mislabeled Grok model', () {
    expect(GroqModels.normalize('grok-4.3'), GroqModels.defaultModel);
    expect(GroqModels.normalize('openai/gpt-oss-120b'), 'openai/gpt-oss-120b');
  });
  test('Only active text completion models', () {
    final models = GroqModels.availableFromResponse({'data': [
      {'id':'llama-3.3-70b-versatile', 'active':true},
      {'id':'openai/gpt-oss-120b', 'active':true},
      {'id':'whisper-large-v3'}, {'id':'llama-3.1-8b-instant','active':false},
      {'id':'meta-llama/llama-prompt-guard-2-22m'},
    ]});
    expect(models,['llama-3.3-70b-versatile','openai/gpt-oss-120b']);
  });
  test('Fallback chooses known model only', () {
    expect(GroqModels.fallback(['whisper-large-v3'],'bad'),isNull);
    expect(GroqModels.fallback(['openai/gpt-oss-120b'],'llama-3.3-70b-versatile'),
      'openai/gpt-oss-120b');
  });
  test('Official API endpoints', () {
    expect(GroqModels.modelsUri.toString(),'https://api.groq.com/openai/v1/models');
    expect(GroqModels.completionsUri.toString(),
      'https://api.groq.com/openai/v1/chat/completions');
  });
}
