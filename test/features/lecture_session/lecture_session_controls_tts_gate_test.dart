import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lecture_common/lecture_common.dart';
import 'package:lecture_viewer_v3/features/lecture_session/presentation/lecture_session_controls.dart';
import 'package:lecture_viewer_v3/features/lecture_session/presentation/lecture_session_scope.dart';
import 'package:lecture_viewer_v3/features/lecture_session/presentation/lecture_session_state.dart';
import 'package:lecture_viewer_v3/features/lecture_session/presentation/providers/lecture_session_notifier.dart';

const _scope = (
  sessionId: 'controls-gate',
  linkRecord: 'example.edu/mobile/session/controls-gate',
  joinUrl: null,
);

class _ControlsGateTestNotifier extends LectureSessionNotifier {
  _ControlsGateTestNotifier(this.initial);

  final LectureSessionState initial;

  @override
  LectureSessionState build(LectureSessionScope scope) => initial;
}

void main() {
  testWidgets('collapsed controls hide slider until gate visible', (
    WidgetTester tester,
  ) async {
    final base = LectureSessionState(
      sessionId: 'controls-gate',
      hasReceivedInfo: true,
      activeLanguages: ['German'],
      computedSenders: {
        'tts:1_de': ComputedSenderInfo(
          language: 'German',
          type: 'tts',
          percent: 0,
        ),
      },
      selectedLanguage: 'German',
      selectedRawSender: 'tts:1_de',
      tts: TtsPaneSnapshot(bufferedDurationSec: 8),
      ttsCollapsedSliderVisible: false,
    );
    final testNotifier = _ControlsGateTestNotifier(base);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          lectureSessionProvider.overrideWith(() => testNotifier),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              child: LectureSessionControls(
                scope: _scope,
                expanded: false,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(Slider), findsNothing);

    testNotifier.state = base.copyWith(ttsCollapsedSliderVisible: true);
    await tester.pump();

    expect(find.byType(Slider), findsOneWidget);
    expect(find.text('00:08'), findsOneWidget);
  });
}
