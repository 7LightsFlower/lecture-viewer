import 'package:lecture_viewer_v3/features/lecture_session/domain/tts/lecture_tts_language.dart';

bool shouldClearTtsCollapsedSliderOnLanguageChange(
  TtsVoiceAvailability availability,
) {
  return availability == TtsVoiceAvailability.transcriptMode ||
      availability == TtsVoiceAvailability.languageUnsupported;
}
