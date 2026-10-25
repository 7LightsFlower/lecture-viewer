import 'package:audio_service/audio_service.dart';
import 'package:lecture_common/lecture_common.dart';

import 'package:lecture_viewer_v3/features/lecture_session/domain/tts/lecture_tts_media_bridge.dart';

/// Remote play / pause / seek callbacks registered by [LectureSessionNotifier].
abstract interface class LectureTtsRemoteDelegate {
  Future<void> onRemotePlay();
  Future<void> onRemotePause();
  Future<void> onRemoteSeek(Duration position);
}

/// Bridges system media controls to lecture TTS playback.
class LectureTtsAudioHandler extends BaseAudioHandler with SeekHandler {
  LectureTtsRemoteDelegate? _delegate;
  bool _hasMediaItem = false;

  void attach(LectureTtsRemoteDelegate delegate) {
    _delegate = delegate;
  }

  void detach() {
    _delegate = null;
  }

  void syncFromSnapshot({
    required String sessionId,
    required String selectedLanguage,
    required TtsPaneSnapshot snapshot,
  }) {
    if (snapshot.isPlaying) {
      _hasMediaItem = true;
    }

    if (!_hasMediaItem) {
      return;
    }

    mediaItem.add(
      lectureTtsMediaItem(
        sessionId: sessionId,
        selectedLanguage: selectedLanguage,
        snapshot: snapshot,
      ),
    );

    playbackState.add(
      lectureTtsPlaybackStateFromSnapshot(
        snapshot: snapshot,
        hasMediaItem: _hasMediaItem,
      ),
    );
  }

  Future<void> clearMediaSession() async {
    _hasMediaItem = false;
    mediaItem.add(null);
    playbackState.add(
      playbackState.value.copyWith(
        processingState: AudioProcessingState.idle,
        playing: false,
        controls: const [],
      ),
    );
    // Do not call [stop]: its override routes to [onRemotePause] and can clear
    // engine playback intent during language change while SoLoud is already idle.
  }

  @override
  Future<void> play() => _delegate?.onRemotePlay() ?? Future.value();

  @override
  Future<void> pause() => _delegate?.onRemotePause() ?? Future.value();

  @override
  Future<void> seek(Duration position) =>
      _delegate?.onRemoteSeek(position) ?? Future.value();

  @override
  Future<void> stop() async {
    await _delegate?.onRemotePause();
    await super.stop();
  }
}
