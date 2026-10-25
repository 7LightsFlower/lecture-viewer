import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:lecture_viewer_v3/core/api/lecture_shorten_client.dart';
import 'package:lecture_viewer_v3/core/lecture_snapshot/lecture_snapshot_provider.dart';
import 'package:lecture_viewer_v3/core/providers/app_settings_notifier.dart';
import 'package:lecture_viewer_v3/core/providers/core_providers.dart';
import 'package:lecture_viewer_v3/core/saved_lectures/saved_lecture.dart';
import 'package:lecture_viewer_v3/core/saved_lectures/saved_lectures_provider.dart';
import 'package:lecture_viewer_v3/core/util/lecture_ws_url.dart';
import 'package:lecture_viewer_v3/core/util/open_lecture_session.dart';
import 'package:lecture_viewer_v3/features/lecture_session/presentation/lecture_session_scope.dart';
import 'package:lecture_viewer_v3/features/lecture_session/presentation/lecture_session_screen.dart';
import 'package:lecture_viewer_v3/features/lecture_session/presentation/lecture_session_state.dart';
import 'package:lecture_viewer_v3/features/lecture_session/presentation/providers/lecture_session_notifier.dart';
import 'package:lecture_common/lecture_common.dart';

class _FakeShortenClient implements LectureShortenClient {
  _FakeShortenClient(this._status);

  final int? _status;

  @override
  Future<int?> checkShorten(
    String meetingName, {
    String httpsOrigin = kLectureTranslatorHttpOrigin,
  }) async =>
      _status;
}

class _TestAppSettingsNotifier extends AppSettingsNotifier {
  @override
  AppSettingsState build() {
    return const AppSettingsState(
      themeMode: ThemeMode.system,
      keepScreenOn: false,
      textScale: 1.0,
    );
  }
}

class _BookmarkedLectureNotifier extends SavedLecturesNotifier {
  _BookmarkedLectureNotifier(this._linkRecord);

  final String _linkRecord;

  @override
  List<SavedLecture> build() => [
        SavedLecture(
          id: '1',
          displayName: 'Saved',
          linkRecord: _linkRecord,
          sessionId: 'foo-lecture',
          savedAt: '2026-05-18T12:00:00.000Z',
          lastJoinedAt: '2026-05-18T12:00:00.000Z',
        ),
      ];

  @override
  bool containsLinkRecord(String linkRecord) => linkRecord == _linkRecord;

  @override
  Future<bool> setJoinUrlIfMissing(String linkRecord, String joinUrl) async {
    return false;
  }
}

class _TestLectureSessionNotifier extends LectureSessionNotifier {
  @override
  LectureSessionState build(LectureSessionScope scope) {
    return LectureSessionState(
      sessionId: scope.sessionId,
      hasReceivedInfo: true,
      activeLanguages: const ['English'],
      computedSenders: const {
        'mt:1_en': ComputedSenderInfo(
          language: 'English',
          type: 'mt',
          percent: 0,
        ),
      },
      selectedLanguage: 'English',
      selectedRawSender: 'mt:1_en',
    );
  }
}

Future<void> _pumpFrames(WidgetTester tester, {int count = 10}) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

class _FakePathProvider extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  @override
  Future<String?> getApplicationDocumentsPath() async => '/tmp';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  PathProviderPlatform.instance = _FakePathProvider();
  setUp(() {
    deleteLectureSnapshotForLinkRecordOverride = (_) async {};
  });
  tearDown(() {
    deleteLectureSnapshotForLinkRecordOverride = null;
  });

  const linkRecord = 'lt2srv.iar.kit.edu/mobile/session/foo-lecture';

  testWidgets('shorten 500 shows session ended and does not push session',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    late BuildContext harnessContext;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              harnessContext = context;
              return const Scaffold(body: Text('Ready'));
            },
          ),
        ),
      ),
    );
    await tester.pump();

    final openFuture = openLectureSessionFromLinkRecord(
      harnessContext,
      linkRecord,
      shortenClient: _FakeShortenClient(500),
    );
    await _pumpFrames(tester);

    expect(find.text('Session ended'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pump();
    expect(await openFuture, isFalse);
    expect(find.text('This session is no longer available.'), findsOneWidget);
    expect(find.text('Join event'), findsNothing);
    expect(find.byType(LectureSessionScreen), findsNothing);
  });

  testWidgets('shorten 200 skips join dialog and pushes session screen',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    late BuildContext harnessContext;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          savedLecturesProvider.overrideWith(
            () => _BookmarkedLectureNotifier(linkRecord),
          ),
          appSettingsProvider.overrideWith(_TestAppSettingsNotifier.new),
          lectureSessionProvider.overrideWith(_TestLectureSessionNotifier.new),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              harnessContext = context;
              return const Scaffold(body: Text('Ready'));
            },
          ),
        ),
      ),
    );
    await tester.pump();

    final openFuture = openLectureSessionFromLinkRecord(
      harnessContext,
      linkRecord,
      shortenClient: _FakeShortenClient(200),
    );
    await _pumpFrames(tester, count: 15);

    expect(find.text('Join event'), findsNothing);
    expect(find.byType(LectureSessionScreen), findsOneWidget);
    expect(find.text('foo-lecture'), findsOneWidget);

    await tester.pageBack();
    await tester.pump();
    await openFuture;
  });

  testWidgets('passes joinUrl onto LectureSessionScreen scope', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    late BuildContext harnessContext;
    const joinUrl =
        'https://lectureviewer.app.link/x?link_record=lt2srv.iar.kit.edu/mobile/session/foo-lecture';

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          savedLecturesProvider.overrideWith(
            () => _BookmarkedLectureNotifier(linkRecord),
          ),
          appSettingsProvider.overrideWith(_TestAppSettingsNotifier.new),
          lectureSessionProvider.overrideWith(_TestLectureSessionNotifier.new),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              harnessContext = context;
              return const Scaffold(body: Text('Ready'));
            },
          ),
        ),
      ),
    );
    await tester.pump();

    final openFuture = openLectureSessionFromLinkRecord(
      harnessContext,
      linkRecord,
      shortenClient: _FakeShortenClient(200),
      joinUrl: joinUrl,
    );
    await _pumpFrames(tester, count: 15);

    final screen = tester.widget<LectureSessionScreen>(
      find.byType(LectureSessionScreen),
    );
    expect(screen.scope.joinUrl, joinUrl);

    await tester.pageBack();
    await tester.pump();
    await openFuture;
  });

  testWidgets('backfills bookmark joinUrl when missing', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    late BuildContext harnessContext;
    const joinUrl =
        'https://lectureviewer.app.link/x?link_record=lt2srv.iar.kit.edu/mobile/session/foo-lecture';

    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        appSettingsProvider.overrideWith(_TestAppSettingsNotifier.new),
        lectureSessionProvider.overrideWith(_TestLectureSessionNotifier.new),
      ],
    );
    addTearDown(container.dispose);

    await container.read(savedLecturesProvider.notifier).add(
          displayName: 'Saved',
          linkRecord: linkRecord,
          sessionId: 'foo-lecture',
        );
    expect(container.read(savedLecturesProvider).single.joinUrl, isNull);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              harnessContext = context;
              return const Scaffold(body: Text('Ready'));
            },
          ),
        ),
      ),
    );
    await tester.pump();

    final openFuture = openLectureSessionFromLinkRecord(
      harnessContext,
      linkRecord,
      shortenClient: _FakeShortenClient(200),
      joinUrl: joinUrl,
    );
    await _pumpFrames(tester, count: 15);

    expect(container.read(savedLecturesProvider).single.joinUrl, joinUrl);

    await tester.pageBack();
    await tester.pump();
    await openFuture;
  });

  testWidgets('invalid linkRecord returns false without dialog', (tester) async {
    late BuildContext harnessContext;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            harnessContext = context;
            return const Scaffold(body: Text('Ready'));
          },
        ),
      ),
    );
    await tester.pump();

    final ok = await openLectureSessionFromLinkRecord(
      harnessContext,
      '',
      shortenClient: _FakeShortenClient(500),
    );

    expect(ok, isFalse);
    expect(find.text('Session ended'), findsNothing);
  });

  testWidgets('shows join QR action when joinUrl is set', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    late BuildContext harnessContext;
    const joinUrl =
        'https://lectureviewer.app.link/x?link_record=lt2srv.iar.kit.edu/mobile/session/foo-lecture';

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          savedLecturesProvider.overrideWith(
            () => _BookmarkedLectureNotifier(linkRecord),
          ),
          appSettingsProvider.overrideWith(_TestAppSettingsNotifier.new),
          lectureSessionProvider.overrideWith(_TestLectureSessionNotifier.new),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              harnessContext = context;
              return const Scaffold(body: Text('Ready'));
            },
          ),
        ),
      ),
    );
    await tester.pump();

    final openFuture = openLectureSessionFromLinkRecord(
      harnessContext,
      linkRecord,
      shortenClient: _FakeShortenClient(200),
      joinUrl: joinUrl,
    );
    await _pumpFrames(tester, count: 15);

    expect(find.byTooltip('Show join QR'), findsOneWidget);
    await tester.tap(find.byTooltip('Show join QR'));
    await tester.pumpAndSettle();
    expect(find.text('Join to view transcription by QR'), findsOneWidget);

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pump();
    await openFuture;
  });

  testWidgets('hides join QR action when joinUrl is null', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    late BuildContext harnessContext;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          savedLecturesProvider.overrideWith(
            () => _BookmarkedLectureNotifier(linkRecord),
          ),
          appSettingsProvider.overrideWith(_TestAppSettingsNotifier.new),
          lectureSessionProvider.overrideWith(_TestLectureSessionNotifier.new),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              harnessContext = context;
              return const Scaffold(body: Text('Ready'));
            },
          ),
        ),
      ),
    );
    await tester.pump();

    final openFuture = openLectureSessionFromLinkRecord(
      harnessContext,
      linkRecord,
      shortenClient: _FakeShortenClient(200),
    );
    await _pumpFrames(tester, count: 15);

    expect(find.byTooltip('Show join QR'), findsNothing);

    await tester.pageBack();
    await tester.pump();
    await openFuture;
  });
}
