import 'package:flutter_test/flutter_test.dart';
import 'package:lecture_viewer_v3/features/lecture_session/domain/tts/tts_language_change.dart';

void main() {
  group('preserveTtsPlaybackOnLanguageChange', () {
    test('true when user wants playback', () {
      expect(
        preserveTtsPlaybackOnLanguageChange(userWantsPlayback: true),
        isTrue,
      );
    });

    test('false when user paused (no playback intent)', () {
      expect(
        preserveTtsPlaybackOnLanguageChange(userWantsPlayback: false),
        isFalse,
      );
    });
  });
}
