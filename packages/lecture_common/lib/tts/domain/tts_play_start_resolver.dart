import 'dart:math';

import 'tts_play_start_debug.dart';

/// Live-tail join offset for explicit TTS play-start (seconds).
const double kTtsTailJoinOffsetSec = 3.0;

/// Minimum remaining buffered audio required to start explicit play (seconds).
const double kTtsEndPlayCutoffOffsetSec = 0.2;

sealed class TtsPlayStartResult {
  const TtsPlayStartResult();
}

final class TtsPlayStartSkip extends TtsPlayStartResult {
  const TtsPlayStartSkip();
}

final class TtsPlayStartFrom extends TtsPlayStartResult {
  const TtsPlayStartFrom(this.startSec);
  final double startSec;
}

/// Resolves where explicit TTS play should start per
/// `docs/superpowers/specs/2026-05-15-tts-play-start-resolver-design.md` §4.
TtsPlayStartResult resolveTtsPlayStart({
  required double playheadSec,
  required double bufferedSec,
  double tailJoinOffsetSec = kTtsTailJoinOffsetSec,
  double endPlayCutoffOffsetSec = kTtsEndPlayCutoffOffsetSec,
}) {
  if (bufferedSec <= 0) {
    ttsPlayStartDebug(
      'skip empty buffer (p=${playheadSec.toStringAsFixed(3)}s '
      'D=${bufferedSec.toStringAsFixed(3)}s)',
    );
    return const TtsPlayStartSkip();
  }

  final tailJoinSec = max(0.0, bufferedSec - tailJoinOffsetSec);
  final endPlayCutoffSec = bufferedSec - endPlayCutoffOffsetSec;

  if (playheadSec >= endPlayCutoffSec) {
    ttsPlayStartDebug(
      'skip too close to end (p=${playheadSec.toStringAsFixed(3)}s '
      '≥ cutoff=${endPlayCutoffSec.toStringAsFixed(3)}s '
      'D=${bufferedSec.toStringAsFixed(3)}s)',
    );
    return const TtsPlayStartSkip();
  }

  // Forward-only: may jump ahead to live tail, never before current playhead.
  final startSec = max(playheadSec, tailJoinSec);
  ttsPlayStartDebug(
    'play from ${startSec.toStringAsFixed(3)}s '
    '(p=${playheadSec.toStringAsFixed(3)}s tailJoin=${tailJoinSec.toStringAsFixed(3)}s '
    'cutoff=${endPlayCutoffSec.toStringAsFixed(3)}s D=${bufferedSec.toStringAsFixed(3)}s)',
  );
  return TtsPlayStartFrom(startSec);
}
