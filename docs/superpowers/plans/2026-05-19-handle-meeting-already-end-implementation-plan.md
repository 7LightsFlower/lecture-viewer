# Handle WebSocket `session_end` Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** When the lecture-session WebSocket sends `data.status == "session_end"`, show a dialog and return the user home on OK without the save prompt or clearing history.

**Architecture:** Parse `session_end` into a dedicated inbound type (`LectureInboundWsSessionEnd`), set `sessionExitRequested` on session state in the notifier (after stopping the WebSocket), and listen from `LectureSessionScreen` to show a blocking dialog and pop with `skipSavePrompt`.

**Tech stack:** Flutter 3.10+, `flutter_riverpod`, existing `lecture_session` feature and `lecture_inbound_parser`.

**Spec:** `docs/superpowers/specs/2026-05-19-handle-meeting-already-end-design.md`

---

## File map

| Path | Responsibility |
|------|----------------|
| `lib/features/lecture_session/data/inbound/lecture_inbound_message.dart` | Add `LectureInboundWsSessionEnd` sealed subtype |
| `lib/features/lecture_session/data/inbound/lecture_inbound_parser.dart` | Branch on `data.status == 'session_end'` before metadata/END |
| `test/features/lecture_session/lecture_inbound_parser_test.dart` | Parser test for README sample payload |
| `lib/features/lecture_session/presentation/lecture_session_state.dart` | `sessionExitRequested` field + `copyWith` |
| `lib/features/lecture_session/presentation/providers/lecture_session_notifier.dart` | Handle `LectureInboundWsSessionEnd`, dispose client |
| `lib/features/lecture_session/presentation/save_lecture_on_exit.dart` | `skipSavePrompt` parameter |
| `lib/features/lecture_session/presentation/lecture_session_screen.dart` | `ConsumerStatefulWidget`, `ref.listen`, dialog, pop |

---

### Task 1: Inbound message type

**Files:**
- Modify: `lib/features/lecture_session/data/inbound/lecture_inbound_message.dart`

- [ ] **Step 1:** Add the new sealed subtype after `LectureInboundSessionEnd`:

```dart
/// WebSocket reports the session is closed (`data.status == 'session_end'`).
final class LectureInboundWsSessionEnd extends LectureInboundMessage {
  const LectureInboundWsSessionEnd({this.reason});

  final String? reason;
}
```

- [ ] **Step 2:** Run analyzer:

```bash
cd /Users/truong-d/Documents/code/lecture_viewer_v3 && dart analyze lib/features/lecture_session/data/inbound/lecture_inbound_message.dart
```

Expected: no errors (switch exhaustiveness warnings may appear until Task 3 — that is OK for now).

- [ ] **Step 3: Commit**

```bash
cd /Users/truong-d/Documents/code/lecture_viewer_v3
git add lib/features/lecture_session/data/inbound/lecture_inbound_message.dart
git commit -m "feat(session): add LectureInboundWsSessionEnd message type"
```

---

### Task 2: Parser — failing test then implementation

**Files:**
- Modify: `test/features/lecture_session/lecture_inbound_parser_test.dart`
- Modify: `lib/features/lecture_session/data/inbound/lecture_inbound_parser.dart`

- [ ] **Step 1: Write the failing test** (append to `lecture_inbound_parser_test.dart`):

```dart
  test('parses session_end info as LectureInboundWsSessionEnd', () {
    const json = '''
{
  "message": "connected",
  "status": 200,
  "data": {
    "status": "session_end",
    "reason": "session_already_over"
  },
  "objectType": "info"
}
''';

    final message = parseLectureInbound(json);
    expect(message, isA<LectureInboundWsSessionEnd>());
    final end = message as LectureInboundWsSessionEnd;
    expect(end.reason, 'session_already_over');
  });
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd /Users/truong-d/Documents/code/lecture_viewer_v3 && flutter test test/features/lecture_session/lecture_inbound_parser_test.dart --name "parses session_end"
```

Expected: FAIL (message is not `LectureInboundWsSessionEnd`, or type missing).

- [ ] **Step 3: Implement parser branch** in `_parseInfo`, **before** the `END` check and language-metadata parsing:

```dart
  if (data['status'] == 'session_end') {
    return LectureInboundWsSessionEnd(
      reason: data['reason']?.toString(),
    );
  }

  if (data['status'] == 'END') {
    return LectureInboundSessionEnd(
      audioUrl: data['audioUrl']?.toString(),
    );
  }
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd /Users/truong-d/Documents/code/lecture_viewer_v3 && flutter test test/features/lecture_session/lecture_inbound_parser_test.dart
```

Expected: all tests PASS.

- [ ] **Step 5: Commit**

```bash
cd /Users/truong-d/Documents/code/lecture_viewer_v3
git add lib/features/lecture_session/data/inbound/lecture_inbound_parser.dart \
  test/features/lecture_session/lecture_inbound_parser_test.dart
git commit -m "feat(session): parse WebSocket session_end info messages"
```

---

### Task 3: Session state flag

**Files:**
- Modify: `lib/features/lecture_session/presentation/lecture_session_state.dart`

- [ ] **Step 1:** Add field to constructor and class:

```dart
    this.sessionExitRequested = false,
```

```dart
  final bool sessionExitRequested;
```

- [ ] **Step 2:** Extend `copyWith`:

```dart
    bool? sessionExitRequested,
```

```dart
      sessionExitRequested:
          sessionExitRequested ?? this.sessionExitRequested,
```

- [ ] **Step 3: Run analyzer**

```bash
cd /Users/truong-d/Documents/code/lecture_viewer_v3 && dart analyze lib/features/lecture_session/presentation/lecture_session_state.dart
```

Expected: no errors.

- [ ] **Step 4: Commit**

```bash
cd /Users/truong-d/Documents/code/lecture_viewer_v3
git add lib/features/lecture_session/presentation/lecture_session_state.dart
git commit -m "feat(session): add sessionExitRequested to session state"
```

---

### Task 4: Notifier handles `session_end`

**Files:**
- Modify: `lib/features/lecture_session/presentation/providers/lecture_session_notifier.dart`

- [ ] **Step 1:** Add a case in `_onRawMessage` switch (after `LectureInboundSessionEnd` or before `LectureInboundIgnored`):

```dart
      case LectureInboundWsSessionEnd(:final reason):
        lectureSessionDebugSessionEnd(
          sessionId: state.sessionId,
          audioUrl: reason,
        );
        if (state.sessionExitRequested) break;
        unawaited(_handleWsSessionEnd());
```

- [ ] **Step 2:** Add private handler:

```dart
  Future<void> _handleWsSessionEnd() async {
    await _disposeClient();
    if (!ref.mounted) return;
    state = state.copyWith(sessionExitRequested: true);
  }
```

Note: `lectureSessionDebugSessionEnd` currently takes `audioUrl`; passing `reason` as the second arg is acceptable for debug logging only. Do not rename debug helpers in this task unless the analyzer complains.

- [ ] **Step 3: Ensure `LectureInboundSessionEnd` case is unchanged** (log only, no `sessionExitRequested`).

- [ ] **Step 4: Run analyzer on notifier**

```bash
cd /Users/truong-d/Documents/code/lecture_viewer_v3 && dart analyze lib/features/lecture_session/presentation/providers/lecture_session_notifier.dart
```

Expected: no errors; switch must be exhaustive.

- [ ] **Step 5: Commit**

```bash
cd /Users/truong-d/Documents/code/lecture_viewer_v3
git add lib/features/lecture_session/presentation/providers/lecture_session_notifier.dart
git commit -m "feat(session): request exit when WebSocket sends session_end"
```

---

### Task 5: Skip save prompt on forced exit

**Files:**
- Modify: `lib/features/lecture_session/presentation/save_lecture_on_exit.dart`

- [ ] **Step 1:** Add parameter to `handleLectureSessionExit`:

```dart
Future<bool> handleLectureSessionExit(
  BuildContext context,
  WidgetRef ref, {
  required String linkRecord,
  required String sessionId,
  bool skipSavePrompt = false,
}) async {
  if (skipSavePrompt) return true;
  if (ref.read(savedLecturesProvider.notifier).containsLinkRecord(linkRecord)) {
    return true;
  }
  // ... rest unchanged
```

- [ ] **Step 2: Commit**

```bash
cd /Users/truong-d/Documents/code/lecture_viewer_v3
git add lib/features/lecture_session/presentation/save_lecture_on_exit.dart
git commit -m "feat(session): allow skipping save prompt on session_end exit"
```

---

### Task 6: Session screen dialog and navigation

**Files:**
- Modify: `lib/features/lecture_session/presentation/lecture_session_screen.dart`

- [ ] **Step 1:** Change `LectureSessionScreen` from `ConsumerWidget` to `ConsumerStatefulWidget`:

```dart
class LectureSessionScreen extends ConsumerStatefulWidget {
  const LectureSessionScreen({
    required this.scope,
    super.key,
  });

  final LectureSessionScope scope;

  @override
  ConsumerState<LectureSessionScreen> createState() =>
      _LectureSessionScreenState();
}

class _LectureSessionScreenState extends ConsumerState<LectureSessionScreen> {
  bool _sessionEndDialogShown = false;
  bool _skipSavePromptOnPop = false;

  LectureSessionScope get scope => widget.scope;
  String get sessionId => scope.sessionId;
  String get linkRecord => scope.linkRecord;

  Future<void> _popToHome({required bool skipSavePrompt}) async {
    _skipSavePromptOnPop = skipSavePrompt;
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _showSessionEndedDialog() async {
    if (_sessionEndDialogShown || !mounted) return;
    _sessionEndDialogShown = true;
    await showDialog<void>(
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
    if (!mounted) return;
    await _popToHome(skipSavePrompt: true);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(
      lectureSessionProvider(scope).select((s) => s.sessionExitRequested),
      (previous, next) {
        if (next && previous != true) {
          unawaited(_showSessionEndedDialog());
        }
      },
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await handleLectureSessionExit(
          context,
          ref,
          linkRecord: linkRecord,
          sessionId: sessionId,
          skipSavePrompt: _skipSavePromptOnPop,
        );
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        // ... keep existing Scaffold body unchanged; use scope/sessionId/linkRecord from getters
```

- [ ] **Step 2:** Update child widgets that referenced `scope` on the widget — they now use `scope` from state (`_LectureSessionTranscriptBody(scope: scope)`, etc.). No logic changes in `_LectureSessionErrorBanner` / `_LectureSessionTranscriptBody`.

- [ ] **Step 3: Run analyzer**

```bash
cd /Users/truong-d/Documents/code/lecture_viewer_v3 && dart analyze lib/features/lecture_session/presentation/lecture_session_screen.dart
```

Expected: no errors.

- [ ] **Step 4: Run full lecture_session tests**

```bash
cd /Users/truong-d/Documents/code/lecture_viewer_v3 && flutter test test/features/lecture_session/
```

Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
cd /Users/truong-d/Documents/code/lecture_viewer_v3
git add lib/features/lecture_session/presentation/lecture_session_screen.dart
git commit -m "feat(session): show dialog and return home on session_end"
```

---

### Task 7: Manual verification

- [ ] **Step 1:** Run the app on a device/simulator.

- [ ] **Step 2:** Join a meeting that is already over (or mock WebSocket to send the README `session_end` payload).

- [ ] **Step 3:** Confirm:
  - Dialog appears with title **Session ended** and body **This session is no longer available.**
  - Tapping outside does not dismiss the dialog.
  - **OK** returns to home without **Save lecture?** prompt.
  - Saved lectures list and any existing snapshot for other sessions are unchanged.

- [ ] **Step 4:** Confirm live session with `data.status == 'END'` still does **not** show this dialog (out of scope; debug log only).

---

## Spec coverage checklist

| Spec requirement | Task |
|------------------|------|
| Parse any `session_end` | Task 2 |
| Distinct type from live `END` | Task 1, 2 |
| `sessionExitRequested` + dispose WS | Task 3, 4 |
| Dialog copy | Task 6 |
| Skip save prompt | Task 5, 6 |
| Do not clear history | No delete/clear calls in Tasks 4–6 |
| Live `END` unchanged | Task 4 (explicit) |
| Parser test | Task 2 |

---

## Execution handoff

Plan complete and saved to `docs/superpowers/plans/2026-05-19-handle-meeting-already-end-implementation-plan.md`.

**Two execution options:**

1. **Subagent-Driven (recommended)** — fresh subagent per task, review between tasks  
2. **Inline Execution** — implement tasks in this session with checkpoints

Which approach do you want?
