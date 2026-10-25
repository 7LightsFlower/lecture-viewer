import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lecture_common/lecture_common.dart';
import 'package:lecture_viewer_v3/features/lecture_session/domain/tts/lecture_tts_language.dart';
import 'package:lecture_viewer_v3/features/lecture_session/presentation/lecture_session_controls.dart';
import 'package:lecture_viewer_v3/features/lecture_session/presentation/lecture_session_scope.dart';
import 'package:lecture_viewer_v3/features/lecture_session/presentation/lecture_session_state.dart';
import 'package:lecture_viewer_v3/features/lecture_session/presentation/lecture_tts_app_bar_button.dart';
import 'package:lecture_viewer_v3/features/lecture_session/presentation/providers/lecture_session_notifier.dart';

const _scope = (
  sessionId: 'tts-notice',
  linkRecord: 'example.edu/mobile/session/tts-notice',
  joinUrl: null,
);

class _TtsNoticeTestNotifier extends LectureSessionNotifier {
  _TtsNoticeTestNotifier(this.initial);

  final LectureSessionState initial;

  @override
  LectureSessionState build(LectureSessionScope scope) => initial;

  @override
  void setLanguage(String language) {
    if (language == state.selectedLanguage) return;
    state = state.copyWith(selectedLanguage: language);
  }
}

LectureSessionState _unsupportedLanguageState({
  required String selectedLanguage,
}) {
  return LectureSessionState(
    sessionId: 'tts-notice',
    hasReceivedInfo: true,
    activeLanguages: const ['German', 'Japanese'],
    computedSenders: const {
      'tts:1_de': ComputedSenderInfo(
        language: 'German',
        type: 'tts',
        percent: 0,
      ),
      'mt:1_de': ComputedSenderInfo(language: 'German', type: 'mt', percent: 0),
      'mt:1_ja': ComputedSenderInfo(
        language: 'Japanese',
        type: 'mt',
        percent: 0,
      ),
    },
    selectedLanguage: selectedLanguage,
    selectedRawSender: selectedLanguage == 'German' ? 'mt:1_de' : 'mt:1_ja',
  );
}

void main() {
  testWidgets('changing to unsupported language does not show snackbar', (
    WidgetTester tester,
  ) async {
    final testNotifier = _TtsNoticeTestNotifier(
      _unsupportedLanguageState(selectedLanguage: 'German'),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [lectureSessionProvider.overrideWith(() => testNotifier)],
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              child: LectureSessionControls(scope: _scope, expanded: true),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Japanese').last);
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsNothing);
    expect(find.text(kTtsLanguageUnsupportedMessage), findsNothing);
    expect(testNotifier.state.selectedLanguage, 'Japanese');
  });

  testWidgets('grey speaker button shows unsupported language snackbar', (
    WidgetTester tester,
  ) async {
    final testNotifier = _TtsNoticeTestNotifier(
      _unsupportedLanguageState(selectedLanguage: 'Japanese'),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [lectureSessionProvider.overrideWith(() => testNotifier)],
        child: MaterialApp(
          home: Scaffold(
            appBar: AppBar(actions: [LectureTtsAppBarButton(scope: _scope)]),
            body: const SizedBox.shrink(),
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.volume_off_rounded));
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text(kTtsLanguageUnsupportedMessage), findsOneWidget);
  });
}
