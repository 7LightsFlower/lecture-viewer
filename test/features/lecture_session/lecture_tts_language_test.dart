import 'package:flutter_test/flutter_test.dart';
import 'package:lecture_common/lecture_common.dart';
import 'package:lecture_viewer_v3/features/lecture_session/domain/tts/lecture_tts_language.dart';

void main() {
  final senders = {
    'tts:1': const ComputedSenderInfo(
      language: 'German',
      type: 'tts',
      percent: 0,
    ),
  };

  test('prefers languageFromPayload', () {
    const event = TtsPcmEvent(
      url: 'u',
      rawSender: 'tts:1',
      languageFromPayload: 'German',
    );
    expect(resolveLectureTtsLanguage(event, senders), 'German');
  });

  test('falls back to computedSenders', () {
    const event = TtsPcmEvent(url: 'u', rawSender: 'tts:1');
    expect(resolveLectureTtsLanguage(event, senders), 'German');
  });

  test('returns null when unknown', () {
    const event = TtsPcmEvent(url: 'u', rawSender: 'tts:9');
    expect(resolveLectureTtsLanguage(event, senders), isNull);
  });

  test('isTtsSupportedForLanguage when tts sender exists', () {
    expect(isTtsSupportedForLanguage('German', senders), isTrue);
    expect(isTtsSupportedForLanguage('English', senders), isFalse);
    expect(isTtsSupportedForLanguage('', senders), isFalse);
  });

  group('ttsVoiceAvailability', () {
    test('Transcript language is transcriptMode', () {
      expect(
        ttsVoiceAvailability(
          selectedLanguage: 'Transcript',
          computedSenders: senders,
        ),
        TtsVoiceAvailability.transcriptMode,
      );
    });

    test('language with tts route is available', () {
      expect(
        ttsVoiceAvailability(
          selectedLanguage: 'German',
          computedSenders: senders,
        ),
        TtsVoiceAvailability.available,
      );
    });

    test('language without tts route is languageUnsupported', () {
      expect(
        ttsVoiceAvailability(
          selectedLanguage: 'Japanese',
          computedSenders: senders,
        ),
        TtsVoiceAvailability.languageUnsupported,
      );
    });

    test('empty language is languageUnsupported', () {
      expect(
        ttsVoiceAvailability(selectedLanguage: '', computedSenders: senders),
        TtsVoiceAvailability.languageUnsupported,
      );
    });
  });

  group('ttsVoiceUnavailableMessage', () {
    test('transcriptMode message', () {
      expect(
        ttsVoiceUnavailableMessage(TtsVoiceAvailability.transcriptMode),
        'Please select a language',
      );
    });

    test('languageUnsupported message', () {
      expect(
        ttsVoiceUnavailableMessage(TtsVoiceAvailability.languageUnsupported),
        'Voice output not activated for this language',
      );
    });
  });
}
