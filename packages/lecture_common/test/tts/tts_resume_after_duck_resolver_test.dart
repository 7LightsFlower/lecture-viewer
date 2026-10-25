import 'package:flutter_test/flutter_test.dart';
import 'package:lecture_common/tts/domain/tts_resume_after_duck_resolver.dart';

void main() {
  TtsResumeAfterDuckResult r({
    required double playheadSec,
    required double bufferedSec,
  }) {
    return resolveTtsResumeAfterDuck(
      playheadSec: playheadSec,
      bufferedSec: bufferedSec,
    );
  }

  test('empty buffer skips', () {
    expect(r(playheadSec: 0, bufferedSec: 0), isA<TtsResumeAfterDuckSkip>());
  });

  test('mid-buffer resumes from playhead not tail', () {
    final result = r(playheadSec: 5, bufferedSec: 30);
    expect(result, isA<TtsResumeAfterDuckFromPlayhead>());
    expect(
      (result as TtsResumeAfterDuckFromPlayhead).startSec,
      closeTo(5, 1e-9),
    );
  });

  test('at buffer end skips until more audio', () {
    expect(
      r(playheadSec: 23.525, bufferedSec: 23.525),
      isA<TtsResumeAfterDuckSkip>(),
    );
  });

  test('buffer grew after duck at tail resumes from playhead', () {
    final result = r(playheadSec: 23.525, bufferedSec: 25);
    expect(result, isA<TtsResumeAfterDuckFromPlayhead>());
    expect(
      (result as TtsResumeAfterDuckFromPlayhead).startSec,
      closeTo(23.525, 1e-9),
    );
  });

  test('too close to end skips', () {
    expect(r(playheadSec: 9.9, bufferedSec: 10), isA<TtsResumeAfterDuckSkip>());
  });
}
