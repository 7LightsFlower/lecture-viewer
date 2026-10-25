import 'package:flutter_test/flutter_test.dart';
import 'package:lecture_viewer_v3/features/lecture_session/domain/tts/lecture_tts_language.dart';
import 'package:lecture_viewer_v3/features/lecture_session/domain/tts/tts_collapsed_slider_gate.dart';

void main() {
  group('shouldClearTtsCollapsedSliderOnLanguageChange', () {
    test('clears for Transcript', () {
      expect(
        shouldClearTtsCollapsedSliderOnLanguageChange(
          TtsVoiceAvailability.transcriptMode,
        ),
        isTrue,
      );
    });

    test('clears for unsupported language', () {
      expect(
        shouldClearTtsCollapsedSliderOnLanguageChange(
          TtsVoiceAvailability.languageUnsupported,
        ),
        isTrue,
      );
    });

    test('preserves for available TTS language', () {
      expect(
        shouldClearTtsCollapsedSliderOnLanguageChange(
          TtsVoiceAvailability.available,
        ),
        isFalse,
      );
    });
  });
}
