import 'package:flutter_test/flutter_test.dart';
import 'package:domashka/grok_models.dart';

void main() {
  test('Normalize xAI model IDs', () {
    expect(GrokModels.normalize(' models/grok-4.3 '), 'grok-4.3');
  });
  test('Only chat-capable Grok models are shown', () {
    final models = GrokModels.availableFromResponse({'data': [
      {'id':'grok-4.7','output_modalities':['text']},
      {'id':'grok-4.20-0309-reasoning'},
      {'id':'grok-4.3'},
      {'id':'grok-imagine-image'},
      {'id':'grok-voice-transcribe-2.0'},
      {'id':'grok-4.20-multi-agent-0309'},
      {'id':'grok-4.7'},
    ]});
    expect(models, ['grok-4.3','grok-4.20-0309-reasoning','grok-4.7']);
  });
  test('Do not silently upgrade to a costlier model', () {
    expect(GrokModels.samePriceFallback(['grok-4.7'],'grok-4.3'), isNull);
    expect(GrokModels.samePriceFallback(
      ['grok-4.7','grok-4.20-0309-reasoning'], 'grok-4.3'),
      'grok-4.20-0309-reasoning');
  });
}
