import 'package:flutter_test/flutter_test.dart';
import 'package:domashka/gemini_models.dart';

void main() {
  test('Old model prefix is normalized', () {
    expect(GeminiModels.normalize(' models/gemini-3.8-flash '), 'gemini-3.8-flash');
  });

  test('Model selection ignores tools incompatible with image reading', () {
    final result = GeminiModels.availableFromResponse({
      'models': [
        {'name': 'models/gemini-3.7-flash',
          'supportedGenerationMethods': ['generateContent']},
        {'name': 'models/gemini-3.8-flash',
          'supportedGenerationMethods': ['generateContent']},
        {'name': 'models/gemini-3.8-flash-tts',
          'supportedGenerationMethods': ['generateContent']},
        {'name': 'models/gemini-4-argon',
          'supportedGenerationMethods': ['generateContent']},
        {'name': 'models/gemini-3.9-flash-preview',
          'supportedGenerationMethods': ['generateContent']},
        {'name': 'models/gemini-3.6-flash',
          'supportedGenerationMethods': ['embedContent']},
      ],
    });
    expect(result, ['gemini-3.8-flash', 'gemini-3.7-flash']);
  });
}
