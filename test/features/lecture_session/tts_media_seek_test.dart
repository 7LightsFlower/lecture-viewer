import 'package:flutter_test/flutter_test.dart';
import 'package:lecture_viewer_v3/features/lecture_session/domain/tts/tts_media_seek.dart';

void main() {
  test('maps seek position to normalized value', () {
    expect(
      ttsNormalizedSeekFromDuration(
        position: const Duration(seconds: 30),
        bufferedDurationSec: 120,
      ),
      0.25,
    );
  });

  test('clamps normalized seek to 0..1', () {
    expect(
      ttsNormalizedSeekFromDuration(
        position: const Duration(seconds: 200),
        bufferedDurationSec: 100,
      ),
      1.0,
    );
    expect(
      ttsNormalizedSeekFromDuration(
        position: Duration.zero,
        bufferedDurationSec: 0,
      ),
      0.0,
    );
  });
}
