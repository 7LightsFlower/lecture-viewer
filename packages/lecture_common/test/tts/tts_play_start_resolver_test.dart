import 'package:flutter_test/flutter_test.dart';
import 'package:lecture_common/tts/domain/tts_play_start_resolver.dart';

void main() {
  TtsPlayStartResult r({
    required double playheadSec,
    required double bufferedSec,
  }) {
    return resolveTtsPlayStart(
      playheadSec: playheadSec,
      bufferedSec: bufferedSec,
    );
  }

  test('tail join when playhead before tailJoinSec', () {
    final result = r(playheadSec: 0, bufferedSec: 10);
    expect(result, isA<TtsPlayStartFrom>());
    expect((result as TtsPlayStartFrom).startSec, closeTo(7, 1e-9));
  });

  test('at or past tail join plays from current playhead (no backward seek)', () {
    final result = r(playheadSec: 8, bufferedSec: 10);
    expect(result, isA<TtsPlayStartFrom>());
    expect((result as TtsPlayStartFrom).startSec, closeTo(8, 1e-9));
  });

  test('duck at buffer end skips until more audio is buffered', () {
    expect(r(playheadSec: 23.525, bufferedSec: 23.525), isA<TtsPlayStartSkip>());
  });

  test('resume after duck plays from playhead when buffer grows (no backward seek)', () {
    final result = r(playheadSec: 23.525, bufferedSec: 25);
    expect(result, isA<TtsPlayStartFrom>());
    expect((result as TtsPlayStartFrom).startSec, closeTo(23.525, 1e-9));
  });

  test('too close to end skips', () {
    expect(r(playheadSec: 9.9, bufferedSec: 10), isA<TtsPlayStartSkip>());
  });

  test('boundary at tailJoinSec plays from playhead', () {
    final result = r(playheadSec: 7, bufferedSec: 10);
    expect(result, isA<TtsPlayStartFrom>());
    expect((result as TtsPlayStartFrom).startSec, closeTo(7, 1e-9));
  });

  test('boundary at endPlayCutoffSec skips', () {
    expect(r(playheadSec: 9.8, bufferedSec: 10), isA<TtsPlayStartSkip>());
  });

  test('short buffer starts at 0', () {
    final result = r(playheadSec: 0, bufferedSec: 2);
    expect(result, isA<TtsPlayStartFrom>());
    expect((result as TtsPlayStartFrom).startSec, closeTo(0, 1e-9));
  });

  test('very short buffer skips', () {
    expect(r(playheadSec: 0, bufferedSec: 0.15), isA<TtsPlayStartSkip>());
  });

  test('empty buffer skips', () {
    expect(r(playheadSec: 0, bufferedSec: 0), isA<TtsPlayStartSkip>());
  });
}
