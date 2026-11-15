import 'package:flutter/foundation.dart';
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

  Future<void> pumpEmptyHome(WidgetTester tester) async {
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
  }

  testWidgets('home offers link entry next to QR scan', (tester) async {
    await pumpEmptyHome(tester);
    expect(find.text('Enter link'), findsOneWidget);
    expect(find.byTooltip('Enter link'), findsOneWidget);

    await tester.tap(find.text('Enter link'));
    await tester.pumpAndSettle();
    expect(find.text('Enter session link'), findsOneWidget);

    final open = find.widgetWithText(FilledButton, 'Open');
    expect(tester.widget<FilledButton>(open).onPressed, isNull);
    await tester.enterText(find.byType(TextField), 'two words');
    await tester.pump();
    expect(tester.widget<FilledButton>(open).onPressed, isNull);
    await tester.enterText(
      find.byType(TextField),
      'lt2srv.iar.kit.edu/mobile/session/foo',
    );
    await tester.pump();
    expect(tester.widget<FilledButton>(open).onPressed, isNotNull);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Enter session link'), findsNothing);
  });

  testWidgets('without QR scanner support only link entry is shown',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      await pumpEmptyHome(tester);
      expect(find.text('Scan QR'), findsNothing);
      expect(find.byTooltip('Scan QR'), findsNothing);
      expect(find.text('Open a lecture'), findsOneWidget);
      expect(find.text('Enter link'), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
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
