import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lecture_common/lecture_common.dart';
import 'package:lecture_viewer_v3/features/lecture_session/presentation/lecture_session_scope.dart';
import 'package:lecture_viewer_v3/features/lecture_session/presentation/lecture_session_state.dart';
import 'package:lecture_viewer_v3/features/lecture_session/presentation/providers/lecture_session_notifier.dart';

const _scope = (
  sessionId: 'gate-test',
  linkRecord: 'example.edu/mobile/session/gate-test',
  joinUrl: null,
);

const _ttsSenders = {
  'tts:1_de': ComputedSenderInfo(
    language: 'German',
    type: 'tts',
    percent: 0,
  ),
};

class _GateTestNotifier extends LectureSessionNotifier {
  @override
  LectureSessionState build(LectureSessionScope scope) {
    return LectureSessionState(
      sessionId: scope.sessionId,
      hasReceivedInfo: true,
      activeLanguages: const ['German', 'Transcript'],
      computedSenders: _ttsSenders,
      selectedLanguage: 'German',
      selectedRawSender: 'tts:1_de',
    );
  }

  void seedPlayingWithSliderVisible() {
    state = state.copyWith(
      ttsCollapsedSliderVisible: true,
      tts: const TtsPaneSnapshot(
        isPlaying: true,
        bufferedDurationSec: 12,
        playbackPositionSec: 3,
      ),
    );
  }

  void seedEnglishTts() {
    state = state.copyWith(
      activeLanguages: const ['German', 'English'],
      computedSenders: {
        ..._ttsSenders,
        'tts:1_en': const ComputedSenderInfo(
          language: 'English',
          type: 'tts',
          percent: 0,
        ),
      },
    );
  }

  @override
  void ttsPlayPause() {
    final wasPlaying = state.tts.isPlaying;
    if (wasPlaying) {
      state = state.copyWith(ttsCollapsedSliderVisible: false);
    }
  }
}

Future<void> _waitForLanguage(
  ProviderContainer container,
  String language,
) async {
  for (var i = 0; i < 50; i++) {
    await Future<void>.delayed(Duration.zero);
    if (container.read(lectureSessionProvider(_scope)).selectedLanguage ==
        language) {
      return;
    }
  }
  fail('Timed out waiting for language $language');
}

void main() {
  group('LectureSessionNotifier TTS collapsed slider gate', () {
    late ProviderContainer container;
    late _GateTestNotifier notifier;

    setUp(() {
      container = ProviderContainer(
        overrides: [
          lectureSessionProvider.overrideWith(_GateTestNotifier.new),
        ],
      );
      container.listen(lectureSessionProvider(_scope), (_, __) {});
      notifier = container.read(lectureSessionProvider(_scope).notifier)
          as _GateTestNotifier;
    });

    tearDown(() => container.dispose());

    test('engageTtsCollapsedSlider sets visible', () {
      expect(
        container.read(lectureSessionProvider(_scope)).ttsCollapsedSliderVisible,
        isFalse,
      );

      notifier.engageTtsCollapsedSlider();

      expect(
        container.read(lectureSessionProvider(_scope)).ttsCollapsedSliderVisible,
        isTrue,
      );
    });

    test('ttsPlayPause clears visible when pausing', () {
      notifier.seedPlayingWithSliderVisible();

      notifier.ttsPlayPause();

      expect(
        container.read(lectureSessionProvider(_scope)).ttsCollapsedSliderVisible,
        isFalse,
      );
    });

    test('setLanguage to Transcript clears visible', () async {
      notifier.engageTtsCollapsedSlider();
      expect(
        container.read(lectureSessionProvider(_scope)).ttsCollapsedSliderVisible,
        isTrue,
      );

      notifier.setLanguage('Transcript');
      await _waitForLanguage(container, 'Transcript');

      expect(
        container.read(lectureSessionProvider(_scope)).ttsCollapsedSliderVisible,
        isFalse,
      );
      expect(
        container.read(lectureSessionProvider(_scope)).selectedLanguage,
        'Transcript',
      );
    });

    test('setLanguage between TTS languages preserves visible', () async {
      notifier.seedEnglishTts();
      notifier.engageTtsCollapsedSlider();

      notifier.setLanguage('English');
      await _waitForLanguage(container, 'English');

      expect(
        container.read(lectureSessionProvider(_scope)).ttsCollapsedSliderVisible,
        isTrue,
      );
    });

    test('onRemotePlay engages collapsed slider', () async {
      expect(
        container.read(lectureSessionProvider(_scope)).ttsCollapsedSliderVisible,
        isFalse,
      );

      await notifier.onRemotePlay();

      expect(
        container.read(lectureSessionProvider(_scope)).ttsCollapsedSliderVisible,
        isTrue,
      );
    });

  });
}
