# Live Session Join QR Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Persist the original lecture join URL from QR/Branch, show a QR AppBar icon on the live session when that URL exists, and display a Close-only QR dialog so another person can join.

**Architecture:** Optional `joinUrl` on `LectureSessionScope` and `SavedLecture`. Entry paths pass the original lecture app link (never reconstruct from `linkRecord`). `openLectureSessionFromLinkRecord` backfills a missing bookmark URL, then the session screen shows `Icons.qr_code_2` only when `joinUrl != null`.

**Tech stack:** Flutter, Riverpod, SharedPreferences (`saved_lectures_v1`), `qr_flutter` ^4.1.0.

**Spec reference:** `docs/superpowers/specs/2026-10-15-live-session-join-qr-design.md`

## Global Constraints

- Do **not** reconstruct `https://lectureviewer.app.link/…?link_record=…` from `linkRecord`.
- Hide the QR AppBar icon when `joinUrl` is null.
- Dialog title is exactly `Join to view transcription by QR`; actions are **Close** only — no copy link, no Share QR, no “or” divider.
- Backfill is first-wins: write `joinUrl` onto an existing bookmark only when that row’s `joinUrl` is null.
- `joinUrl` must pass `isLectureViewerAppLink` after trim; empty/whitespace becomes null.
- Do **not** create git commits (user request). Skip every commit step.

---

## File map

| Path | Action | Responsibility |
|------|--------|----------------|
| `lib/core/saved_lectures/saved_lecture.dart` | Modify | Optional `joinUrl`, JSON, `copyWith`, equality |
| `lib/core/saved_lectures/saved_lectures_repository.dart` | Modify | `setJoinUrlIfMissing` |
| `lib/core/saved_lectures/saved_lectures_provider.dart` | Modify | `add(joinUrl)` + `setJoinUrlIfMissing` |
| `lib/core/util/lecture_app_link.dart` | Modify | `joinUrlFromBranchSession` |
| `lib/features/lecture_session/presentation/lecture_session_scope.dart` | Modify | Add `joinUrl` to record + factory |
| `lib/core/util/open_lecture_session.dart` | Modify | Accept/pass `joinUrl`; backfill before push |
| `lib/features/home/presentation/qr_scan_screen.dart` | Modify | Pass scanned URL via `openLectureSessionFromAppLink` |
| `lib/app/branch_session_listener.dart` | Modify | Pass Branch join URL |
| `lib/features/home/presentation/saved_lectures_list.dart` | Modify | Pass `lecture.joinUrl` |
| `lib/features/lecture_session/presentation/save_lecture_on_exit.dart` | Modify | Persist `joinUrl` on new save |
| `lib/features/lecture_session/presentation/lecture_session_screen.dart` | Modify | Conditional QR AppBar action |
| `lib/features/lecture_session/presentation/lecture_session_qr_dialog.dart` | Create | Close-only QR dialog |
| `pubspec.yaml` | Modify | `qr_flutter: ^4.1.0` |
| `test/features/lecture_session/lecture_tts_unavailable_notice_test.dart` | Modify | Scope record includes `joinUrl` |
| `test/features/lecture_session/lecture_session_controls_tts_gate_test.dart` | Modify | Scope record includes `joinUrl` |
| `test/features/lecture_session/lecture_session_notifier_tts_gate_test.dart` | Modify | Scope record includes `joinUrl` |

---

### Task 1: `SavedLecture.joinUrl`

**Files:**
- Modify: `lib/core/saved_lectures/saved_lecture.dart`
- Test: `test/core/saved_lectures/saved_lecture_test.dart`

**Interfaces:**
- Consumes: existing `SavedLecture` named constructor
- Produces: `SavedLecture.joinUrl` (`String?`); `fromJson` missing/blank → `null`; `copyWith({String? joinUrl})` uses `joinUrl ?? this.joinUrl`

- [ ] **Step 1: Write the failing tests**

Append to `test/core/saved_lectures/saved_lecture_test.dart`:

```dart
  test('fromJson without joinUrl is null', () {
    const lecture = SavedLecture(
      id: 'id-1',
      displayName: 'My lecture',
      linkRecord: 'lt2srv.example.edu/mobile/session/foo-lecture',
      sessionId: 'foo-lecture',
      savedAt: '2026-05-18T12:00:00.000Z',
      lastJoinedAt: '2026-05-18T12:00:00.000Z',
    );
    final json = lecture.toJson()..remove('joinUrl');
    expect(SavedLecture.fromJson(json).joinUrl, isNull);
  });

  test('fromJson blank joinUrl is null', () {
    const lecture = SavedLecture(
      id: 'id-1',
      displayName: 'My lecture',
      linkRecord: 'lt2srv.example.edu/mobile/session/foo-lecture',
      sessionId: 'foo-lecture',
      savedAt: '2026-05-18T12:00:00.000Z',
      lastJoinedAt: '2026-05-18T12:00:00.000Z',
    );
    final json = lecture.toJson()..['joinUrl'] = '   ';
    expect(SavedLecture.fromJson(json).joinUrl, isNull);
  });

  test('toJson/fromJson keeps joinUrl', () {
    const lecture = SavedLecture(
      id: 'id-1',
      displayName: 'My lecture',
      linkRecord: 'lt2srv.example.edu/mobile/session/foo-lecture',
      sessionId: 'foo-lecture',
      savedAt: '2026-05-18T12:00:00.000Z',
      lastJoinedAt: '2026-05-18T12:00:00.000Z',
      joinUrl:
          'https://lectureviewer.app.link/x?link_record=lt2srv.example.edu/mobile/session/foo-lecture',
    );
    expect(SavedLecture.fromJson(lecture.toJson()), lecture);
  });

  test('copyWith sets joinUrl when missing', () {
    const lecture = SavedLecture(
      id: 'id-1',
      displayName: 'My lecture',
      linkRecord: 'lt2srv.example.edu/mobile/session/foo-lecture',
      sessionId: 'foo-lecture',
      savedAt: '2026-05-18T12:00:00.000Z',
      lastJoinedAt: '2026-05-18T12:00:00.000Z',
    );
    const url =
        'https://lectureviewer.app.link/x?link_record=lt2srv.example.edu/mobile/session/foo-lecture';
    expect(lecture.copyWith(joinUrl: url).joinUrl, url);
  });
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd /Users/macbook/Works/Lecture_Translation_Alex/lecture_viewer_v3
flutter test test/core/saved_lectures/saved_lecture_test.dart --name "joinUrl"
```

Expected: FAIL — `joinUrl` is not defined.

- [ ] **Step 3: Implement `joinUrl`**

Update `lib/core/saved_lectures/saved_lecture.dart`:

```dart
class SavedLecture {
  const SavedLecture({
    required this.id,
    required this.displayName,
    required this.linkRecord,
    required this.sessionId,
    required this.savedAt,
    required this.lastJoinedAt,
    this.joinUrl,
  });

  final String id;
  final String displayName;
  final String linkRecord;
  final String sessionId;
  final String savedAt;
  final String lastJoinedAt;
  final String? joinUrl;

  Map<String, dynamic> toJson() => {
        'id': id,
        'displayName': displayName,
        'linkRecord': linkRecord,
        'sessionId': sessionId,
        'savedAt': savedAt,
        'lastJoinedAt': lastJoinedAt,
        'joinUrl': joinUrl,
      };

  factory SavedLecture.fromJson(Map<String, dynamic> json) {
    final savedAt = json['savedAt'] as String;
    final rawJoinUrl = json['joinUrl'] as String?;
    final trimmedJoinUrl = rawJoinUrl?.trim();
    return SavedLecture(
      id: json['id'] as String,
      displayName: json['displayName'] as String,
      linkRecord: json['linkRecord'] as String,
      sessionId: json['sessionId'] as String,
      savedAt: savedAt,
      lastJoinedAt: json['lastJoinedAt'] as String? ?? savedAt,
      joinUrl: (trimmedJoinUrl == null || trimmedJoinUrl.isEmpty)
          ? null
          : trimmedJoinUrl,
    );
  }

  SavedLecture copyWith({
    String? displayName,
    String? lastJoinedAt,
    String? joinUrl,
  }) {
    return SavedLecture(
      id: id,
      displayName: displayName ?? this.displayName,
      linkRecord: linkRecord,
      sessionId: sessionId,
      savedAt: savedAt,
      lastJoinedAt: lastJoinedAt ?? this.lastJoinedAt,
      joinUrl: joinUrl ?? this.joinUrl,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is SavedLecture &&
        other.id == id &&
        other.displayName == displayName &&
        other.linkRecord == linkRecord &&
        other.sessionId == sessionId &&
        other.savedAt == savedAt &&
        other.lastJoinedAt == lastJoinedAt &&
        other.joinUrl == joinUrl;
  }

  @override
  int get hashCode => Object.hash(
        id,
        displayName,
        linkRecord,
        sessionId,
        savedAt,
        lastJoinedAt,
        joinUrl,
      );
}
```

Existing `SavedLecture(...)` call sites stay valid (`joinUrl` optional).

- [ ] **Step 4: Run tests to verify they pass**

```bash
flutter test test/core/saved_lectures/saved_lecture_test.dart
```

Expected: PASS (existing round-trip + new `joinUrl` cases).

---

### Task 2: Persist and backfill `joinUrl`

**Files:**
- Modify: `lib/core/saved_lectures/saved_lectures_repository.dart`
- Modify: `lib/core/saved_lectures/saved_lectures_provider.dart`
- Test: `test/core/saved_lectures/saved_lectures_repository_test.dart`
- Test: `test/core/saved_lectures/saved_lectures_provider_test.dart`

**Interfaces:**
- Consumes: `SavedLecture.copyWith(joinUrl:)`
- Produces:
  - `Future<bool> SavedLecturesRepository.setJoinUrlIfMissing(String linkRecord, String joinUrl)`
  - `Future<bool> SavedLecturesNotifier.setJoinUrlIfMissing(String linkRecord, String joinUrl)`
  - `SavedLecturesNotifier.add({..., String? joinUrl})`

- [ ] **Step 1: Write the failing repository tests**

Add `joinUrl` to the `sample` helper (optional, default null) and append:

```dart
  test('setJoinUrlIfMissing writes when bookmark joinUrl is null', () async {
    final prefs = await SharedPreferences.getInstance();
    final repo = SavedLecturesRepository(prefs);
    await repo.add(
      sample(id: '1', linkRecord: linkA, savedAt: '2026-05-18T10:00:00.000Z'),
    );

    const url =
        'https://lectureviewer.app.link/x?link_record=host/mobile/session/lecture-a';
    expect(await repo.setJoinUrlIfMissing(linkA, url), isTrue);
    expect(repo.load().single.joinUrl, url);
  });

  test('setJoinUrlIfMissing does not overwrite existing joinUrl', () async {
    final prefs = await SharedPreferences.getInstance();
    final repo = SavedLecturesRepository(prefs);
    await repo.add(
      SavedLecture(
        id: '1',
        displayName: 'Name 1',
        linkRecord: linkA,
        sessionId: 'lecture-a',
        savedAt: '2026-05-18T10:00:00.000Z',
        lastJoinedAt: '2026-05-18T10:00:00.000Z',
        joinUrl: 'https://lectureviewer.app.link/old?link_record=host/mobile/session/lecture-a',
      ),
    );

    expect(
      await repo.setJoinUrlIfMissing(
        linkA,
        'https://lectureviewer.app.link/new?link_record=host/mobile/session/lecture-a',
      ),
      isFalse,
    );
    expect(
      repo.load().single.joinUrl,
      'https://lectureviewer.app.link/old?link_record=host/mobile/session/lecture-a',
    );
  });

  test('setJoinUrlIfMissing returns false when lecture missing', () async {
    final prefs = await SharedPreferences.getInstance();
    final repo = SavedLecturesRepository(prefs);
    expect(
      await repo.setJoinUrlIfMissing(
        linkA,
        'https://lectureviewer.app.link/x?link_record=host/mobile/session/lecture-a',
      ),
      isFalse,
    );
  });
```

- [ ] **Step 2: Run repository tests to verify they fail**

```bash
flutter test test/core/saved_lectures/saved_lectures_repository_test.dart --name "setJoinUrlIfMissing"
```

Expected: FAIL — method not defined.

- [ ] **Step 3: Implement repository method**

Add to `SavedLecturesRepository`:

```dart
  Future<bool> setJoinUrlIfMissing(String linkRecord, String joinUrl) async {
    final trimmedUrl = joinUrl.trim();
    if (trimmedUrl.isEmpty) return false;

    final normalized = linkRecord.trim();
    final existing = load();
    var changed = false;
    final next = existing.map((lecture) {
      if (lecture.linkRecord.trim() != normalized) return lecture;
      if (lecture.joinUrl != null) return lecture;
      changed = true;
      return lecture.copyWith(joinUrl: trimmedUrl);
    }).toList();
    if (!changed) return false;
    return _persist(next);
  }
```

- [ ] **Step 4: Run repository tests**

```bash
flutter test test/core/saved_lectures/saved_lectures_repository_test.dart
```

Expected: PASS.

- [ ] **Step 5: Write failing provider tests**

Append to `test/core/saved_lectures/saved_lectures_provider_test.dart`:

```dart
  test('add persists joinUrl', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
    addTearDown(container.dispose);

    const url =
        'https://lectureviewer.app.link/x?link_record=host/mobile/session/foo-lecture';
    final ok = await container.read(savedLecturesProvider.notifier).add(
          displayName: 'My lecture',
          linkRecord: 'host/mobile/session/foo-lecture',
          sessionId: 'foo-lecture',
          joinUrl: url,
        );
    expect(ok, isTrue);
    expect(container.read(savedLecturesProvider).single.joinUrl, url);
  });

  test('setJoinUrlIfMissing updates provider state once', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(savedLecturesProvider.notifier);
    await notifier.add(
      displayName: 'My lecture',
      linkRecord: 'host/mobile/session/foo-lecture',
      sessionId: 'foo-lecture',
    );
    const url =
        'https://lectureviewer.app.link/x?link_record=host/mobile/session/foo-lecture';
    expect(
      await notifier.setJoinUrlIfMissing(
        'host/mobile/session/foo-lecture',
        url,
      ),
      isTrue,
    );
    expect(container.read(savedLecturesProvider).single.joinUrl, url);
    expect(
      await notifier.setJoinUrlIfMissing(
        'host/mobile/session/foo-lecture',
        'https://lectureviewer.app.link/other?link_record=host/mobile/session/foo-lecture',
      ),
      isFalse,
    );
    expect(container.read(savedLecturesProvider).single.joinUrl, url);
  });
```

- [ ] **Step 6: Run provider tests to verify they fail**

```bash
flutter test test/core/saved_lectures/saved_lectures_provider_test.dart --name "joinUrl"
```

Expected: FAIL — `joinUrl` / `setJoinUrlIfMissing` not on notifier.

- [ ] **Step 7: Implement provider**

In `add`, add optional `String? joinUrl` and pass it into `SavedLecture`:

```dart
      joinUrl: () {
        final trimmed = joinUrl?.trim();
        if (trimmed == null || trimmed.isEmpty) return null;
        return trimmed;
      }(),
```

Add:

```dart
  Future<bool> setJoinUrlIfMissing(String linkRecord, String joinUrl) async {
    final ok = await _repository.setJoinUrlIfMissing(linkRecord, joinUrl);
    if (ok) {
      state = _repository.load();
    }
    return ok;
  }
```

- [ ] **Step 8: Run provider tests**

```bash
flutter test test/core/saved_lectures/saved_lectures_provider_test.dart
```

Expected: PASS.

---

### Task 3: `joinUrlFromBranchSession`

**Files:**
- Modify: `lib/core/util/lecture_app_link.dart`
- Test: `test/core/util/lecture_app_link_test.dart`

**Interfaces:**
- Consumes: `isLectureViewerAppLink`
- Produces: `String? joinUrlFromBranchSession(Map<dynamic, dynamic> data)` — first valid lecture app link among `$canonical_url`, `+url`, `$desktop_url`, `~referring_link`

- [ ] **Step 1: Write the failing tests**

Append to `test/core/util/lecture_app_link_test.dart`:

```dart
  group('joinUrlFromBranchSession', () {
    test('returns first valid lecture app link', () {
      expect(
        joinUrlFromBranchSession({
          r'$canonical_url':
              'https://lectureviewer.app.link/x?link_record=host/path',
          '+url': 'https://example.com/nope',
        }),
        'https://lectureviewer.app.link/x?link_record=host/path',
      );
    });

    test('skips invalid keys and uses later valid url', () {
      expect(
        joinUrlFromBranchSession({
          r'$canonical_url': 'https://example.com/x?link_record=host/path',
          '+url':
              'https://lectureviewer.app.link/y?link_record=host/path',
        }),
        'https://lectureviewer.app.link/y?link_record=host/path',
      );
    });

    test('returns null when only link_record custom data exists', () {
      expect(
        joinUrlFromBranchSession({'link_record': 'host/path'}),
        isNull,
      );
    });
  });
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
flutter test test/core/util/lecture_app_link_test.dart --name "joinUrlFromBranchSession"
```

Expected: FAIL — function not defined.

- [ ] **Step 3: Implement helper**

Add to `lib/core/util/lecture_app_link.dart` (same key order as `linkRecordFromBranchSession`):

```dart
String? joinUrlFromBranchSession(Map<dynamic, dynamic> data) {
  const urlKeys = [
    r'$canonical_url',
    '+url',
    r'$desktop_url',
    '~referring_link',
  ];
  for (final key in urlKeys) {
    final raw = data[key];
    if (raw is! String) continue;
    final trimmed = raw.trim();
    final uri = Uri.tryParse(trimmed);
    if (uri != null && isLectureViewerAppLink(uri)) {
      return trimmed;
    }
  }
  return null;
}
```

- [ ] **Step 4: Run tests**

```bash
flutter test test/core/util/lecture_app_link_test.dart
```

Expected: PASS.

---

### Task 4: `LectureSessionScope.joinUrl`

**Files:**
- Modify: `lib/features/lecture_session/presentation/lecture_session_scope.dart`
- Modify: `test/features/lecture_session/lecture_tts_unavailable_notice_test.dart`
- Modify: `test/features/lecture_session/lecture_session_controls_tts_gate_test.dart`
- Modify: `test/features/lecture_session/lecture_session_notifier_tts_gate_test.dart`

**Interfaces:**
- Consumes: none
- Produces: `LectureSessionScope = ({String sessionId, String linkRecord, String? joinUrl})`; `lectureSessionScope({required sessionId, required linkRecord, String? joinUrl})`

Dart records are structural. Every existing two-field `_scope` literal must add `joinUrl: null` or it will not be a `LectureSessionScope`.

- [ ] **Step 1: Update the typedef and factory**

```dart
typedef LectureSessionScope = ({
  String sessionId,
  String linkRecord,
  String? joinUrl,
});

LectureSessionScope lectureSessionScope({
  required String sessionId,
  required String linkRecord,
  String? joinUrl,
}) =>
    (sessionId: sessionId, linkRecord: linkRecord, joinUrl: joinUrl);
```

- [ ] **Step 2: Fix existing test scope literals**

In each of the three test files, change:

```dart
const _scope = (
  sessionId: '...',
  linkRecord: '...',
);
```

to:

```dart
const _scope = (
  sessionId: '...',
  linkRecord: '...',
  joinUrl: null,
);
```

Keep the existing `sessionId` / `linkRecord` strings unchanged.

- [ ] **Step 3: Analyze / run the three tests**

```bash
dart analyze lib/features/lecture_session/presentation/lecture_session_scope.dart
flutter test \
  test/features/lecture_session/lecture_tts_unavailable_notice_test.dart \
  test/features/lecture_session/lecture_session_controls_tts_gate_test.dart \
  test/features/lecture_session/lecture_session_notifier_tts_gate_test.dart
```

Expected: PASS. If analyzer reports other two-field scope records, add `joinUrl: null` the same way.

---

### Task 5: Pass `joinUrl` and backfill on open

**Files:**
- Modify: `lib/core/util/open_lecture_session.dart`
- Modify: `test/core/util/open_lecture_session_test.dart`

**Interfaces:**
- Consumes: `lectureSessionScope(joinUrl:)`, `SavedLecturesNotifier.setJoinUrlIfMissing`
- Produces: `openLectureSessionFromLinkRecord(..., {String? joinUrl})`; `openLectureSessionFromAppLink` passes the validated app-link string; invalid `joinUrl` is treated as null

- [ ] **Step 1: Write the failing tests**

In `test/core/util/open_lecture_session_test.dart`:

1. On `_BookmarkedLectureNotifier`, add a no-op so existing tests do not hit an uninitialized repository:

```dart
  @override
  Future<bool> setJoinUrlIfMissing(String linkRecord, String joinUrl) async {
    return false;
  }
```

2. Append:

```dart
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
```

- [ ] **Step 2: Run the new tests to verify they fail**

```bash
flutter test test/core/util/open_lecture_session_test.dart --name "joinUrl"
```

Expected: FAIL — `joinUrl` named argument / scope field missing (or scope `joinUrl` is null).

- [ ] **Step 3: Implement open-session plumbing**

In `openLectureSessionFromAppLink`, pass `joinUrl: appLink.trim()`.

In `openLectureSessionFromLinkRecord`, add `String? joinUrl` and resolve it:

```dart
  String? resolvedJoinUrl;
  if (joinUrl != null) {
    final trimmed = joinUrl.trim();
    final uri = Uri.tryParse(trimmed);
    if (uri != null && isLectureViewerAppLink(uri)) {
      resolvedJoinUrl = trimmed;
    }
  }
```

After the 500 check and `deleteLectureSnapshotForLinkRecord`, before `Navigator.push`:

```dart
    if (resolvedJoinUrl != null) {
      await ProviderScope.containerOf(context)
          .read(savedLecturesProvider.notifier)
          .setJoinUrlIfMissing(linkRecord, resolvedJoinUrl);
      if (!context.mounted) return false;
    }

    final popResult = await Navigator.of(context).push<LectureSessionPopResult>(
      MaterialPageRoute<LectureSessionPopResult>(
        builder: (_) => LectureSessionScreen(
          scope: lectureSessionScope(
            sessionId: meetingName,
            linkRecord: linkRecord,
            joinUrl: resolvedJoinUrl,
          ),
        ),
      ),
    );
```

Import `saved_lectures_provider.dart` and `lecture_app_link.dart` if not already imported (`lecture_app_link.dart` is already imported).

- [ ] **Step 4: Run open-session tests**

```bash
flutter test test/core/util/open_lecture_session_test.dart
```

Expected: PASS.

---

### Task 6: Wire QR, Branch, Home, and save-on-exit

**Files:**
- Modify: `lib/features/home/presentation/qr_scan_screen.dart`
- Modify: `lib/app/branch_session_listener.dart`
- Modify: `lib/features/home/presentation/saved_lectures_list.dart`
- Modify: `lib/features/lecture_session/presentation/save_lecture_on_exit.dart`
- Modify: `lib/features/lecture_session/presentation/lecture_session_screen.dart`

**Interfaces:**
- Consumes: `openLectureSessionFromAppLink`, `openLectureSessionFromLinkRecord(joinUrl:)`, `joinUrlFromBranchSession`, `SavedLecturesNotifier.add(joinUrl:)`
- Produces: every live entry path that has a valid lecture app link supplies `joinUrl`; new bookmarks store it

No new test file. Task 2 already covers `add(joinUrl:)`. Task 5 covers Home-style `openLectureSessionFromLinkRecord(joinUrl:)`.

- [ ] **Step 1: QR scan uses `openLectureSessionFromAppLink`**

In `lib/features/home/presentation/qr_scan_screen.dart`, after the URI / host check, drop the extra `linkRecord == null` branch’s separate `FromLinkRecord` call and open with the raw URL:

```dart
    _handling = true;
    final ok = await openLectureSessionFromAppLink(context, raw.trim());
```

Keep the existing invalid-link snackbars. `linkRecordFromAppLinkUri` is no longer required here if `FromAppLink` owns validation; you may delete unused imports (`lecture_app_link.dart` still needed for `isLectureViewerAppLink`).

- [ ] **Step 2: Branch passes `joinUrlFromBranchSession`**

In `lib/app/branch_session_listener.dart`:

```dart
    final sessionName = sessionNameFromBranchSession(data);
    final joinUrl = joinUrlFromBranchSession(data);
    final ok = await openLectureSessionFromLinkRecord(
      nav.context,
      linkRecord,
      sessionName: sessionName,
      joinUrl: joinUrl,
    );
```

- [ ] **Step 3: Home reopen passes `lecture.joinUrl`**

In `lib/features/home/presentation/saved_lectures_list.dart` `_openLecture`:

```dart
    final joined = await openLectureSessionFromLinkRecord(
      context,
      lecture.linkRecord,
      sessionName: lecture.displayName,
      joinUrl: lecture.joinUrl,
    );
```

- [ ] **Step 4: Save-on-exit writes `joinUrl`**

Add `String? joinUrl` to `handleLectureSessionExit` and pass it into `add`:

```dart
Future<bool> handleLectureSessionExit(
  BuildContext context,
  WidgetRef ref, {
  required String linkRecord,
  required String sessionId,
  String? joinUrl,
  bool skipSavePrompt = false,
}) async {
```

```dart
  final ok = await ref.read(savedLecturesProvider.notifier).add(
        displayName: generated,
        linkRecord: linkRecord,
        sessionId: sessionId,
        locale: locale,
        joinUrl: joinUrl,
      );
```

In `lecture_session_screen.dart` `onPopInvokedWithResult`:

```dart
        final shouldPop = await handleLectureSessionExit(
          context,
          ref,
          linkRecord: linkRecord,
          sessionId: sessionId,
          joinUrl: scope.joinUrl,
          skipSavePrompt: _skipSavePromptOnPop,
        );
```

- [ ] **Step 5: Analyze wired files**

```bash
dart analyze \
  lib/features/home/presentation/qr_scan_screen.dart \
  lib/app/branch_session_listener.dart \
  lib/features/home/presentation/saved_lectures_list.dart \
  lib/features/lecture_session/presentation/save_lecture_on_exit.dart \
  lib/features/lecture_session/presentation/lecture_session_screen.dart
```

Expected: no issues.

---

### Task 7: QR dialog and AppBar button

**Files:**
- Modify: `pubspec.yaml` (add `qr_flutter: ^4.1.0` next to `share_plus`)
- Create: `lib/features/lecture_session/presentation/lecture_session_qr_dialog.dart`
- Modify: `lib/features/lecture_session/presentation/lecture_session_screen.dart`
- Test: `test/features/lecture_session/lecture_session_qr_dialog_test.dart`
- Test: `test/core/util/open_lecture_session_test.dart` (AppBar visibility)

**Interfaces:**
- Consumes: `scope.joinUrl`
- Produces: `Future<void> showLectureSessionQrDialog({required BuildContext context, required String joinUrl})`

- [ ] **Step 1: Add dependency**

In `pubspec.yaml` dependencies:

```yaml
  qr_flutter: ^4.1.0
```

```bash
flutter pub get
```

- [ ] **Step 2: Write the failing dialog test**

Create `test/features/lecture_session/lecture_session_qr_dialog_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:lecture_viewer_v3/features/lecture_session/presentation/lecture_session_qr_dialog.dart';

void main() {
  const joinUrl =
      'https://lectureviewer.app.link/x?link_record=lt2srv.iar.kit.edu/mobile/session/foo-lecture';

  testWidgets('shows title, QR, and Close only', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () => showLectureSessionQrDialog(
                  context: context,
                  joinUrl: joinUrl,
                ),
                child: const Text('Open'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Join to view transcription by QR'), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
    expect(find.text('Share QR'), findsNothing);
    expect(find.text('Join to view transcription by Link'), findsNothing);
    expect(find.text(joinUrl), findsNothing);

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });
}
```

- [ ] **Step 3: Run dialog test to verify it fails**

```bash
flutter test test/features/lecture_session/lecture_session_qr_dialog_test.dart
```

Expected: FAIL — library / `showLectureSessionQrDialog` missing.

- [ ] **Step 4: Implement the dialog**

Create `lib/features/lecture_session/presentation/lecture_session_qr_dialog.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

Future<void> showLectureSessionQrDialog({
  required BuildContext context,
  required String joinUrl,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      return AlertDialog(
        title: const Text('Join to view transcription by QR'),
        content: ColoredBox(
          color: Colors.white,
          child: QrImageView(
            data: joinUrl,
            size: 220,
            backgroundColor: Colors.white,
            padding: EdgeInsets.zero,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      );
    },
  );
}
```

- [ ] **Step 5: Run dialog test**

```bash
flutter test test/features/lecture_session/lecture_session_qr_dialog_test.dart
```

Expected: PASS.

- [ ] **Step 6: Write failing AppBar tests**

Append to `test/core/util/open_lecture_session_test.dart`:

```dart
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
```

- [ ] **Step 7: Run AppBar tests to verify they fail**

```bash
flutter test test/core/util/open_lecture_session_test.dart --name "join QR"
```

Expected: FAIL — tooltip not found when `joinUrl` is set.

- [ ] **Step 8: Wire the AppBar button**

In `lecture_session_screen.dart` AppBar `actions`, **left of** `LectureTtsAppBarButton`:

```dart
          actions: [
            if (scope.joinUrl != null)
              IconButton(
                tooltip: 'Show join QR',
                icon: const Icon(Icons.qr_code_2),
                onPressed: () => showLectureSessionQrDialog(
                  context: context,
                  joinUrl: scope.joinUrl!,
                ),
              ),
            LectureTtsAppBarButton(scope: scope),
            IconButton(
```

Import `lecture_session_qr_dialog.dart`.

- [ ] **Step 9: Run AppBar + related tests**

```bash
flutter test \
  test/core/util/open_lecture_session_test.dart \
  test/features/lecture_session/lecture_session_qr_dialog_test.dart
```

Expected: PASS.

- [ ] **Step 10: Regression sweep**

```bash
flutter test \
  test/core/saved_lectures \
  test/core/util/lecture_app_link_test.dart \
  test/core/util/open_lecture_session_test.dart \
  test/features/lecture_session/lecture_session_qr_dialog_test.dart \
  test/features/lecture_session/lecture_tts_unavailable_notice_test.dart \
  test/features/lecture_session/lecture_session_controls_tts_gate_test.dart \
  test/features/lecture_session/lecture_session_notifier_tts_gate_test.dart \
  test/features/home
```

Expected: PASS.

---

## Manual check (after implementation)

- [ ] Scan a valid lecture QR → session AppBar shows QR icon → dialog is QR + Close only.
- [ ] Bookmark the lecture → leave → reopen from Home → QR icon still present and encodes the same URL.
- [ ] Open an old bookmark with no `joinUrl` → no QR icon.
- [ ] Scan that same session again → icon appears; after exit, Home reopen keeps the icon (backfill).
- [ ] Don't save a new session → later join without QR/Branch URL → no icon.
