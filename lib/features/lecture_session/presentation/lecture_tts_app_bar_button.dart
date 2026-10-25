import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lecture_viewer_v3/features/lecture_session/domain/tts/lecture_tts_language.dart';
import 'package:lecture_viewer_v3/features/lecture_session/presentation/lecture_session_scope.dart';
import 'package:lecture_viewer_v3/features/lecture_session/presentation/providers/lecture_session_notifier.dart';

const _ttsWaitingForAudioMessage =
    'Waiting for audio. Play will be available once translation audio is buffered.';

String lectureTtsPlayBlockedMessage({
  required TtsVoiceAvailability voiceAvailability,
}) {
  if (voiceAvailability != TtsVoiceAvailability.available) {
    return ttsVoiceUnavailableMessage(voiceAvailability);
  }
  return _ttsWaitingForAudioMessage;
}

void showLectureTtsPlayBlockedSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
}

void onLectureTtsPlayPressed(
  BuildContext context, {
  required bool canPlayTts,
  required VoidCallback onPlayPause,
  required String blockedMessage,
}) {
  if (canPlayTts) {
    onPlayPause();
    return;
  }
  showLectureTtsPlayBlockedSnack(context, blockedMessage);
}

class LectureTtsAppBarButton extends ConsumerWidget {
  const LectureTtsAppBarButton({
    required this.scope,
    super.key,
  });

  final LectureSessionScope scope;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(
      lectureSessionProvider(scope).select(
        (s) => (
          tts: s.tts,
          selectedLanguage: s.selectedLanguage,
          computedSenders: s.computedSenders,
        ),
      ),
    );
    final notifier = ref.read(lectureSessionProvider(scope).notifier);
    final voiceAvailability = ttsVoiceAvailability(
      selectedLanguage: session.selectedLanguage,
      computedSenders: session.computedSenders,
    );
    final snapshot = session.tts;
    final playbackRequested =
        snapshot.isPlaying || notifier.ttsUserWantsPlayback;
    final canPlayTts =
        playbackRequested ||
        (voiceAvailability == TtsVoiceAvailability.available &&
            snapshot.bufferedDurationSec > 0);
    final blockedMessage = lectureTtsPlayBlockedMessage(
      voiceAvailability: voiceAvailability,
    );
    final scheme = Theme.of(context).colorScheme;

    if (voiceAvailability != TtsVoiceAvailability.available &&
        !playbackRequested) {
      return IconButton(
        tooltip: 'Voice output unavailable',
        iconSize: 32,
        onPressed: () => showLectureTtsPlayBlockedSnack(
          context,
          ttsVoiceUnavailableMessage(voiceAvailability),
        ),
        icon: Icon(
          Icons.volume_off_rounded,
          color: scheme.onSurface.withValues(alpha: 0.38),
        ),
      );
    }
    return IconButton(
      tooltip: playbackRequested ? 'Pause TTS' : 'Play TTS',
      iconSize: 32,
      onPressed: () {
        if (!playbackRequested) {
          notifier.engageTtsCollapsedSlider();
        }
        onLectureTtsPlayPressed(
          context,
          canPlayTts: canPlayTts,
          onPlayPause: notifier.ttsPlayPause,
          blockedMessage: blockedMessage,
        );
      },
      icon: Icon(
        playbackRequested ? Icons.volume_up_rounded : Icons.volume_off_rounded,
      ),
    );
  }
}
