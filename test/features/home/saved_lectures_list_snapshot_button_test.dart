import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lecture_viewer_v3/core/lecture_snapshot/lecture_snapshot_provider.dart';
import 'package:lecture_viewer_v3/core/providers/core_providers.dart';
import 'package:lecture_viewer_v3/core/saved_lectures/saved_lecture.dart';
import 'package:lecture_viewer_v3/core/saved_lectures/saved_lectures_provider.dart';
import 'package:lecture_viewer_v3/features/home/presentation/saved_lectures_list.dart';

const _kLinkRecord = 'lt2srv.example.edu/mobile/session/foo';

class _TestSavedLecturesNotifier extends SavedLecturesNotifier {
  @override
  List<SavedLecture> build() => [
        const SavedLecture(
          id: 'id-1',
          displayName: 'My lecture',
          linkRecord: _kLinkRecord,
          sessionId: 'foo',
          savedAt: '2026-05-19T12:00:00.000Z',
          lastJoinedAt: '2026-05-19T12:00:00.000Z',
        ),
      ];
}

Future<void> _pumpList(
  WidgetTester tester, {
  required bool shareable,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        savedLecturesProvider.overrideWith(_TestSavedLecturesNotifier.new),
        lectureSnapshotShareableProvider(_kLinkRecord)
            .overrideWith((ref) async => shareable),
      ],
      child: const MaterialApp(home: Scaffold(body: SavedLecturesList())),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows Share when websocket sessionId is saved', (tester) async {
    await _pumpList(tester, shareable: true);
    expect(find.byTooltip('Share'), findsOneWidget);
    expect(find.byTooltip('Rename lecture'), findsOneWidget);
  });

  testWidgets('hides Share when no websocket sessionId', (tester) async {
    await _pumpList(tester, shareable: false);
    expect(find.byTooltip('Share'), findsNothing);
    expect(find.byTooltip('Rename lecture'), findsOneWidget);
  });
}
