import 'tts_play_start_resolver.dart';

sealed class TtsResumeAfterDuckResult {
  const TtsResumeAfterDuckResult();
}

final class TtsResumeAfterDuckSkip extends TtsResumeAfterDuckResult {
  const TtsResumeAfterDuckSkip();
}

final class TtsResumeAfterDuckFromPlayhead extends TtsResumeAfterDuckResult {
  const TtsResumeAfterDuckFromPlayhead(this.startSec);
  final double startSec;
}

final class TtsResumeAfterDuckTailJoin extends TtsResumeAfterDuckResult {
  const TtsResumeAfterDuckTailJoin(this.playStart);
  final TtsPlayStartResult playStart;
}

/// Where auto-TTS should resume after duck (playhead-first per spec §5.4).
TtsResumeAfterDuckResult resolveTtsResumeAfterDuck({
  required double playheadSec,
  required double bufferedSec,
  double endPlayCutoffOffsetSec = kTtsEndPlayCutoffOffsetSec,
}) {
  if (bufferedSec <= 0) return const TtsResumeAfterDuckSkip();

  final endPlayCutoffSec = bufferedSec - endPlayCutoffOffsetSec;
  if (playheadSec >= endPlayCutoffSec) {
    final tail = resolveTtsPlayStart(
      playheadSec: playheadSec,
      bufferedSec: bufferedSec,
    );
    return switch (tail) {
      TtsPlayStartSkip() => const TtsResumeAfterDuckSkip(),
      TtsPlayStartFrom(:final startSec) =>
        TtsResumeAfterDuckTailJoin(TtsPlayStartFrom(startSec)),
    };
  }

  return TtsResumeAfterDuckFromPlayhead(playheadSec);
}
