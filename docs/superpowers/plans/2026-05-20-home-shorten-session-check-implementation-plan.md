# Pre-join Shorten Session Check Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Before opening `LectureSessionScreen`, call `GET https://lecture-translator.kit.edu/webapi/shorten/{meetingName}`; on HTTP 500 show the session-ended dialog and stay put; otherwise skip the join dialog and navigate immediately.

**Architecture:** Injectable `LectureShortenClient` in `lib/core/api/`; orchestration in `open_lecture_session.dart` (loading dialog → check → shared unavailable dialog or push session loop). Delete `join_session_dialog.dart`. Optionally refactor in-session end dialog to shared helper.

**Tech stack:** Flutter 3.10+, `http`, `flutter_riverpod`, existing `lecture_session` feature.

**Spec:** `docs/superpowers/specs/2026-05-20-home-shorten-session-check-design.md`

---

## File map

| Path | Responsibility |
|------|----------------|
| `lib/core/api/lecture_shorten_client.dart` | HTTP GET shorten; returns status or `null` on transport failure |
| `lib/features/lecture_session/presentation/session_unavailable_dialog.dart` | Shared "Session ended" alert |
| `lib/core/util/open_lecture_session.dart` | Loading, check, navigate (replaces join dialog) |
| `lib/features/lecture_session/presentation/join_session_dialog.dart` | **Delete** (logic moved) |
| `lib/features/lecture_session/presentation/lecture_session_screen.dart` | Optional: call shared dialog helper |
| `test/core/api/lecture_shorten_client_test.dart` | Client unit tests with `MockClient` |
| `test/core/util/open_lecture_session_test.dart` | Widget tests with fake client |

---

### Task 1: `LectureShortenClient` — failing tests then implementation

**Files:**
- Create: `lib/core/api/lecture_shorten_client.dart`
- Create: `test/core/api/lecture_shorten_client_test.dart`

- [ ] **Step 1: Write failing tests**

```dart
// test/core/api/lecture_shorten_client_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:lecture_viewer_v3/core/api/lecture_shorten_client.dart';

void main() {
  test('checkShorten returns 500 when server returns 500', () async {
    final client = HttpLectureShortenClient(
      httpClient: MockClient((request) async {
        expect(
          request.url.toString(),
          'https://lecture-translator.kit.edu/webapi/shorten/foo-lecture',
        );
        expect(request.method, 'GET');
        return http.Response('', 500);
      }),
    );

    expect(await client.checkShorten('foo-lecture'), 500);
  });

  test('checkShorten returns 200 when server returns 200', () async {
    final client = HttpLectureShortenClient(
      httpClient: MockClient((_) async => http.Response('ok', 200)),
    );

    expect(await client.checkShorten('foo-lecture'), 200);
  });

  test('checkShorten encodes meeting name in path', () async {
    final client = HttpLectureShortenClient(
      httpClient: MockClient((request) async {
        expect(
          request.url.path,
          '/webapi/shorten/foo%2Fbar',
        );
        return http.Response('', 200);
      }),
    );

    await client.checkShorten('foo/bar');
  });

  test('checkShorten returns null on network failure', () async {
    final client = HttpLectureShortenClient(
      httpClient: MockClient((_) async {
        throw Exception('connection failed');
      }),
    );

    expect(await client.checkShorten('foo'), isNull);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd /Users/truong-d/Documents/code/lecture_viewer_v3 && flutter test test/core/api/lecture_shorten_client_test.dart
```

Expected: FAIL — `lecture_shorten_client.dart` not found.

- [ ] **Step 3: Implement client** (abstract type for test fakes)

```dart
// lib/core/api/lecture_shorten_client.dart
import 'package:http/http.dart' as http;

const _shortenApiOrigin = 'https://lecture-translator.kit.edu';
const _shortenTimeout = Duration(seconds: 20);

/// Pre-join availability probe. Returns HTTP status, or null on transport failure.
abstract class LectureShortenClient {
  Future<int?> checkShorten(String meetingName);
}

class HttpLectureShortenClient implements LectureShortenClient {
  HttpLectureShortenClient({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  @override
  Future<int?> checkShorten(String meetingName) async {
    final encoded = Uri.encodeComponent(meetingName);
    final uri = Uri.parse('$_shortenApiOrigin/webapi/shorten/$encoded');
    try {
      final response = await _httpClient
          .get(uri)
          .timeout(_shortenTimeout);
      return response.statusCode;
    } catch (_) {
      return null;
    }
  }
}

final LectureShortenClient defaultLectureShortenClient =
    HttpLectureShortenClient();
```

Update tests to use `HttpLectureShortenClient(httpClient: MockClient(...))` instead of `LectureShortenClient(...)`.

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd /Users/truong-d/Documents/code/lecture_viewer_v3 && flutter test test/core/api/lecture_shorten_client_test.dart
```

Expected: All PASS.

- [ ] **Step 5: Commit**

```bash
cd /Users/truong-d/Documents/code/lecture_viewer_v3
git add lib/core/api/lecture_shorten_client.dart test/core/api/lecture_shorten_client_test.dart
git commit -m "feat: add lecture shorten pre-join HTTP client"
```

---

### Task 2: Shared session-unavailable dialog

**Files:**
- Create: `lib/features/lecture_session/presentation/session_unavailable_dialog.dart`
- Modify: `lib/features/lecture_session/presentation/lecture_session_screen.dart`

- [ ] **Step 1: Add dialog helper**

```dart
// lib/features/lecture_session/presentation/session_unavailable_dialog.dart
import 'package:flutter/material.dart';

/// Session cannot be joined (shorten 500 or WebSocket session_end).
Future<void> showSessionUnavailableDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: const Text('Session ended'),
      content: const Text('This session is no longer available.'),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}
```

- [ ] **Step 2: Refactor `lecture_session_screen.dart`** — replace inline `_showSessionEndedDialog` body with:

```dart
import 'package:lecture_viewer_v3/features/lecture_session/presentation/session_unavailable_dialog.dart';

// inside _showSessionEndedDialog:
    await showSessionUnavailableDialog(context);
    if (!mounted) return;
    await _popToHome(skipSavePrompt: true);
```

Remove the duplicate `AlertDialog` widget code from `_showSessionEndedDialog` (keep the `_sessionEndDialogShown` guard).

- [ ] **Step 3: Analyze**

```bash
cd /Users/truong-d/Documents/code/lecture_viewer_v3 && dart analyze lib/features/lecture_session/presentation/session_unavailable_dialog.dart lib/features/lecture_session/presentation/lecture_session_screen.dart
```

Expected: no issues.

- [ ] **Step 4: Commit**

```bash
cd /Users/truong-d/Documents/code/lecture_viewer_v3
git add lib/features/lecture_session/presentation/session_unavailable_dialog.dart \
  lib/features/lecture_session/presentation/lecture_session_screen.dart
git commit -m "feat: shared session unavailable dialog"
```

---

### Task 3: Rewrite `open_lecture_session.dart` and remove join dialog

**Files:**
- Modify: `lib/core/util/open_lecture_session.dart`
- Delete: `lib/features/lecture_session/presentation/join_session_dialog.dart`

- [ ] **Step 1: Replace `open_lecture_session.dart` implementation**

```dart
import 'package:flutter/material.dart';

import 'package:lecture_viewer_v3/core/api/lecture_shorten_client.dart';
import 'package:lecture_viewer_v3/core/lecture_snapshot/lecture_snapshot_provider.dart';
import 'package:lecture_viewer_v3/core/util/lecture_app_link.dart';
import 'package:lecture_viewer_v3/features/lecture_session/presentation/lecture_session_pop_result.dart';
import 'package:lecture_viewer_v3/features/lecture_session/presentation/lecture_session_scope.dart';
import 'package:lecture_viewer_v3/features/lecture_session/presentation/lecture_session_screen.dart';
import 'package:lecture_viewer_v3/features/lecture_session/presentation/session_unavailable_dialog.dart';

Future<void> _showJoinLoadingDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => const AlertDialog(
      content: Row(
        children: [
          CircularProgressIndicator(),
          SizedBox(width: 24),
          Expanded(child: Text('Checking session…')),
        ],
      ),
    ),
  );
}

Future<int?> _runShortenCheck(
  BuildContext context,
  String meetingName, {
  required LectureShortenClient shortenClient,
}) async {
  await _showJoinLoadingDialog(context);
  final status = await shortenClient.checkShorten(meetingName);
  if (context.mounted) {
    Navigator.of(context, rootNavigator: true).pop();
  }
  return status;
}

Future<bool> _openLectureSessionScreen(
  BuildContext context, {
  required String meetingName,
  required String linkRecord,
}) async {
  while (context.mounted) {
    await deleteLectureSnapshotForLinkRecord(linkRecord);
    if (!context.mounted) return false;
    final popResult = await Navigator.of(context).push<LectureSessionPopResult>(
      MaterialPageRoute<LectureSessionPopResult>(
        builder: (_) => LectureSessionScreen(
          scope: lectureSessionScope(
            sessionId: meetingName,
            linkRecord: linkRecord,
          ),
        ),
      ),
    );
    if (popResult == LectureSessionPopResult.retryJoin) continue;
    return true;
  }
  return false;
}

/// Validates a lectureviewer.app.link URL and opens session after shorten check.
Future<bool> openLectureSessionFromAppLink(
  BuildContext context,
  String appLink,
) async {
  final uri = Uri.tryParse(appLink.trim());
  if (uri == null || !isLectureViewerAppLink(uri)) {
    return false;
  }
  final linkRecord = linkRecordFromAppLinkUri(uri);
  if (linkRecord == null) {
    return false;
  }
  return openLectureSessionFromLinkRecord(
    context,
    linkRecord,
    sessionName: sessionNameFromAppLinkUri(uri),
  );
}

/// Validates [linkRecord], runs shorten check, then opens in-app meeting view.
Future<bool> openLectureSessionFromLinkRecord(
  BuildContext context,
  String linkRecord, {
  String? sessionName,
  LectureShortenClient? shortenClient,
}) async {
  final meetingName = meetingNameFromLinkRecord(linkRecord);
  if (meetingName == null || meetingName.isEmpty) {
    return false;
  }

  final client = shortenClient ?? defaultLectureShortenClient;

  while (context.mounted) {
    final status = await _runShortenCheck(
      context,
      meetingName,
      shortenClient: client,
    );
    if (!context.mounted) return false;

    if (status == 500) {
      await showSessionUnavailableDialog(context);
      return false;
    }

    final joined = await _openLectureSessionScreen(
      context,
      meetingName: meetingName,
      linkRecord: linkRecord,
    );
    if (!context.mounted) return false;
    if (joined) return true;
    // retryJoin: loop runs shorten check again before next push
  }
  return false;
}
```

Note: Remove unused `_resolveJoinSessionName` and `sessionName` parameter only if nothing reads it — **keep `sessionName` in the signature** for API stability (callers pass `lecture.displayName` from home); it is unused after join dialog removal (acceptable; analyzer may warn — prefix with `// ignore` or use `sessionName` in a debug assert only; simplest: keep parameter unnamed usage with `// ignore: unused_element` on parameter via comment or reference in doc comment). Prefer:

```dart
  // sessionName kept for API stability; was used by removed join dialog.
  assert(sessionName == null || sessionName.isNotEmpty || true);
```

Or just leave parameter and add `// ignore: unused_element` on the function — in Dart 3, unused optional params don't always warn. Home still passes `sessionName: lecture.displayName` — no change needed at call sites.

- [ ] **Step 2: Delete join dialog file**

```bash
rm /Users/truong-d/Documents/code/lecture_viewer_v3/lib/features/lecture_session/presentation/join_session_dialog.dart
```

Confirm no other imports:

```bash
cd /Users/truong-d/Documents/code/lecture_viewer_v3 && rg join_session_dialog
```

Expected: no `lib/` imports (docs may still mention it).

- [ ] **Step 3: Analyze project**

```bash
cd /Users/truong-d/Documents/code/lecture_viewer_v3 && dart analyze lib/core/util/open_lecture_session.dart
```

Expected: no errors.

- [ ] **Step 4: Commit**

```bash
cd /Users/truong-d/Documents/code/lecture_viewer_v3
git add lib/core/util/open_lecture_session.dart
git add -u lib/features/lecture_session/presentation/join_session_dialog.dart
git commit -m "feat: pre-join shorten check replaces join dialog"
```

---

### Task 4: Widget tests for `open_lecture_session`

**Files:**
- Create: `test/core/util/open_lecture_session_test.dart`

- [ ] **Step 1: Write widget tests**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lecture_viewer_v3/core/api/lecture_shorten_client.dart';
import 'package:lecture_viewer_v3/core/providers/core_providers.dart';
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
  Future<int?> checkShorten(String meetingName) async => _status;
}

class _TestLectureSessionNotifier extends LectureSessionNotifier {
  @override
  LectureSessionState build(LectureSessionScope scope) {
    return LectureSessionState(
      sessionId: scope.sessionId,
      hasReceivedInfo: true,
    );
  }
}

void main() {
  const linkRecord = 'lt2srv.iar.kit.edu/mobile/session/foo-lecture';

  testWidgets('shorten 500 shows session ended and does not push session',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => openLectureSessionFromLinkRecord(
                  context,
                  linkRecord,
                  shortenClient: _FakeShortenClient(500),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Session ended'), findsOneWidget);
    expect(find.text('This session is no longer available.'), findsOneWidget);
    expect(find.text('Join event'), findsNothing);
    expect(find.byType(LectureSessionScreen), findsNothing);
  });

  testWidgets('shorten 200 skips join dialog and pushes session screen',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          lectureSessionProvider.overrideWith(_TestLectureSessionNotifier.new),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => openLectureSessionFromLinkRecord(
                  context,
                  linkRecord,
                  shortenClient: _FakeShortenClient(200),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Join event'), findsNothing);
    expect(find.byType(LectureSessionScreen), findsOneWidget);
    expect(find.text('foo-lecture'), findsOneWidget); // app bar title
  });

  testWidgets('invalid linkRecord returns false without dialog', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                final ok = await openLectureSessionFromLinkRecord(
                  context,
                  '',
                  shortenClient: _FakeShortenClient(500),
                );
                expect(ok, isFalse);
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Session ended'), findsNothing);
  });
}
```

- [ ] **Step 2: Run widget tests**

```bash
cd /Users/truong-d/Documents/code/lecture_viewer_v3 && flutter test test/core/util/open_lecture_session_test.dart
```

Expected: All PASS.

- [ ] **Step 3: Run full test suite**

```bash
cd /Users/truong-d/Documents/code/lecture_viewer_v3 && flutter test
```

Expected: PASS (fix any tests that referenced join dialog text).

- [ ] **Step 4: Commit**

```bash
cd /Users/truong-d/Documents/code/lecture_viewer_v3
git add test/core/util/open_lecture_session_test.dart
git commit -m "test: cover pre-join shorten open flow"
```

---

### Task 5: Final verification

- [ ] **Step 1: Analyzer**

```bash
cd /Users/truong-d/Documents/code/lecture_viewer_v3 && dart analyze
```

Expected: no issues.

- [ ] **Step 2: Manual checks** (from spec)

- [ ] Home: tap saved lecture → loading → meeting view (no join dialog)
- [ ] Home: ended session (API 500) → Session ended dialog → stay on home
- [ ] QR / Branch: same behavior
- [ ] Airplane mode during check → still opens meeting view
- [ ] Server error **Retry** on session screen → loading + shorten runs again

---

## Spec coverage (self-review)

| Spec requirement | Task |
|------------------|------|
| GET shorten with `meetingNameFromLinkRecord` | Task 1, 3 |
| 500 → session ended dialog, stay | Task 2, 3, 4 |
| Non-500 / null → open session | Task 1, 3, 4 |
| No join dialog all paths | Task 3 |
| Blocking loading all paths | Task 3 |
| Fixed `lecture-translator.kit.edu` host | Task 1 |
| retryJoin re-runs shorten | Task 3 (`while` loop) |
| Delete snapshot before push | Task 3 (`_openLectureSessionScreen`) |
| Shared dialog with in-session end | Task 2 |
| Call sites unchanged | Task 3 (signatures stable) |

---

## Manual test link example

`link_record`: `lt2srv.iar.kit.edu/mobile/session/tkq1221114001-lecture`  
→ `meetingName`: `tkq1221114001-lecture`  
→ `GET https://lecture-translator.kit.edu/webapi/shorten/tkq1221114001-lecture`
