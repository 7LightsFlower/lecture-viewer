# Lecture Session View — Design Spec

**Date:** 2026-05-18  
**Project:** `lecture_viewer_v3`  
**Status:** Approved in brainstorming; amended for `lecture_common` shared package  
**Source:** `docs/1-session_view.md`, `app_2way_v3/docs/app_desc_part3.md`

## Goal

Replace external-browser session launch with an **in-app meeting view**: join confirmation after QR/Branch entry, WebSocket connection to `lecture-session`, and a two-part screen (controls + transcript) that displays live and historical text with language and shortening-level selection.

## Decisions (brainstorming)

| Topic | Decision |
|-------|----------|
| Text routing | **0%** shortening → `mt:*` for selected language; **>0%** → `postproduction:<percent>_<langCode>` |
| Shortening picker | Show only percents present in `computedSenders` for the **current language** |
| Default shortening | **0%** if available for language, else **lowest** available percent |
| TTS | **Text only** — ignore all `raw_pcm` / TTS messages (backlog and live) |
| Entry | **Always in-app**; remove system-browser launch for session links |
| Speaker labels | Same rules as `app_desc_part3` (`text_compound_id` lookup, `isShowSpeakerName`) |
| Default display language | Language from `computedSenders['asr:0']` (typically **Transcript**); fallback: first `activeLanguages` |
| Backlog performance | **Ingest all languages** in memory; **batched UI updates** while backlog drains |
| Font size | **Global persisted** step control (`textScale`), default **1.0** |
| Shared UI & transcript logic | **`lecture_common`** package — used by **both** `app_2way_v3` and `lecture_viewer_v3` |
| Implementation strategy | **Extract to `lecture_common` first**, then wire both apps (see § Shared package) |

## Amends prior spec

`docs/superpowers/specs/2026-05-18-home-settings-design.md` stated sessions open in the **system browser**. This spec **replaces** that outcome: QR and Branch both navigate to the in-app join flow and meeting view.

---

## Shared package: `lecture_common`

Both apps share the same transcript display and TTS transport UI. Extract from `app_2way_v3` into the existing package at `../lecture_common` (path dependency in each app’s `pubspec.yaml`).

### Rationale

- **Single source** for paragraph list, partial preview line, speaker inline spans, and TTS play/seek UI.
- **Lecture viewer** uses transcript widgets; **does not** mount TTS transport (text-only product decision unchanged).
- **2-way app** keeps full toolbar + TTS; imports shared widgets instead of duplicating.

### Move into `lecture_common`

| Layer | From `app_2way_v3` | Notes |
|-------|-------------------|--------|
| **Data** | `transcript_bucket.dart`, `transcript_paragraph.dart`, `transcript_segment.dart`, `speaker_label_state.dart` | Immutable models + JSON |
| **Domain** | `transcript_display_format.dart`, `transcript_reducer.dart`, `translation_text_compound_id.dart`, `session_transcript_state.dart` | Reducer renamed API: `applyTranscriptTextEvent` |
| **Domain** | `MtTextEvent` → **`TranscriptTextEvent`**, `SenderDetailParsed` → **`TranscriptSenderDetail`** | Neutral names; same fields as today |
| **UI** | `TranslationResultTranscriptView` | Unchanged public name |
| **UI** | `TranslationResultPanel.paragraphInlineSpans`, `oneLineHeight` | Extract to `transcript_inline_format.dart` (or keep static helpers on a `TranscriptViewFormat` class) |
| **TTS** | `TtsPaneSnapshot`, `tts_slider_utils.dart`, `TranslationTtsTransport` | Unchanged public names |

### Stay app-specific (not in `lecture_common`)

| Concern | `app_2way_v3` | `lecture_viewer_v3` |
|---------|---------------|---------------------|
| WebSocket client & inbound JSON | `TranslationWebSocketClient`, uplink PCM | `LectureSessionWebSocketClient`, receive-only |
| Text routing | `mt:` only (`translation_transcript_router`) | `mt:` vs `postproduction:*` by shortening % |
| Toolbar / language picker | `TranslationResultToolbarRow`, `display_language_sheet`, `Language` model | `LectureSessionControls` (language + shortening + font) |
| Composite panel | `TranslationResultPanel` (toolbar + transcript) | Meeting screen composes controls + `TranslationResultTranscriptView` |
| TTS playback controller | `LiveTtsController`, PCM download | **None** (ignore `raw_pcm`) |
| Session / Riverpod notifiers | `translation_session_notifier` | `lecture_session_notifier` |

### `lecture_common` layout

```text
lecture_common/lib/
  lecture_common.dart                    # barrel exports
  transcript/
    data/
      transcript_bucket.dart
      transcript_paragraph.dart
      transcript_segment.dart
      speaker_label_state.dart
    domain/
      transcript_text_event.dart
      transcript_sender_detail.dart
      transcript_display_format.dart
      transcript_reducer.dart
      session_transcript_state.dart
      translation_text_compound_id.dart
    presentation/
      transcript_inline_format.dart      # paragraphInlineSpans, oneLineHeight
      translation_result_transcript_view.dart
  tts/
    tts_pane_snapshot.dart
    tts_slider_utils.dart
    presentation/
      translation_tts_transport.dart
```

### App dependencies

```yaml
# app_2way_v3/pubspec.yaml and lecture_viewer_v3/pubspec.yaml
dependencies:
  lecture_common:
    path: ../lecture_common
```

### Migration steps (implementation order)

1. **Populate `lecture_common`** — move files, fix imports, rename `MtTextEvent` → `TranscriptTextEvent`, `applyMtTextEvent` → `applyTranscriptTextEvent`.
2. **Migrate tests** — move `transcript_reducer`, `transcript_display_format`, `translation_tts_transport` tests into `lecture_common/test/`.
3. **Rewire `app_2way_v3`** — replace local imports with `package:lecture_common/...`; thin wrappers only where needed (e.g. parse WS JSON → `TranscriptTextEvent` then call reducer).
4. **Implement lecture session** — use `lecture_common` for buckets, reducer, `TranslationResultTranscriptView`; no `TranslationTtsTransport` on meeting screen.

### API example (both apps)

```dart
import 'package:lecture_common/lecture_common.dart';

// After inbound parse:
final next = applyTranscriptTextEvent(bucket, event);

// UI:
TranslationResultTranscriptView(
  textScaler: TextScaler.linear(textScale),
  activeBucket: activeBucket,
  scrollController: scrollController,
);
```

---

## Entry & join flow

### Meeting name extraction

From `link_record` (path after host), **meeting name** = last non-empty path segment.

```text
link_record=lt2srv.iar.kit.edu/mobile/session/tkq1221114001-lecture
→ meeting_name = tkq1221114001-lecture
```

Helper: `meetingNameFromLinkRecord(String linkRecord)` in `lib/core/util/lecture_app_link.dart` (or `lecture_session` feature util).

### Paths (unchanged validation)

1. **QR** (`mobile_scanner`): validate `lectureviewer.app.link` + `link_record` (existing helpers).
2. **Branch** (`BranchSessionListener`): same `link_record` extraction.

### Join modal

Before meeting screen:

- Show **meeting name** prominently.
- **Join** → navigate to meeting view with `sessionId = meetingName`.
- **Cancel** → dismiss modal; remain on home or pop scanner.

### Retire browser launch

- Remove usage of `handleLectureSessionLink` → `url_launcher` external browser for sessions.
- Keep `resolveSessionUrl` / link parsing where useful for tests or future; session entry no longer opens browser.
- Update home empty-state copy: sessions open **in the app**.

---

## WebSocket & session lifecycle

### URL

```text
wss://<host>/ws/lecture-session?sessionID=<meetingName>
```

- `<host>` from `ApiEnvironment.origin` (strip `https://`, use `wss://`).
- Production: `lt2srv.iar.kit.edu`; testing: `ltg-api.vais.vn` (per `ApiEnvironmentOrigins`).

### Client

Adapt `app_2way_v3` `TranslationWebSocketClient`:

- Connect / reconnect phases (`connecting`, `connected`, `reconnecting`, `stopped`).
- **No** PCM uplink or `END`/`DONE` session teardown (viewer is receive-only).
- Inbound JSON passed to lecture inbound handler.

### Message types

| `objectType` | Handling |
|--------------|----------|
| `info` | Parse `activeLanguages`, `computedSenders`, `sessionID`; initialize session metadata and UI defaults |
| `texts` | Parse text array → transcript reducer for all matching buckets |
| `raw_pcm` | **Ignore** immediately (no parse, no queue) |

### Defaults after `info`

1. **Language:** `computedSenders['asr:0'].language` if key exists; else `activeLanguages.first`.
2. **Shortening:** `0` if present in `computedSenders` for that language; else minimum available percent for that language.

### Lifecycle

- **On meeting screen mount:** start WebSocket.
- **On back / dispose:** stop WebSocket, clear session notifier state.
- **Reconnect:** auto-retry with backoff while screen mounted; show phase in control area.

### Connection UX

- After join, show connecting state until first `info` or recoverable error.
- On persistent failure: banner/snackbar + manual retry affordance.

---

## Transcript routing & display

### Bucket model

In-memory `Map<String, TranscriptBucket>` from **`lecture_common`** (`SessionTranscriptState` or equivalent).

**Bucket key** encodes display route, e.g.:

- `Transcript|mt:0` (language display name + rawSender for route)
- `German|postproduction:70_de`

### Router rules

For each text in a `texts` message:

1. Determine language display name from `sender` / `senderDetail.language`.
2. For each known route for that language (all `mt:*` and `postproduction:*` entries in `computedSenders` for that language), evaluate acceptance:
   - **Shortening 0%:** accept if `rawSender` is the `mt:*` sender for that language.
   - **Shortening N% (N > 0):** accept if `rawSender == postproduction:N_<langCode>` for that language.
3. Apply **`applyTranscriptTextEvent`** from `lecture_common` (same semantics as `app_desc_part3` / 2-way): `isFinal`, `isEndParagraph`, partial preview line, `text_compound_id`, speaker label rules.

**Ingest all routes:** every accepted text updates its bucket even when not the active display route (enables instant language/shortening switches).

### Active display

UI watches **one** bucket: derived from current language + shortening selection. Changing language or shortening only changes which bucket is rendered (no reconnect).

### Content area UI

Use **`TranslationResultTranscriptView`** from `lecture_common` (no fork in `lecture_viewer_v3`):

- `ListView.builder` over paragraphs with finalized segments.
- Gray partial line for current `isFinal: false` preview (replaces previous partial).
- Speaker inline spans per `app_desc_part3` (implemented in package).

Do **not** embed `TranslationTtsTransport` on the lecture meeting screen (text-only).

---

## Control area UI

Top section of meeting screen:

| Control | Behavior |
|---------|----------|
| **Language** | Picker from `activeLanguages` |
| **Shortening level** | Percents available in `computedSenders` for **current language**; changing language rebuilds options |
| **Font size** | − / + steps; `textScale` in `AppSettingsState`, persisted via `shared_preferences`, default `1.0`; applied via `TextScaler.linear(textScale)` |
| **Connection** (optional) | Label/icon for WS phase |

Bottom section: transcript view (§ above).

---

## Performance

### Backlog draining

On connect, server may send a large burst of historical `texts` across many languages.

1. Set **backlog mode** when connection opens.
2. Apply all texts to in-memory buckets **without** notifying UI per message.
3. **Throttle** Riverpod/notifier notifications (≈50–100 ms) while backlog mode is active.
4. Exit backlog mode when inter-message gap exceeds threshold or after first post-burst live message; emit final state.

### Live mode

After backlog: notify on meaningful bucket changes; UI uses `select` to watch only active bucket + controls (avoid full-tree rebuilds).

### TTS

Drop `raw_pcm` at parser boundary (zero storage).

---

## Feature layout

```text
lecture_common/                        # shared (see § Shared package)
  lib/transcript/...
  lib/tts/...

lib/features/lecture_session/          # lecture_viewer_v3 only
  data/
    websocket/lecture_session_websocket_client.dart
    inbound/lecture_inbound_parser.dart   # JSON → TranscriptTextEvent
  domain/
    transcript/lecture_transcript_router.dart
  presentation/
    providers/lecture_session_notifier.dart
    join_session_dialog.dart
    lecture_session_screen.dart       # controls + TranslationResultTranscriptView
    lecture_session_controls.dart

lib/core/util/lecture_app_link.dart    # + meetingNameFromLinkRecord
lib/core/providers/app_settings_notifier.dart  # + textScale persistence
```

**Dependencies to add (`lecture_viewer_v3`):** `lecture_common` (path), `web_socket_channel` (match `app_2way_v3`).

**Parallel change (`app_2way_v3`):** `lecture_common` (path); delete moved transcript/TTS UI files; update imports.

**Entry wiring:**

- `qr_scan_screen.dart` / `branch_session_listener.dart` → join modal → `LectureSessionScreen(sessionId: meetingName)`.
- Remove external `launchUrl` for sessions.

---

## Error handling

| Case | UX |
|------|-----|
| Invalid QR / Branch link | Existing snackbars on home/scanner |
| Missing `link_record` | “Missing session link” |
| Empty meeting name from path | “Invalid session link” |
| WebSocket connect failure | Inline error + retry on meeting screen |
| WS disconnect while viewing | Reconnecting indicator; resume when connected |

---

## Testing

| Area | Tests |
|------|-------|
| **`lecture_common`** | Reducer, display format, `TranslationTtsTransport` widget tests (migrated from `app_2way_v3`) |
| `meetingNameFromLinkRecord` | Unit: `lecture_viewer_v3` |
| WS URL builder | Unit: `lecture_viewer_v3` |
| `lecture_transcript_router` | Unit: 0% → `mt:*`; 70% → `postproduction:70_en`; reject wrong sender |
| Backlog batching | Unit: `lecture_session_notifier` — bounded notify count during burst |

**Manual:** QR and Branch → join modal → meeting view; switch language/shortening during live session; reconnect after background.

---

## Out of scope (v1)

- **Lecture viewer:** TTS playback (no `TranslationTtsTransport` on meeting screen; `raw_pcm` ignored)
- In-app WebView for session
- Meeting list / history
- HTTP REST beyond WebSocket
- **`lecture_common`:** WebSocket clients, session notifiers, app-specific routers
- Speaker-less simplified display (full `app_desc_part3` rules required)

---

## Doc drift

- `docs/1-session_view.md`: canonical product notes; this spec is the implementation contract.
- `docs/superpowers/specs/2026-05-18-home-settings-design.md`: update “Unified outcome” and out-of-scope when implementing (browser → in-app).
- `README.md`: update session entry description.
