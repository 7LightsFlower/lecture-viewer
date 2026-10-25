import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lecture_viewer_v3/core/providers/core_providers.dart';
import 'package:lecture_viewer_v3/core/saved_lectures/saved_lecture.dart';
import 'package:lecture_viewer_v3/core/saved_lectures/saved_lectures_provider.dart';
import 'package:lecture_viewer_v3/features/home/presentation/saved_lectures_list.dart';

class _RenameTestNotifier extends SavedLecturesNotifier {
  @override
  List<SavedLecture> build() => const [
        SavedLecture(
          id: 'id-1',
          displayName: 'My lecture',
          linkRecord: 'host/mobile/session/foo',
          sessionId: 'foo',
          savedAt: '2026-05-20T12:00:00.000Z',
          lastJoinedAt: '2026-05-20T12:00:00.000Z',
        ),
      ];

  @override
  Future<bool> updateDisplayName(String id, String displayName) async {
    state = [
      SavedLecture(
        id: 'id-1',
        displayName: displayName,
        linkRecord: 'host/mobile/session/foo',
        sessionId: 'foo',
        savedAt: '2026-05-20T12:00:00.000Z',
        lastJoinedAt: '2026-05-20T12:00:00.000Z',
      ),
    ];
    return true;
  }
}

void main() {
  testWidgets('edit icon opens rename dialog and updates title', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          savedLecturesProvider.overrideWith(_RenameTestNotifier.new),
        ],
        child: const MaterialApp(home: Scaffold(body: SavedLecturesList())),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Rename lecture'));
    await tester.pumpAndSettle();

    expect(find.text('Rename lecture'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Renamed title');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('Renamed title'), findsOneWidget);
    expect(find.text('My lecture'), findsNothing);
  });
}
