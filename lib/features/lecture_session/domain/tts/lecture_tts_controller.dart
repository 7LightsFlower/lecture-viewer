import 'package:lecture_common/lecture_common.dart';

import 'package:lecture_viewer_v3/features/lecture_session/domain/tts/tts_soloud_pane_engine.dart';

bool shouldPauseTtsForUserToggle({
  required bool userWantsPlayback,
  required bool isPlaying,
}) => userWantsPlayback || isPlaying;

/// Single-pane TTS orchestration for the lecture viewer session.
final class LectureTtsController {
  LectureTtsController({required void Function(TtsPaneSnapshot) onSnapshot})
      : _engine = TtsSoloudPaneEngine(onSnapshot: onSnapshot);

  final TtsSoloudPaneEngine _engine;

  bool get userWantsPlayback => _engine.userWantsPlayback;

  void enqueue(String url) => _engine.enqueue(url);

  Future<void> playPauseFromUser({required bool isPlaying}) async {
    if (shouldPauseTtsForUserToggle(
      userWantsPlayback: _engine.userWantsPlayback,
      isPlaying: isPlaying,
    )) {
      await _engine.pauseFromUserTap();
    } else {
      await _engine.playFromUserTap();
    }
  }

  void seekEnd(double normalized) => _engine.seekToNormalized(normalized);

  Future<void> clearForLanguageChange({
    required bool preserveUserPlaybackIntent,
  }) =>
      _engine.clearBuffer(
        preserveUserPlaybackIntent: preserveUserPlaybackIntent,
      );

  Future<void> reset() => _engine.clear();

  Future<void> dispose() => _engine.dispose();
}
