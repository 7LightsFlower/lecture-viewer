import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lecture_viewer_v3/core/providers/core_providers.dart';
import 'package:lecture_viewer_v3/core/saved_lectures/saved_lecture.dart';
import 'package:lecture_viewer_v3/core/saved_lectures/saved_lectures_provider.dart';
import 'package:lecture_viewer_v3/features/home/presentation/home_screen.dart';

void main() {
  testWidgets('home shows scan and settings', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          savedLecturesProvider.overrideWith(() => _EmptySavedLecturesNotifier()),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Lectures'), findsOneWidget);
    expect(find.text('Scan QR'), findsOneWidget);
    expect(find.byIcon(Icons.settings), findsOneWidget);
  });

  testWidgets('home shows saved lectures when list non-empty', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          savedLecturesProvider.overrideWith(() => _OneSavedLectureNotifier()),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Saved one'), findsOneWidget);
    expect(find.textContaining('Last join time:'), findsOneWidget);
    expect(find.text('Scan a lecture QR code'), findsNothing);
  });
}

class _EmptySavedLecturesNotifier extends SavedLecturesNotifier {
  @override
  List<SavedLecture> build() => const [];
}

class _OneSavedLectureNotifier extends SavedLecturesNotifier {
  @override
  List<SavedLecture> build() => const [
        SavedLecture(
          id: '1',
          displayName: 'Saved one',
          linkRecord: 'host/mobile/session/foo',
          sessionId: 'foo',
          savedAt: '2026-05-18T12:00:00.000Z',
          lastJoinedAt: '2026-05-18T12:00:00.000Z',
        ),
      ];
}
