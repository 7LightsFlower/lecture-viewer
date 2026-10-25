import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lecture_common/lecture_common.dart';
import 'package:lecture_viewer_v3/features/lecture_session/domain/tts/lecture_tts_media_bridge.dart';

void main() {
  test('playback state reflects playing snapshot', () {
    const snap = TtsPaneSnapshot(
      bufferedDurationSec: 60,
      playbackPositionSec: 15,
      isPlaying: true,
    );
    final state = lectureTtsPlaybackStateFromSnapshot(
      snapshot: snap,
      hasMediaItem: true,
    );
    expect(state.playing, isTrue);
    expect(state.controls, [MediaControl.pause]);
    expect(state.updatePosition, const Duration(seconds: 15));
    expect(state.bufferedPosition, const Duration(seconds: 60));
    expect(state.processingState, AudioProcessingState.ready);
  });

  test('media item uses session id and language', () {
    const snap = TtsPaneSnapshot(bufferedDurationSec: 90);
    final item = lectureTtsMediaItem(
      sessionId: 'sess-1',
      selectedLanguage: 'en',
      snapshot: snap,
    );
    expect(item.id, 'sess-1');
    expect(item.album, 'en');
    expect(item.duration, const Duration(seconds: 90));
  });
}
