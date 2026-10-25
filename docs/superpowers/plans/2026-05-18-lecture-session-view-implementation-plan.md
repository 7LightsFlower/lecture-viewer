# Lecture Session View Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extract shared transcript/TTS UI into `lecture_common`, rewire `app_2way_v3` to use it, then build the in-app lecture meeting view in `lecture_viewer_v3` (join modal, WebSocket, controls, live transcript) per `docs/superpowers/specs/2026-05-18-lecture-session-view-design.md`.

**Architecture:** Three repos/paths: `lecture_common` (shared models, reducer, `TranslationResultTranscriptView`, `TranslationTtsTransport`), `app_2way_v3` (thin WS/inbound + existing session notifier; imports package), `lecture_viewer_v3` (lecture-session feature with `mt`/`postproduction` router, receive-only WS, no TTS UI). Implement **package first**, then 2-way migration, then viewer.

**Tech stack:** Flutter 3.10+, `lecture_common` (path dep), `flutter_riverpod`, `web_socket_channel`, `shared_preferences`, existing Branch/QR stack in viewer.

**Spec:** `docs/superpowers/specs/2026-05-18-lecture-session-view-design.md`

---

## File map

### `lecture_common/` (new / moved)

| Path | Responsibility |
|------|----------------|
| `lib/lecture_common.dart` | Barrel exports |
| `lib/transcript/data/transcript_*.dart` | Bucket, paragraph, segment, speaker label |
| `lib/transcript/domain/transcript_text_event.dart` | Neutral text event (was `MtTextEvent`) |
| `lib/transcript/domain/transcript_sender_detail.dart` | Speaker fields (was `SenderDetailParsed`) |
| `lib/transcript/domain/transcript_reducer.dart` | `applyTranscriptTextEvent` |
| `lib/transcript/domain/transcript_display_format.dart` | Spacing / partial helpers |
| `lib/transcript/domain/session_transcript_state.dart` | `Map<String, TranscriptBucket>` |
| `lib/transcript/domain/translation_text_compound_id.dart` | Compound id helper |
| `lib/transcript/presentation/transcript_inline_format.dart` | `paragraphInlineSpans`, `oneLineHeight` |
| `lib/transcript/presentation/translation_result_transcript_view.dart` | Scrollable transcript widget |
| `lib/tts/tts_pane_snapshot.dart` | TTS UI snapshot |
| `lib/tts/tts_slider_utils.dart` | Slider max seconds |
| `lib/tts/presentation/translation_tts_transport.dart` | Play/seek control |
| `test/transcript/transcript_reducer_test.dart` | Reducer tests (migrated) |
| `test/transcript/transcript_json_roundtrip_test.dart` | JSON roundtrip (migrated) |
| `test/tts/translation_tts_transport_test.dart` | Widget test (migrated) |

### `app_2way_v3/` (modify)

| Path | Responsibility |
|------|----------------|
| `pubspec.yaml` | `lecture_common` path dependency |
| `lib/features/translation_session/data/websocket/mt_text_event.dart` | **Delete** → typedef export file or import package |
| `lib/features/translation_session/ui/translation_result_panel.dart` | Import package; keep toolbar + panel shell |
| Other transcript/TTS paths listed in spec | **Delete** after rewire |

### `lecture_viewer_v3/` (create / modify)

| Path | Responsibility |
|------|----------------|
| `pubspec.yaml` | `lecture_common`, `web_socket_channel` |
| `lib/core/util/lecture_app_link.dart` | `meetingNameFromLinkRecord` |
| `lib/core/util/lecture_ws_url.dart` | `wss://` URL from `ApiEnvironment` |
| `lib/core/providers/app_settings_notifier.dart` | `textScale` persistence |
| `lib/features/lecture_session/domain/transcript/lecture_transcript_router.dart` | mt vs postproduction routing |
| `lib/features/lecture_session/domain/transcript/lecture_bucket_key.dart` | `language|rawSender` key |
| `lib/features/lecture_session/data/inbound/lecture_inbound_parser.dart` | `info`, `texts` → events |
| `lib/features/lecture_session/data/websocket/lecture_session_websocket_client.dart` | Receive-only WS |
| `lib/features/lecture_session/presentation/providers/lecture_session_notifier.dart` | State, backlog batching |
| `lib/features/lecture_session/presentation/join_session_dialog.dart` | Join modal |
| `lib/features/lecture_session/presentation/lecture_session_controls.dart` | Language, shortening, font |
| `lib/features/lecture_session/presentation/lecture_session_screen.dart` | Meeting UI |
| `lib/features/home/presentation/qr_scan_screen.dart` | Join flow (no browser) |
| `lib/app/branch_session_listener.dart` | Join flow (no browser) |

---

## Phase 1 — `lecture_common` package

### Task 1: Package scaffold

**Files:**
- Modify: `lecture_common/pubspec.yaml`
- Delete: `lecture_common/lib/lecture_common.dart` (placeholder)
- Delete: `lecture_common/test/lecture_common_test.dart` (placeholder)

- [ ] **Step 1:** Set `pubspec.yaml`:

```yaml
name: lecture_common
description: Shared transcript display and TTS transport for lecture apps.
version: 0.1.0
publish_to: 'none'

environment:
  sdk: ^3.10.1
  flutter: ">=3.10.0"

dependencies:
  flutter:
    sdk: flutter

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0
```

- [ ] **Step 2:** Run from `lecture_common/`:

```bash
cd /Users/truong-d/Documents/code/lecture_common && flutter pub get
```

Expected: exit 0.

- [ ] **Step 3: Commit** (`lecture_common` repo)

```bash
git add pubspec.yaml pubspec.lock
git commit -m "chore: scaffold lecture_common for shared transcript UI"
```

---

### Task 2: Transcript data models

**Files:**
- Create: `lecture_common/lib/transcript/data/*.dart` (copy from `app_2way_v3/.../data/transcript/`)
- Create: `lecture_common/test/transcript/transcript_json_roundtrip_test.dart`

- [ ] **Step 1:** Copy unchanged (update imports to `package:lecture_common/...`):

- `transcript_segment.dart`
- `transcript_paragraph.dart`
- `speaker_label_state.dart`
- `transcript_bucket.dart`

- [ ] **Step 2:** Copy test `app_2way_v3/test/.../transcript_json_roundtrip_test.dart` → `lecture_common/test/transcript/`, fix imports.

- [ ] **Step 3:** Run:

```bash
cd /Users/truong-d/Documents/code/lecture_common && flutter test test/transcript/transcript_json_roundtrip_test.dart
```

Expected: All tests passed.

- [ ] **Step 4: Commit**

```bash
git add lib/transcript/data test/transcript
git commit -m "feat(common): add transcript data models and JSON roundtrip tests"
```

---

### Task 3: Text event types

**Files:**
- Create: `lecture_common/lib/transcript/domain/transcript_sender_detail.dart`
- Create: `lecture_common/lib/transcript/domain/transcript_text_event.dart`
- Create: `lecture_common/lib/transcript/domain/translation_text_compound_id.dart`

- [ ] **Step 1:** `transcript_sender_detail.dart`:

```dart
import 'package:flutter/foundation.dart';

@immutable
class TranscriptSenderDetail {
  const TranscriptSenderDetail({
    required this.speakerName,
    required this.isShowSpeakerName,
  });

  final String speakerName;
  final bool isShowSpeakerName;
}
```

- [ ] **Step 2:** `transcript_text_event.dart`:

```dart
import 'package:flutter/foundation.dart';
import 'transcript_sender_detail.dart';

@immutable
class TranscriptTextEvent {
  const TranscriptTextEvent({
    required this.text,
    required this.isFinal,
    required this.textId,
    required this.sender,
    required this.rawSender,
    required this.isEndParagraph,
    required this.senderDetail,
  });

  final String text;
  final bool isFinal;
  final String textId;
  final String sender;
  final String rawSender;
  final bool isEndParagraph;
  final TranscriptSenderDetail senderDetail;
}
```

- [ ] **Step 3:** Copy `translation_text_compound_id.dart` from app_2way; only package-import paths change.

- [ ] **Step 4: Commit**

```bash
git add lib/transcript/domain
git commit -m "feat(common): add TranscriptTextEvent and sender detail types"
```

---

### Task 4: Transcript reducer (TDD migrate)

**Files:**
- Create: `lecture_common/lib/transcript/domain/transcript_reducer.dart`
- Create: `lecture_common/test/transcript/transcript_reducer_test.dart`

- [ ] **Step 1:** Copy `transcript_reducer.dart`; rename `applyMtTextEvent` → `applyTranscriptTextEvent`, `MtTextEvent` → `TranscriptTextEvent`, `SenderDetailParsed` → `TranscriptSenderDetail`.

- [ ] **Step 2:** Copy `transcript_reducer_test.dart`; update imports and helper:

```dart
import 'package:lecture_common/transcript/domain/transcript_reducer.dart';
import 'package:lecture_common/transcript/domain/transcript_text_event.dart';
// ...

TranscriptTextEvent ev({ /* same fields */ }) {
  return TranscriptTextEvent(
    // ...
    senderDetail: TranscriptSenderDetail(
      speakerName: speakerName,
      isShowSpeakerName: showSpeaker,
    ),
  );
}

// replace applyMtTextEvent → applyTranscriptTextEvent
```

- [ ] **Step 3:** Run:

```bash
cd /Users/truong-d/Documents/code/lecture_common && flutter test test/transcript/transcript_reducer_test.dart
```

Expected: All tests passed.

- [ ] **Step 4: Commit**

```bash
git add lib/transcript/domain/transcript_reducer.dart test/transcript/transcript_reducer_test.dart
git commit -m "feat(common): add applyTranscriptTextEvent reducer with tests"
```

---

### Task 5: Display format and session state

**Files:**
- Create: `lecture_common/lib/transcript/domain/transcript_display_format.dart`
- Create: `lecture_common/lib/transcript/domain/session_transcript_state.dart`

- [ ] **Step 1:** Copy `transcript_display_format.dart` (import `TranscriptBucket` from package).

- [ ] **Step 2:** Copy `session_transcript_state.dart`; rename `applyMt` → `applyToBucket` (or keep `applyMt` as alias calling same reducer):

```dart
SessionTranscriptState applyToBucket({
  required String bucketKey,
  required TranscriptBucket Function(TranscriptBucket bucket) apply,
}) {
  final previous = buckets[bucketKey] ?? TranscriptBucket.initial();
  final next = apply(previous);
  return SessionTranscriptState(buckets: {...buckets, bucketKey: next});
}
```

- [ ] **Step 3: Commit**

```bash
git add lib/transcript/domain/transcript_display_format.dart lib/transcript/domain/session_transcript_state.dart
git commit -m "feat(common): add display format helpers and session transcript state"
```

---

### Task 6: Transcript UI widgets

**Files:**
- Create: `lecture_common/lib/transcript/presentation/transcript_inline_format.dart`
- Create: `lecture_common/lib/transcript/presentation/translation_result_transcript_view.dart`

- [ ] **Step 1:** Extract from `translation_result_panel.dart` into `transcript_inline_format.dart`:

```dart
class TranscriptInlineFormat {
  TranscriptInlineFormat._();

  static double oneLineHeight(TextStyle? style) { /* copy from TranslationResultPanel */ }

  static List<InlineSpan> paragraphInlineSpans({
    required TranscriptBucket activeBucket,
    required TranscriptParagraph paragraph,
    required TextStyle? labelStyle,
    required TextStyle? bodyStyle,
  }) { /* copy loop */ }
}
```

- [ ] **Step 2:** `translation_result_transcript_view.dart` — copy `TranslationResultTranscriptView` body; use `TranscriptInlineFormat` + `transcript_display_format.dart` imports from package.

- [ ] **Step 3: Commit**

```bash
git add lib/transcript/presentation
git commit -m "feat(common): add TranslationResultTranscriptView and inline format helpers"
```

---

### Task 7: TTS UI

**Files:**
- Create: `lecture_common/lib/tts/tts_pane_snapshot.dart`
- Create: `lecture_common/lib/tts/tts_slider_utils.dart`
- Create: `lecture_common/lib/tts/presentation/translation_tts_transport.dart`
- Create: `lecture_common/test/tts/translation_tts_transport_test.dart`

- [ ] **Step 1:** Copy the three TTS source files; fix imports to package paths.

- [ ] **Step 2:** Copy widget test; update import to `package:lecture_common/tts/presentation/translation_tts_transport.dart`.

- [ ] **Step 3:** Run:

```bash
cd /Users/truong-d/Documents/code/lecture_common && flutter test test/tts/translation_tts_transport_test.dart
```

Expected: All tests passed.

- [ ] **Step 4: Commit**

```bash
git add lib/tts test/tts
git commit -m "feat(common): add TranslationTtsTransport and TtsPaneSnapshot"
```

---

### Task 8: Barrel export

**Files:**
- Create: `lecture_common/lib/lecture_common.dart`

- [ ] **Step 1:**

```dart
library lecture_common;

export 'transcript/data/transcript_bucket.dart';
export 'transcript/data/transcript_paragraph.dart';
export 'transcript/data/transcript_segment.dart';
export 'transcript/data/speaker_label_state.dart';
export 'transcript/domain/transcript_text_event.dart';
export 'transcript/domain/transcript_sender_detail.dart';
export 'transcript/domain/transcript_reducer.dart';
export 'transcript/domain/transcript_display_format.dart';
export 'transcript/domain/session_transcript_state.dart';
export 'transcript/domain/translation_text_compound_id.dart';
export 'transcript/presentation/transcript_inline_format.dart';
export 'transcript/presentation/translation_result_transcript_view.dart';
export 'tts/tts_pane_snapshot.dart';
export 'tts/tts_slider_utils.dart';
export 'tts/presentation/translation_tts_transport.dart';
```

- [ ] **Step 2:** Run all package tests:

```bash
cd /Users/truong-d/Documents/code/lecture_common && flutter test
```

Expected: All tests passed.

- [ ] **Step 3: Commit**

```bash
git add lib/lecture_common.dart
git commit -m "feat(common): export public API from lecture_common.dart"
```

---

## Phase 2 — Rewire `app_2way_v3`

### Task 9: Add dependency and compatibility exports

**Files:**
- Modify: `app_2way_v3/pubspec.yaml`
- Create: `app_2way_v3/lib/features/translation_session/data/websocket/mt_text_event.dart` (thin export)
- Create: `app_2way_v3/lib/features/translation_session/data/websocket/sender_detail_parsed.dart` (thin export)
- Create: `app_2way_v3/lib/features/translation_session/domain/transcript/transcript_reducer.dart` (thin export)

- [ ] **Step 1:** Add to `pubspec.yaml`:

```yaml
  lecture_common:
    path: ../lecture_common
```

Run `flutter pub get` in `app_2way_v3`.

- [ ] **Step 2:** Replace deleted-type files with exports:

```dart
// mt_text_event.dart
import 'package:lecture_common/lecture_common.dart';
typedef MtTextEvent = TranscriptTextEvent;
```

```dart
// sender_detail_parsed.dart
import 'package:lecture_common/lecture_common.dart';
typedef SenderDetailParsed = TranscriptSenderDetail;
```

```dart
// transcript_reducer.dart
import 'package:lecture_common/lecture_common.dart';
TranscriptBucket applyMtTextEvent(TranscriptBucket bucket, MtTextEvent event) =>
    applyTranscriptTextEvent(bucket, event);
```

- [ ] **Step 3: Commit** (`app_2way_v3`)

```bash
git add pubspec.yaml pubspec.lock lib/features/translation_session
git commit -m "chore: add lecture_common dependency and compatibility typedefs"
```

---

### Task 10: Update UI and delete moved files

**Files:**
- Modify: `app_2way_v3/lib/features/translation_session/ui/translation_result_panel.dart`
- Delete: moved transcript data/domain/presentation files under `app_2way_v3` (keep WS, inbound, routers, TTS controller)
- Delete: `app_2way_v3/lib/features/translation_session/ui/translation_tts_transport.dart`
- Delete: `app_2way_v3/lib/features/translation_session/ui/tts_slider_utils.dart`
- Modify: tests — remove migrated tests or point to `lecture_common` if duplicated

- [ ] **Step 1:** `translation_result_panel.dart` — import package:

```dart
import 'package:lecture_common/lecture_common.dart';
// Remove local transcript imports
// TranslationResultTranscriptView → from package
// TranslationTtsTransport → from package
// paragraphInlineSpans → TranscriptInlineFormat.paragraphInlineSpans
// oneLineHeight → TranscriptInlineFormat.oneLineHeight
```

- [ ] **Step 2:** Update `translation_screen.dart` imports if it imported local transcript view directly (use package or panel only).

- [ ] **Step 3:** Delete files now in `lecture_common` (data/transcript/*, domain/transcript/* except router/asr/legacy, ui/translation_tts_transport.dart, ui/tts_slider_utils.dart, domain/tts/tts_pane_snapshot.dart).

- [ ] **Step 4:** Run full 2-way test suite:

```bash
cd /Users/truong-d/Documents/code/app_2way_v3 && flutter test
```

Expected: All tests passed (fix any broken imports).

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "refactor: use lecture_common for transcript and TTS transport UI"
```

---

## Phase 3 — `lecture_viewer_v3` lecture session

### Task 11: Dependencies

**Files:**
- Modify: `lecture_viewer_v3/pubspec.yaml`

- [ ] **Step 1:**

```yaml
  lecture_common:
    path: ../lecture_common
  web_socket_channel: ^3.0.3
```

- [ ] **Step 2:** `flutter pub get` in `lecture_viewer_v3`.

- [ ] **Step 3: Commit**

```bash
cd /Users/truong-d/Documents/code/lecture_viewer_v3
git add pubspec.yaml pubspec.lock
git commit -m "chore: add lecture_common and web_socket_channel"
```

---

### Task 12: Meeting name helper (TDD)

**Files:**
- Modify: `lecture_viewer_v3/lib/core/util/lecture_app_link.dart`
- Modify: `lecture_viewer_v3/test/core/util/lecture_app_link_test.dart`

- [ ] **Step 1: Write failing tests**

```dart
group('meetingNameFromLinkRecord', () {
  test('returns last path segment', () {
    expect(
      meetingNameFromLinkRecord(
        'lt2srv.iar.kit.edu/mobile/session/tkq1221114001-lecture',
      ),
      'tkq1221114001-lecture',
    );
  });

  test('returns null when path empty', () {
    expect(meetingNameFromLinkRecord('host.only'), isNull);
  });
});
```

- [ ] **Step 2:** Run test — expect FAIL.

- [ ] **Step 3: Implement**

```dart
String? meetingNameFromLinkRecord(String linkRecord) {
  final trimmed = linkRecord.trim();
  final path = trimmed.contains('://')
      ? Uri.parse(trimmed).path
      : '/${trimmed.split('/').skip(1).join('/')}';
  final segments = path.split('/').where((s) => s.isNotEmpty).toList();
  if (segments.isEmpty) return null;
  return segments.last;
}
```

(Adjust parsing to match existing `resolveSessionUrl` host/path handling — use same path extraction as `Uri` on resolved https URL for consistency.)

- [ ] **Step 4:** Run tests — expect PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/util/lecture_app_link.dart test/core/util/lecture_app_link_test.dart
git commit -m "feat: extract meeting name from link_record"
```

---

### Task 13: WebSocket URL builder (TDD)

**Files:**
- Create: `lecture_viewer_v3/lib/core/util/lecture_ws_url.dart`
- Create: `lecture_viewer_v3/test/core/util/lecture_ws_url_test.dart`

- [ ] **Step 1: Failing test**

```dart
test('builds wss lecture-session URL', () {
  final uri = lectureSessionWsUri(
    origin: 'https://lt2srv.iar.kit.edu',
    sessionId: 'tkq1221114001-lecture',
  );
  expect(uri.scheme, 'wss');
  expect(uri.host, 'lt2srv.iar.kit.edu');
  expect(uri.path, '/ws/lecture-session');
  expect(uri.queryParameters['sessionID'], 'tkq1221114001-lecture');
});
```

- [ ] **Step 2: Implement**

```dart
Uri lectureSessionWsUri({required String origin, required String sessionId}) {
  final https = Uri.parse(origin);
  return Uri(
    scheme: 'wss',
    host: https.host,
    port: https.hasPort ? https.port : null,
    path: '/ws/lecture-session',
    queryParameters: {'sessionID': sessionId},
  );
}
```

- [ ] **Step 3:** `flutter test test/core/util/lecture_ws_url_test.dart` — PASS.

- [ ] **Step 4: Commit**

---

### Task 14: Lecture transcript router (TDD)

**Files:**
- Create: `lecture_viewer_v3/lib/features/lecture_session/domain/transcript/lecture_bucket_key.dart`
- Create: `lecture_viewer_v3/lib/features/lecture_session/domain/transcript/lecture_transcript_router.dart`
- Create: `lecture_viewer_v3/test/features/lecture_session/domain/lecture_transcript_router_test.dart`

- [ ] **Step 1: Bucket key**

```dart
String lectureBucketKey({
  required String languageDisplayName,
  required String rawSender,
}) => '$languageDisplayName|$rawSender';
```

- [ ] **Step 2: Router — tests for:**

- percent `0` + language English + `mt:0` in computedSenders → accepts `mt:0`, rejects `postproduction:70_en`
- percent `70` → accepts `postproduction:70_en`, rejects `mt:0`
- wrong language → rejects

- [ ] **Step 3: Implement** `List<String> targetRawSendersForEvent(...)` or `bool shouldApplyText({required TranscriptTextEvent event, required int shorteningPercent, required Map<String, ComputedSenderInfo> computedSenders})` returning bucket keys to update.

Parse `computedSenders` into a small map:

```dart
class ComputedSenderInfo {
  const ComputedSenderInfo({
    required this.language,
    required this.type,
    required this.percent,
    this.langCode,
  });
  final String language;
  final String type;
  final int percent;
  final String? langCode;
}
```

- [ ] **Step 4:** Run router tests — PASS.

- [ ] **Step 5: Commit**

---

### Task 15: Inbound parser

**Files:**
- Create: `lecture_viewer_v3/lib/features/lecture_session/data/inbound/lecture_inbound_message.dart`
- Create: `lecture_viewer_v3/lib/features/lecture_session/data/inbound/lecture_inbound_parser.dart`
- Create: `lecture_viewer_v3/test/features/lecture_session/data/lecture_inbound_parser_test.dart`

- [ ] **Step 1:** Sealed messages: `LectureInboundInfo`, `LectureInboundTexts`, `LectureInboundIgnored`.

- [ ] **Step 2:** Parse `info` → `activeLanguages`, `computedSenders` map, `sessionID`.

- [ ] **Step 3:** Parse `texts` → `List<TranscriptTextEvent>`:

```dart
final textId = '${item['textId']}'; // int or string from server
final isFinal = item['isFinal'] == true;
```

- [ ] **Step 4:** `objectType == 'raw_pcm'` → `LectureInboundIgnored`.

- [ ] **Step 5:** Unit tests with JSON fixtures from `docs/1-session_view.md`.

- [ ] **Step 6: Commit**

---

### Task 16: WebSocket client (receive-only)

**Files:**
- Create: `lecture_viewer_v3/lib/features/lecture_session/data/websocket/lecture_session_websocket_client.dart`

- [ ] **Step 1:** Copy reconnect loop from `TranslationWebSocketClient`; remove `sendPcmBytes`, `END`/`DONE` stop handshake (simple `sink.close()` on stop).

- [ ] **Step 2:** Expose `Stream<LectureWsPhase> phase` and `void Function(String raw) onMessage`.

- [ ] **Step 3:** Manual smoke: connect to test server in debug (optional); unit-test phase transitions with mock channel if feasible.

- [ ] **Step 4: Commit**

---

### Task 17: `textScale` in app settings

**Files:**
- Modify: `lecture_viewer_v3/lib/core/providers/app_settings_notifier.dart`
- Modify: `lecture_viewer_v3/lib/features/settings/presentation/settings_screen.dart` (optional: show current scale; controls live on meeting screen)

- [ ] **Step 1:** Add `textScale` to state (default `1.0`), prefs key `text_scale_v1`.

- [ ] **Step 2:** Methods `increaseTextScale()` / `decreaseTextScale()` clamp e.g. `0.8`–`2.0`, step `0.1`.

- [ ] **Step 3: Commit**

---

### Task 18: Lecture session notifier

**Files:**
- Create: `lecture_viewer_v3/lib/features/lecture_session/presentation/providers/lecture_session_notifier.dart`
- Create: `lecture_viewer_v3/lib/features/lecture_session/presentation/lecture_session_state.dart`
- Create: `lecture_viewer_v3/test/features/lecture_session/lecture_session_notifier_test.dart`

- [ ] **Step 1:** State fields: `sessionId`, `wsPhase`, `activeLanguages`, `computedSenders`, `selectedLanguage`, `shorteningPercent`, `transcript` (`SessionTranscriptState`), `errorMessage`, `isBacklogDraining`.

- [ ] **Step 2:** On `LectureInboundInfo`: set defaults — language from `asr:0`, shortening `0` or min percent.

- [ ] **Step 3:** On each text: compute **all** matching bucket keys via router; `applyTranscriptTextEvent` per bucket; during backlog skip `notifyListeners` and schedule throttle timer (80 ms).

- [ ] **Step 4:** `activeBucket` getter from `selectedLanguage` + shortening → rawSender lookup.

- [ ] **Step 5:** Test: 100 rapid text applies → `notifyListeners` call count &lt; 20 (mock notifier or counter).

- [ ] **Step 6: Commit**

---

### Task 19: Join dialog and meeting screen

**Files:**
- Create: `lecture_viewer_v3/lib/features/lecture_session/presentation/join_session_dialog.dart`
- Create: `lecture_viewer_v3/lib/features/lecture_session/presentation/lecture_session_controls.dart`
- Create: `lecture_viewer_v3/lib/features/lecture_session/presentation/lecture_session_screen.dart`

- [ ] **Step 1:** `showJoinSessionDialog(context, meetingName)` → AlertDialog with Join/Cancel; Join pushes `LectureSessionScreen(sessionId: meetingName)`.

- [ ] **Step 2:** `LectureSessionScreen` — `ConsumerStatefulWidget`; `initState` → start WS via notifier; `dispose` → stop WS.

- [ ] **Step 3:** Controls: language dropdown, shortening dropdown (percents for language), font −/+, connection label.

- [ ] **Step 4:** Body: `TranslationResultTranscriptView` from `lecture_common` with `ref.watch(notifier.select((s) => s.activeBucket))` and `textScaler`.

- [ ] **Step 5: Commit**

---

### Task 20: Wire entry points; remove browser launch

**Files:**
- Modify: `lecture_viewer_v3/lib/features/home/presentation/qr_scan_screen.dart`
- Modify: `lecture_viewer_v3/lib/app/branch_session_listener.dart`
- Modify: `lecture_viewer_v3/lib/features/home/presentation/home_empty_body.dart`
- Modify: `lecture_viewer_v3/lib/core/util/launch_lecture_session.dart` (deprecate or remove `handleLectureSessionLink` usage)
- Modify: `lecture_viewer_v3/lib/app/lecture_viewer_app.dart` (route if needed)

- [ ] **Step 1:** QR success path:

```dart
final meetingName = meetingNameFromLinkRecord(linkRecord);
if (meetingName == null) { /* invalid snackbar */ return; }
if (!context.mounted) return;
await showJoinSessionDialog(context, meetingName: meetingName);
if (context.mounted) Navigator.of(context).pop(); // leave scanner
```

- [ ] **Step 2:** Branch path — same after `link_record` resolved (keep dedupe logic).

- [ ] **Step 3:** Update empty body: “Join the session in the app.”

- [ ] **Step 4:** Run `flutter test` in `lecture_viewer_v3`.

- [ ] **Step 5: Commit**

```bash
git commit -m "feat: in-app lecture session entry and meeting view"
```

---

### Task 21: Documentation drift

**Files:**
- Modify: `lecture_viewer_v3/README.md`
- Modify: `lecture_viewer_v3/docs/superpowers/specs/2026-05-18-home-settings-design.md` (note superseded entry behavior)

- [ ] **Step 1:** README — session opens in-app, lists `lecture_common`.

- [ ] **Step 2: Commit**

```bash
git commit -m "docs: update README for in-app lecture session"
```

---

## Manual test plan

- [ ] QR scan example Branch URL → join modal shows `tkq1221114001-lecture` → Join → connecting → transcript appears.
- [ ] Branch link from Notes → same flow cold start.
- [ ] Switch language and shortening — instant content swap without reconnect.
- [ ] Font −/+ persists after leaving and rejoining meeting.
- [ ] Cancel join modal — stays on home/scanner, no WS.
- [ ] `app_2way_v3`: existing translation session still shows transcript + TTS transport (regression).

---

## Spec coverage checklist

| Spec requirement | Task(s) |
|------------------|---------|
| `lecture_common` shared UI | 1–8, 9–10 |
| Join modal + meeting name | 12, 19–20 |
| No browser launch | 20 |
| WS `lecture-session` URL | 13, 16 |
| `info` / `texts` / ignore `raw_pcm` | 15–16, 18 |
| mt vs postproduction routing | 14, 18 |
| Default language `asr:0` | 18 |
| Default shortening 0% or lowest | 18 |
| Speaker rules via reducer | 4 (package) |
| Backlog batching | 18 |
| Global textScale | 17, 19 |
| No TTS on viewer | 15 (ignore), 19 (no transport widget) |
| 2-way uses package | 9–10 |

---

## Execution handoff

Plan complete and saved to `docs/superpowers/plans/2026-05-18-lecture-session-view-implementation-plan.md`.

**Two execution options:**

1. **Subagent-driven (recommended)** — fresh subagent per task, review between tasks  
2. **Inline execution** — run tasks in this session with checkpoints  

Which approach do you want?
