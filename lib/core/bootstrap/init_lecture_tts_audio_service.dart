import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:lecture_viewer_v3/features/lecture_session/data/media/lecture_tts_audio_handler.dart';

LectureTtsAudioHandler? _lectureTtsAudioHandler;

/// Initializes [audio_service] for lock-screen / notification media controls.
Future<void> initLectureTtsAudioService() async {
  if (kIsWeb) return;
  if (_lectureTtsAudioHandler != null) return;

  final handler = LectureTtsAudioHandler();
  await AudioService.init(
    builder: () => handler,
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'lecture_tts_playback',
      androidNotificationChannelName: 'Lecture translation',
      androidNotificationOngoing: true,
    ),
  );
  _lectureTtsAudioHandler = handler;
}

/// Active handler after [initLectureTtsAudioService]; null on web or before init.
LectureTtsAudioHandler? get lectureTtsAudioHandler => _lectureTtsAudioHandler;
