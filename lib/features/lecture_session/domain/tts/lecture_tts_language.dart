import 'package:lecture_common/lecture_common.dart';

enum TtsVoiceAvailability { available, transcriptMode, languageUnsupported }

const kTtsTranscriptModeMessage = 'Please select a language';
const kTtsLanguageUnsupportedMessage =
    'Voice output not activated for this language';

String? resolveLectureTtsLanguage(
  TtsPcmEvent event,
  Map<String, ComputedSenderInfo> computedSenders,
) {
  final hint = event.languageFromPayload;
  if (hint != null && hint.isNotEmpty) return hint;
  return computedSenders[event.rawSender]?.language;
}

/// Whether the session exposes a `tts:*` route for [language].
bool isTtsSupportedForLanguage(
  String language,
  Map<String, ComputedSenderInfo> computedSenders,
) {
  if (language.isEmpty) return false;
  return computedSenders.values.any(
    (info) => info.type == 'tts' && info.language == language,
  );
}

TtsVoiceAvailability ttsVoiceAvailability({
  required String selectedLanguage,
  required Map<String, ComputedSenderInfo> computedSenders,
}) {
  if (selectedLanguage == 'Transcript') {
    return TtsVoiceAvailability.transcriptMode;
  }
  if (isTtsSupportedForLanguage(selectedLanguage, computedSenders)) {
    return TtsVoiceAvailability.available;
  }
  return TtsVoiceAvailability.languageUnsupported;
}

String ttsVoiceUnavailableMessage(TtsVoiceAvailability availability) {
  return switch (availability) {
    TtsVoiceAvailability.transcriptMode => kTtsTranscriptModeMessage,
    TtsVoiceAvailability.languageUnsupported => kTtsLanguageUnsupportedMessage,
    TtsVoiceAvailability.available => throw ArgumentError(
      'ttsVoiceUnavailableMessage called for available state',
    ),
  };
}
