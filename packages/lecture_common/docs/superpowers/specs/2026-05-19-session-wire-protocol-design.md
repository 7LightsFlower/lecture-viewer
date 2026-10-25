# Session wire protocol consolidation (lecture_common)

**Date:** 2026-05-19  
**Repos:** `lecture_common`, `app_2way_v3`, `lecture_viewer_v3`  
**Status:** Approved (brainstorming)

## 1. Summary

Consolidate duplicated **wire-protocol** and **TTS PCM utility** code from `translation_session` (2-way) and `lecture_session` (viewer) into `lecture_common`. Each app keeps its own inbound message union, WebSocket client, transcript routing, share, and UI. **PCM uplink and WebSocket send** remain **only** in `app_2way_v3`.

**Approach:** Stateless payload parsers in `lecture_common` (Approach 1). **Text filtering:** permissive parse in common; viewer applies post-parse filter (Approach B).

## 2. Context

`lecture_common` already owns transcript models, reducer, `SessionTranscriptState`, and transcript/TTS presentation widgets. Both apps depend on it via path dependency.

**Still duplicated today:**

| Area | Notes |
|------|--------|
| Inbound `texts` / `raw_pcm` parsing | Nearly identical; viewer adds `info`, session-end, server-error |
| `TtsPcmEvent` / `LectureTtsPcmEvent` | Same fields except 2-way adds `lt2srvSessionId` |
| `ws_reconnect_policy` | Byte-identical |
| TTS PCM helpers | `tts_pcm_http_fetch`, `tts_pcm_base64_payload`, `tts_play_start_resolver`, `tts_resume_after_duck_resolver` — identical in both apps |

**App-specific (unchanged):**

- 2-way: PCM uplink, `TranslationWebSocketClient` send path, session coordinator, recording, auto-TTS/VAD
- Viewer: receive-only WS client, `info` parsing, multi-module transcript router, media bridge

## 3. Goals and non-goals

### Goals

1. Single implementation of `texts` and `raw_pcm` payload parsing.
2. Unified `TtsPcmEvent` (including optional `lt2srvSessionId` from URL).
3. Shared `reconnectDelay` and identical TTS PCM domain utilities.
4. Permissive `texts` parser; viewer filters unsupported modules and empty text **after** parse.
5. No behavior change for live sessions in either app.
6. Tests live in `lecture_common` for shared code; app parser tests remain and pass.

### Non-goals

- Transcript routing, share export, presentation/UI.
- Unifying WebSocket clients (uplink vs receive-only).
- Viewer `info` / `session_end` / server-error parsing (stays in viewer).
- Removing 2-way transcript re-export shims (optional follow-up).
- Transcript content formats (separate spec: `2026-05-18-transcript-content-formats-design.md`).

## 4. Architecture

### 4.1 New `lecture_common` layout

```text
lib/
  inbound/
    inbound_json.dart              # decodeInboundJsonMap(String raw)
    inbound_texts_parser.dart      # parseInboundTextsPayload(Map decoded)
    inbound_raw_pcm_parser.dart    # parseInboundRawPcmPayload(Map decoded)
    lt2srv_pcm_url.dart            # parseLt2srvSessionIdFromPcmUrl(String url)
    tts_pcm_event.dart             # TtsPcmEvent
  websocket/
    ws_reconnect_policy.dart       # reconnectDelay(...)
  tts/domain/
    tts_pcm_http_fetch.dart
    tts_pcm_base64_payload.dart
    tts_play_start_resolver.dart
    tts_resume_after_duck_resolver.dart
```

Export new public API from `lib/lecture_common.dart`.

Existing `lib/transcript/*` and `lib/tts/presentation/*` unchanged.

### 4.2 Shared inbound API

#### `decodeInboundJsonMap(String raw) → Map<String, dynamic>?`

- `jsonDecode`; returns map only when top-level value is `Map<String, dynamic>`.
- Returns `null` on parse failure or wrong shape (callers treat as ignored).

#### `parseInboundTextsPayload(Map<String, dynamic> decoded) → List<TranscriptTextEvent>?`

- Expects full decoded envelope where caller has already matched `objectType == 'texts'`.
- Reads `data.texts` array; returns `null` if `data` or `texts` invalid/empty.
- **Permissive:** no module-type filter; no empty-text skip.
- Per item, require `text`, `sender`, `rawSender` as `String`.
- `textId`: coerce with `'${item['textId']}'` (supports viewer and 2-way).
- Map `senderDetail` → `TranscriptSenderDetail` (same rules as today).
- Returns empty list only when no valid items (caller may treat as ignored).

#### `parseInboundRawPcmPayload(Map<String, dynamic> decoded) → TtsPcmEvent?`

- Reads `data.url`, `data.rawSender`; requires non-empty URL and `rawSender.startsWith('tts:')`.
- Language from `senderDetail.language` then top-level `data.language`.
- `index` when `data.index` is `int`.
- Sets `lt2srvSessionId` via `parseLt2srvSessionIdFromPcmUrl(url)` (viewer ignores field).

#### `TtsPcmEvent`

```dart
@immutable
class TtsPcmEvent {
  const TtsPcmEvent({
    required this.url,
    required this.rawSender,
    this.index,
    this.languageFromPayload,
    this.lt2srvSessionId,
  });

  final String url;
  final String rawSender;
  final int? index;
  final String? languageFromPayload;
  final String? lt2srvSessionId;
}
```

#### `parseLt2srvSessionIdFromPcmUrl`

Move from `app_2way_v3` `lt2srv_pcm_url.dart` unchanged (extract id from `name=Data/<id>/...`).

### 4.3 App inbound routers (thin wrappers)

#### `app_2way_v3` — `parseTranslationInbound`

```dart
final decoded = decodeInboundJsonMap(raw);
if (decoded == null) return const InboundIgnored();

return switch (decoded['objectType']) {
  'texts' => () {
    final events = parseInboundTextsPayload(decoded);
    if (events == null || events.isEmpty) return const InboundIgnored();
    return InboundMtTexts(events);
  }(),
  'raw_pcm' => () {
    final event = parseInboundRawPcmPayload(decoded);
    if (event == null) return const InboundIgnored();
    return InboundTtsPcm(event);
  }(),
  _ => const InboundIgnored(),
};
```

- Delete `lib/.../data/websocket/tts_pcm_event.dart`.
- Delete `lib/.../domain/inbound/lt2srv_pcm_url.dart` (moved to common).
- `MtTextEvent` typedef remains `TranscriptTextEvent`.

#### `lecture_viewer_v3` — `parseLectureInbound`

Keep existing logic for:

- `decodeInboundJsonMap` failure → `LectureInboundIgnored`
- `status != 200` → `LectureInboundServerError`
- `objectType == 'info'` → `_parseInfo` (unchanged, app-local)
- `session_end` / `END` branches inside `_parseInfo`

For `texts`:

```dart
final parsed = parseInboundTextsPayload(decoded);
if (parsed == null) return const LectureInboundIgnored();
final events = filterLectureTranscriptEvents(parsed);
if (events.isEmpty) return const LectureInboundIgnored();
return LectureInboundTexts(events);
```

For `raw_pcm`:

```dart
final event = parseInboundRawPcmPayload(decoded);
if (event == null) return const LectureInboundIgnored();
return LectureInboundTtsPcm(event);
```

- Delete `lecture_tts_pcm_event.dart`.
- `LectureInboundTtsPcm` holds `TtsPcmEvent` (not `LectureTtsPcmEvent`).

#### Viewer post-filter

New file: `lib/features/lecture_session/domain/transcript/lecture_transcript_event_filter.dart`

```dart
List<TranscriptTextEvent> filterLectureTranscriptEvents(
  List<TranscriptTextEvent> events,
) =>
    events
        .where(
          (e) =>
              isSupportedLectureModuleType(
                moduleTypeFromRawSender(e.rawSender),
              ) &&
              e.text.trim().isNotEmpty,
        )
        .toList();
```

Uses existing `lecture_supported_modules.dart` (`moduleTypeFromRawSender`, `isSupportedLectureModuleType`).

### 4.4 TTS domain files (move to common)

Move byte-identical files from both apps into `lib/tts/domain/` and update imports:

| File |
|------|
| `tts_pcm_http_fetch.dart` |
| `tts_pcm_base64_payload.dart` |
| `tts_play_start_resolver.dart` |
| `tts_resume_after_duck_resolver.dart` |

**Stay app-specific:** `live_tts_controller`, `lecture_tts_controller`, `translation_tts_router`, auto-TTS/VAD, `lecture_tts_media_bridge`, `lecture_tts_gate`, etc.

### 4.5 WebSocket reconnect

Move `ws_reconnect_policy.dart` to `lecture_common/lib/websocket/`. Both `TranslationWebSocketClient` and `LectureSessionWebSocketClient` import `reconnectDelay` from common.

## 5. Files to remove (per app)

### `app_2way_v3`

- `data/websocket/tts_pcm_event.dart`
- `domain/inbound/lt2srv_pcm_url.dart`
- `data/websocket/ws_reconnect_policy.dart`
- `domain/tts/tts_pcm_http_fetch.dart`
- `domain/tts/tts_pcm_base64_payload.dart`
- `domain/tts/tts_play_start_resolver.dart`
- `domain/tts/tts_resume_after_duck_resolver.dart`

### `lecture_viewer_v3`

- `data/inbound/lecture_tts_pcm_event.dart`
- `data/websocket/ws_reconnect_policy.dart`
- `domain/tts/tts_pcm_http_fetch.dart`
- `domain/tts/tts_pcm_base64_payload.dart`
- `domain/tts/tts_play_start_resolver.dart`
- `domain/tts/tts_resume_after_duck_resolver.dart`

## 6. Migration order

1. **`lecture_common`** — add modules, barrel exports, unit tests (port/adapt from app tests).
2. **`app_2way_v3`** — thin parser, import common TTS/WS types; delete moved files; fix tests.
3. **`lecture_viewer_v3`** — thin parser + filter; unify on `TtsPcmEvent`; delete duplicates; fix tests.
4. Verify: `flutter test` in all three packages; `dart analyze` clean.

## 7. Testing

### `lecture_common` (new/ported)

| Test file | Covers |
|-----------|--------|
| `test/inbound/inbound_texts_parser_test.dart` | Valid/invalid payloads, permissive (no filter) |
| `test/inbound/inbound_raw_pcm_parser_test.dart` | TTS URL, language, `lt2srvSessionId` |
| `test/inbound/lt2srv_pcm_url_test.dart` | URL parsing (from 2-way) |
| `test/tts/tts_pcm_http_fetch_test.dart` | Port from app |
| `test/tts/tts_play_start_resolver_test.dart` | Port from app |
| `test/tts/tts_resume_after_duck_resolver_test.dart` | Port from app |

### Apps (adjust imports only)

- `app_2way_v3`: `translation_inbound_parser_test.dart`, TTS tests referencing moved types.
- `lecture_viewer_v3`: `lecture_inbound_parser_test.dart`, new `lecture_transcript_event_filter_test.dart`, TTS language tests use `TtsPcmEvent`.

## 8. Risks and mitigations

| Risk | Mitigation |
|------|------------|
| Subtle `textId` coercion change in 2-way | Parser tests in common + existing 2-way inbound tests |
| Viewer accepts then filters vs inline filter | Dedicated filter unit tests; keep `lecture_inbound_parser_test` |
| Import churn | Migrate one package at a time; run tests after each |
| `lt2srvSessionId` on viewer events | Field optional; viewer code unchanged |

## 9. Optional follow-up

- Remove 2-way transcript re-export shims; import `lecture_common` directly.
- Consolidate share text formatting (out of scope B).

## 10. Decisions log

| Decision | Choice |
|----------|--------|
| Scope | B — wire protocol + identical TTS utilities |
| PCM uplink | Stays in `app_2way_v3` only |
| Text parse filtering | Permissive in common; viewer post-filter |
| Inbound structure | Stateless payload helpers (Approach 1) |
| `TtsPcmEvent` | Single type in common with optional `lt2srvSessionId` |
