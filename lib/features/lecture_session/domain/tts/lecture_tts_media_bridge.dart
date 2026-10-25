import 'package:audio_service/audio_service.dart';
import 'package:lecture_common/lecture_common.dart';

/// Maps [TtsPaneSnapshot] + session metadata to [audio_service] state.
PlaybackState lectureTtsPlaybackStateFromSnapshot({
  required TtsPaneSnapshot snapshot,
  required bool hasMediaItem,
}) {
  final buffered = Duration(
    milliseconds: (snapshot.bufferedDurationSec * 1000).round(),
  );
  final position = Duration(
    milliseconds: (snapshot.playbackPositionSec * 1000).round(),
  );

  final processingState = _processingState(snapshot, hasMediaItem);

  return PlaybackState(
    controls: [
      if (snapshot.isPlaying) MediaControl.pause else MediaControl.play,
    ],
    systemActions: const {MediaAction.seek},
    androidCompactActionIndices: const [0],
    processingState: processingState,
    playing: snapshot.isPlaying,
    updatePosition: position,
    bufferedPosition: buffered,
    speed: 1.0,
  );
}

AudioProcessingState _processingState(
  TtsPaneSnapshot snapshot,
  bool hasMediaItem,
) {
  if (!hasMediaItem) return AudioProcessingState.idle;
  if (snapshot.bufferedDurationSec <= 0) return AudioProcessingState.idle;
  if (snapshot.pendingDownloadCount > 0 && !snapshot.isPlaying) {
    return AudioProcessingState.loading;
  }
  return AudioProcessingState.ready;
}

MediaItem lectureTtsMediaItem({
  required String sessionId,
  required String selectedLanguage,
  required TtsPaneSnapshot snapshot,
}) {
  return MediaItem(
    id: sessionId,
    title: 'Lecture translation',
    album: selectedLanguage.isEmpty ? 'Translation' : selectedLanguage,
    duration: Duration(
      milliseconds: (snapshot.bufferedDurationSec * 1000).round(),
    ),
  );
}
