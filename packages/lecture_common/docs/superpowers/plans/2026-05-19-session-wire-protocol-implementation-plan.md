# Session Wire Protocol Consolidation — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move shared WebSocket inbound parsing (`texts`/`raw_pcm`), `TtsPcmEvent`, reconnect policy, and identical TTS PCM utilities into `lecture_common`, then thin both apps to wrappers while keeping PCM uplink only in `app_2way_v3`.

**Architecture:** Stateless payload parsers in `lecture_common`; each app keeps its sealed inbound union and routes `objectType`. Permissive `texts` parse in common; viewer filters afterward. Identical TTS files copied from `app_2way_v3` (source of truth).

**Tech stack:** Flutter 3.10+, Dart 3.10+, `lecture_common` path dependency, `http` (for PCM fetch), `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-05-19-session-wire-protocol-design.md`

**Repos (absolute base):** `/Users/truong-d/Documents/code/`

---

## File map

| Action | Path |
|--------|------|
| Create | `lecture_common/lib/inbound/inbound_json.dart` |
| Create | `lecture_common/lib/inbound/inbound_texts_parser.dart` |
| Create | `lecture_common/lib/inbound/inbound_raw_pcm_parser.dart` |
| Create | `lecture_common/lib/inbound/lt2srv_pcm_url.dart` |
| Create | `lecture_common/lib/inbound/tts_pcm_event.dart` |
| Create | `lecture_common/lib/websocket/ws_reconnect_policy.dart` |
| Create | `lecture_common/lib/tts/domain/tts_pcm_http_fetch.dart` |
| Create | `lecture_common/lib/tts/domain/tts_pcm_base64_payload.dart` |
| Create | `lecture_common/lib/tts/domain/tts_play_start_debug.dart` |
| Create | `lecture_common/lib/tts/domain/tts_play_start_resolver.dart` |
| Create | `lecture_common/lib/tts/domain/tts_resume_after_duck_resolver.dart` |
| Modify | `lecture_common/lib/lecture_common.dart` |
| Modify | `lecture_common/pubspec.yaml` |
| Create | `lecture_common/test/inbound/*.dart`, `lecture_common/test/tts/*.dart` |
| Modify | `app_2way_v3` parser, WS client, TTS imports; delete 7 files |
| Modify | `lecture_viewer_v3` parser, filter, WS client, TTS imports; delete 6 files |

**Note:** `tts_play_start_debug.dart` is not in the spec table but is required by `tts_play_start_resolver.dart` (identical in both apps). Move it with the resolver.

---

### Task 1: `lecture_common` — LT2SRV URL + `TtsPcmEvent`

**Files:**
- Create: `lecture_common/lib/inbound/lt2srv_pcm_url.dart`
- Create: `lecture_common/lib/inbound/tts_pcm_event.dart`
- Create: `lecture_common/test/inbound/lt2srv_pcm_url_test.dart`
- Modify: `lecture_common/lib/lecture_common.dart`

- [ ] **Step 1: Write failing test**

Create `lecture_common/test/inbound/lt2srv_pcm_url_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lecture_common/inbound/lt2srv_pcm_url.dart';

void main() {
  test('parses id from name=Data/<id>/<suffix>', () {
    const url =
        'https://vais:eiliepo0kiu7Giec@lt2srv.iar.kit.edu/ltapi/stream/data?name=Data/317221/1';
    expect(parseLt2srvSessionIdFromPcmUrl(url), '317221');
  });

  test('returns null when name query missing', () {
    expect(
      parseLt2srvSessionIdFromPcmUrl('https://example.com/ltapi/stream/data'),
      isNull,
    );
  });

  test('returns null when name does not start with Data/', () {
    expect(
      parseLt2srvSessionIdFromPcmUrl(
        'https://example.com/x?name=Other/317221/1',
      ),
      isNull,
    );
  });

  test('returns null for invalid url', () {
    expect(parseLt2srvSessionIdFromPcmUrl(''), isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd /Users/truong-d/Documents/code/lecture_common && flutter test test/inbound/lt2srv_pcm_url_test.dart
```

Expected: FAIL — library/file not found.

- [ ] **Step 3: Implement `lt2srv_pcm_url.dart` and `tts_pcm_event.dart`**

`lecture_common/lib/inbound/lt2srv_pcm_url.dart` (copy from `app_2way_v3/lib/features/translation_session/domain/inbound/lt2srv_pcm_url.dart`):

```dart
/// Extracts LT2SRV session id from PCM stream URLs:
/// `...?name=Data/<lt2srv_session_id>/...`
String? parseLt2srvSessionIdFromPcmUrl(String url) {
  try {
    final name = Uri.parse(url).queryParameters['name'];
    if (name == null || name.isEmpty) return null;
    final parts = name.split('/');
    if (parts.length < 2 || parts[0] != 'Data') return null;
    final id = parts[1].trim();
    if (id.isEmpty) return null;
    return id;
  } on Object {
    return null;
  }
}
```

`lecture_common/lib/inbound/tts_pcm_event.dart`:

```dart
import 'package:flutter/foundation.dart';

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

Add to `lecture_common/lib/lecture_common.dart`:

```dart
export 'inbound/lt2srv_pcm_url.dart';
export 'inbound/tts_pcm_event.dart';
```

- [ ] **Step 4: Run test to verify it passes**

```bash
cd /Users/truong-d/Documents/code/lecture_common && flutter test test/inbound/lt2srv_pcm_url_test.dart
```

Expected: PASS

- [ ] **Step 5: Commit**

```bash
cd /Users/truong-d/Documents/code/lecture_common
git add lib/inbound/lt2srv_pcm_url.dart lib/inbound/tts_pcm_event.dart lib/lecture_common.dart test/inbound/lt2srv_pcm_url_test.dart
git commit -m "feat(common): add TtsPcmEvent and lt2srv PCM URL parser"
```

---

### Task 2: `lecture_common` — inbound JSON + texts + raw_pcm parsers

**Files:**
- Create: `lecture_common/lib/inbound/inbound_json.dart`
- Create: `lecture_common/lib/inbound/inbound_texts_parser.dart`
- Create: `lecture_common/lib/inbound/inbound_raw_pcm_parser.dart`
- Create: `lecture_common/test/inbound/inbound_texts_parser_test.dart`
- Create: `lecture_common/test/inbound/inbound_raw_pcm_parser_test.dart`
- Modify: `lecture_common/lib/lecture_common.dart`

- [ ] **Step 1: Write failing tests**

`lecture_common/test/inbound/inbound_texts_parser_test.dart`:

```dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lecture_common/inbound/inbound_json.dart';
import 'package:lecture_common/inbound/inbound_texts_parser.dart';

void main() {
  test('parseInboundTextsPayload returns events for valid texts envelope', () {
    const json = '''
{"message":"","status":200,"data":{"texts":[{"text":" Hello","isFinal":false,"textId":"0010","sender":"English","rawSender":"mt:1","senderDetail":{"speakerName":"Unknown 0","isShowSpeakerName":false},"isEndParagraph":false}]},"objectType":"texts"}
''';
    final decoded = decodeInboundJsonMap(json)!;
    final events = parseInboundTextsPayload(decoded);
    expect(events, isNotNull);
    expect(events!, hasLength(1));
    expect(events.single.text, ' Hello');
    expect(events.single.textId, '0010');
    expect(events.single.rawSender, 'mt:1');
  });

  test('returns null when texts array empty', () {
    final decoded = jsonDecode('{"objectType":"texts","data":{"texts":[]}}')
        as Map<String, dynamic>;
    expect(parseInboundTextsPayload(decoded), isNull);
  });

  test('permissive: includes unsupported module types', () {
    final decoded = jsonDecode(
      '{"objectType":"texts","data":{"texts":[{"text":"x","textId":"1","sender":"S","rawSender":"summarizer:0","senderDetail":{}}]}}',
    ) as Map<String, dynamic>;
    final events = parseInboundTextsPayload(decoded);
    expect(events, hasLength(1));
    expect(events!.single.rawSender, 'summarizer:0');
  });

  test('permissive: includes empty trimmed text', () {
    final decoded = jsonDecode(
      '{"objectType":"texts","data":{"texts":[{"text":"   ","textId":"1","sender":"S","rawSender":"mt:0","senderDetail":{}}]}}',
    ) as Map<String, dynamic>;
    final events = parseInboundTextsPayload(decoded);
    expect(events, hasLength(1));
  });

  test('coerces numeric textId', () {
    final decoded = jsonDecode(
      '{"objectType":"texts","data":{"texts":[{"text":"hi","textId":42,"sender":"S","rawSender":"mt:0","senderDetail":{}}]}}',
    ) as Map<String, dynamic>;
    expect(parseInboundTextsPayload(decoded)!.single.textId, '42');
  });
}
```

`lecture_common/test/inbound/inbound_raw_pcm_parser_test.dart`:

```dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lecture_common/inbound/inbound_raw_pcm_parser.dart';

void main() {
  test('parses raw_pcm with language and index', () {
    final decoded = jsonDecode('''
{"objectType":"raw_pcm","data":{"index":4,"language":"German","rawSender":"tts:0","url":"https://example.com/pcm"}}
''') as Map<String, dynamic>;
    final event = parseInboundRawPcmPayload(decoded);
    expect(event, isNotNull);
    expect(event!.url, 'https://example.com/pcm');
    expect(event.rawSender, 'tts:0');
    expect(event.index, 4);
    expect(event.languageFromPayload, 'German');
  });

  test('parses lt2srv session id from stream url', () {
    final decoded = jsonDecode('''
{"objectType":"raw_pcm","data":{"url":"https://lt2srv.iar.kit.edu/ltapi/stream/data?name=Data/317221/1","rawSender":"tts:0","language":"German"}}
''') as Map<String, dynamic>;
    expect(parseInboundRawPcmPayload(decoded)!.lt2srvSessionId, '317221');
  });

  test('returns null for non-tts rawSender', () {
    final decoded = jsonDecode(
      '{"objectType":"raw_pcm","data":{"url":"https://x","rawSender":"mt:1"}}',
    ) as Map<String, dynamic>;
    expect(parseInboundRawPcmPayload(decoded), isNull);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd /Users/truong-d/Documents/code/lecture_common && flutter test test/inbound/inbound_texts_parser_test.dart test/inbound/inbound_raw_pcm_parser_test.dart
```

Expected: FAIL

- [ ] **Step 3: Implement parsers**

`lecture_common/lib/inbound/inbound_json.dart`:

```dart
import 'dart:convert';

Map<String, dynamic>? decodeInboundJsonMap(String raw) {
  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) return decoded;
    return null;
  } catch (_) {
    return null;
  }
}
```

`lecture_common/lib/inbound/inbound_texts_parser.dart`:

```dart
import '../transcript/domain/transcript_sender_detail.dart';
import '../transcript/domain/transcript_text_event.dart';

/// Permissive parse of `objectType: texts` payload. No module or empty-text filter.
List<TranscriptTextEvent>? parseInboundTextsPayload(
  Map<String, dynamic> decoded,
) {
  final data = decoded['data'];
  if (data is! Map<String, dynamic>) return null;
  final texts = data['texts'];
  if (texts is! List || texts.isEmpty) return null;

  final out = <TranscriptTextEvent>[];
  for (final item in texts) {
    if (item is! Map<String, dynamic>) continue;
    final text = item['text'];
    final sender = item['sender'];
    final rawSender = item['rawSender'];
    if (text is! String || sender is! String || rawSender is! String) {
      continue;
    }
    final sd = item['senderDetail'];
    var speakerName = '';
    var showSpeaker = false;
    if (sd is Map<String, dynamic>) {
      final n = sd['speakerName'];
      if (n is String) speakerName = n;
      showSpeaker = sd['isShowSpeakerName'] == true;
    }
    out.add(
      TranscriptTextEvent(
        text: text,
        isFinal: item['isFinal'] == true,
        textId: '${item['textId']}',
        sender: sender,
        rawSender: rawSender,
        isEndParagraph: item['isEndParagraph'] == true,
        senderDetail: TranscriptSenderDetail(
          speakerName: speakerName,
          isShowSpeakerName: showSpeaker,
        ),
      ),
    );
  }
  if (out.isEmpty) return null;
  return out;
}
```

`lecture_common/lib/inbound/inbound_raw_pcm_parser.dart`:

```dart
import 'lt2srv_pcm_url.dart';
import 'tts_pcm_event.dart';

TtsPcmEvent? parseInboundRawPcmPayload(Map<String, dynamic> decoded) {
  final data = decoded['data'];
  if (data is! Map<String, dynamic>) return null;
  final url = data['url'];
  final rawSender = data['rawSender'];
  if (url is! String || url.isEmpty) return null;
  if (rawSender is! String || !rawSender.startsWith('tts:')) return null;

  String? lang;
  final sd = data['senderDetail'];
  if (sd is Map<String, dynamic>) {
    final l = sd['language'];
    if (l is String && l.isNotEmpty) lang = l;
  }
  lang ??= switch (data['language']) {
    final String s when s.isNotEmpty => s,
    _ => null,
  };

  return TtsPcmEvent(
    url: url,
    rawSender: rawSender,
    index: data['index'] is int ? data['index'] as int : null,
    languageFromPayload: lang,
    lt2srvSessionId: parseLt2srvSessionIdFromPcmUrl(url),
  );
}
```

Fix import in `inbound_raw_pcm_parser.dart` — use only:

```dart
import 'lt2srv_pcm_url.dart';
import 'tts_pcm_event.dart';
```

Add exports to `lecture_common.dart`:

```dart
export 'inbound/inbound_json.dart';
export 'inbound/inbound_texts_parser.dart';
export 'inbound/inbound_raw_pcm_parser.dart';
```

- [ ] **Step 4: Run tests**

```bash
cd /Users/truong-d/Documents/code/lecture_common && flutter test test/inbound/
```

Expected: all PASS

- [ ] **Step 5: Commit**

```bash
cd /Users/truong-d/Documents/code/lecture_common
git add lib/inbound/ test/inbound/ lib/lecture_common.dart
git commit -m "feat(common): add shared inbound texts and raw_pcm parsers"
```

---

### Task 3: `lecture_common` — WebSocket reconnect policy

**Files:**
- Create: `lecture_common/lib/websocket/ws_reconnect_policy.dart`
- Modify: `lecture_common/lib/lecture_common.dart`

- [ ] **Step 1: Copy `ws_reconnect_policy.dart`**

From `app_2way_v3/lib/features/translation_session/data/websocket/ws_reconnect_policy.dart` to `lecture_common/lib/websocket/ws_reconnect_policy.dart` (identical logic).

Export in `lecture_common.dart`:

```dart
export 'websocket/ws_reconnect_policy.dart';
```

- [ ] **Step 2: Analyze**

```bash
cd /Users/truong-d/Documents/code/lecture_common && dart analyze lib/websocket/
```

Expected: No issues

- [ ] **Step 3: Commit**

```bash
cd /Users/truong-d/Documents/code/lecture_common
git add lib/websocket/ws_reconnect_policy.dart lib/lecture_common.dart
git commit -m "feat(common): add shared WebSocket reconnect delay policy"
```

---

### Task 4: `lecture_common` — TTS PCM domain utilities

**Files:**
- Modify: `lecture_common/pubspec.yaml` (add `http: ^1.4.0`)
- Create: `lecture_common/lib/tts/domain/*.dart` (5 files)
- Port tests from `app_2way_v3/test/features/translation_session/domain/tts/`
- Modify: `lecture_common/lib/lecture_common.dart`

- [ ] **Step 1: Add `http` dependency**

In `lecture_common/pubspec.yaml` under `dependencies:`:

```yaml
  http: ^1.4.0
```

Run:

```bash
cd /Users/truong-d/Documents/code/lecture_common && flutter pub get
```

- [ ] **Step 2: Copy TTS domain files**

Copy from `app_2way_v3/lib/features/translation_session/domain/tts/` to `lecture_common/lib/tts/domain/`:

| Source | Destination |
|--------|-------------|
| `tts_pcm_http_fetch.dart` | same name |
| `tts_pcm_base64_payload.dart` | same name |
| `tts_play_start_debug.dart` | same name |
| `tts_play_start_resolver.dart` | same name (keep `import 'tts_play_start_debug.dart';`) |
| `tts_resume_after_duck_resolver.dart` | same name |

No package imports to change inside these files (relative imports only).

- [ ] **Step 3: Port tests**

Copy and update package imports:

| From | To |
|------|-----|
| `app_2way_v3/test/.../tts_pcm_http_fetch_test.dart` | `lecture_common/test/tts/tts_pcm_http_fetch_test.dart` |
| `app_2way_v3/test/.../tts_play_start_resolver_test.dart` | `lecture_common/test/tts/tts_play_start_resolver_test.dart` |
| `app_2way_v3/test/.../tts_resume_after_duck_resolver_test.dart` | `lecture_common/test/tts/tts_resume_after_duck_resolver_test.dart` |

Replace imports like:

```dart
import 'package:app_2way_v3/features/translation_session/domain/tts/tts_pcm_http_fetch.dart';
```

with:

```dart
import 'package:lecture_common/tts/domain/tts_pcm_http_fetch.dart';
```

(or `package:lecture_common/lecture_common.dart` if exported).

- [ ] **Step 4: Export from barrel**

Add to `lecture_common/lib/lecture_common.dart`:

```dart
export 'tts/domain/tts_pcm_http_fetch.dart';
export 'tts/domain/tts_pcm_base64_payload.dart';
export 'tts/domain/tts_play_start_resolver.dart';
export 'tts/domain/tts_resume_after_duck_resolver.dart';
```

- [ ] **Step 5: Run tests**

```bash
cd /Users/truong-d/Documents/code/lecture_common && flutter test test/tts/
```

Expected: PASS

- [ ] **Step 6: Commit**

```bash
cd /Users/truong-d/Documents/code/lecture_common
git add pubspec.yaml pubspec.lock lib/tts/domain/ test/tts/ lib/lecture_common.dart
git commit -m "feat(common): move shared TTS PCM domain utilities"
```

---

### Task 5: `app_2way_v3` — adopt common inbound + delete duplicates

**Files:**
- Modify: `lib/features/translation_session/domain/inbound/translation_inbound_parser.dart`
- Modify: imports in `translation_inbound_handler.dart`, `translation_tts_language_resolution.dart`, `translation_websocket_client.dart`, `tts_soloud_pane_engine.dart`
- Delete: 7 files listed in spec §5
- Delete: `test/.../lt2srv_pcm_url_test.dart` (moved to common)
- Modify: `test/.../translation_inbound_parser_test.dart` (unchanged behavior; still tests app router)

- [ ] **Step 1: Rewrite `translation_inbound_parser.dart`**

```dart
import 'package:lecture_common/lecture_common.dart';

import 'package:app_2way_v3/features/translation_session/data/websocket/mt_text_event.dart';

sealed class TranslationInboundMessage {
  const TranslationInboundMessage();
}

final class InboundMtTexts extends TranslationInboundMessage {
  const InboundMtTexts(this.events);
  final List<MtTextEvent> events;
}

final class InboundTtsPcm extends TranslationInboundMessage {
  const InboundTtsPcm(this.event);
  final TtsPcmEvent event;
}

final class InboundIgnored extends TranslationInboundMessage {
  const InboundIgnored();
}

TranslationInboundMessage parseTranslationInbound(String raw) {
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
}
```

- [ ] **Step 2: Update imports across 2-way**

| File | Change |
|------|--------|
| `translation_inbound_handler.dart` | `TtsPcmEvent` from `lecture_common` |
| `translation_tts_language_resolution.dart` | `TtsPcmEvent` from `lecture_common` |
| `translation_websocket_client.dart` | `reconnectDelay` from `lecture_common` |
| `tts_soloud_pane_engine.dart` | `fetchTtsPcmChunk`, `pcmBase64PayloadFromHttpBody`, resolvers from `lecture_common` |

- [ ] **Step 3: Delete moved files**

```bash
cd /Users/truong-d/Documents/code/app_2way_v3
rm lib/features/translation_session/data/websocket/tts_pcm_event.dart
rm lib/features/translation_session/domain/inbound/lt2srv_pcm_url.dart
rm lib/features/translation_session/data/websocket/ws_reconnect_policy.dart
rm lib/features/translation_session/domain/tts/tts_pcm_http_fetch.dart
rm lib/features/translation_session/domain/tts/tts_pcm_base64_payload.dart
rm lib/features/translation_session/domain/tts/tts_play_start_resolver.dart
rm lib/features/translation_session/domain/tts/tts_resume_after_duck_resolver.dart
rm test/features/translation_session/domain/inbound/lt2srv_pcm_url_test.dart
```

Keep `tts_play_start_debug.dart` in app **only if** still referenced locally; otherwise delete if unused after soloud engine imports common resolver (debug moves to common).

- [ ] **Step 4: Run 2-way tests**

```bash
cd /Users/truong-d/Documents/code/app_2way_v3 && flutter pub get && flutter test test/features/translation_session/domain/inbound/ test/features/translation_session/domain/tts/
```

Expected: PASS (TTS unit tests for moved files should be removed from app or deleted — only integration tests remain in app)

- [ ] **Step 5: Full analyze**

```bash
cd /Users/truong-d/Documents/code/app_2way_v3 && dart analyze lib/features/translation_session/
```

- [ ] **Step 6: Commit**

```bash
cd /Users/truong-d/Documents/code/app_2way_v3
git add -A lib/features/translation_session/ test/features/translation_session/
git commit -m "refactor(2way): use lecture_common wire protocol and TTS utilities"
```

---

### Task 6: `lecture_viewer_v3` — filter wrapper + adopt common types

**Files:**
- Create: `lib/features/lecture_session/domain/transcript/lecture_transcript_event_filter.dart`
- Create: `test/features/lecture_session/lecture_transcript_event_filter_test.dart`
- Modify: `lecture_inbound_parser.dart`, `lecture_inbound_message.dart`, `lecture_session_notifier.dart`, `lecture_tts_language.dart`, `lecture_session_websocket_client.dart`, `tts_soloud_pane_engine.dart`
- Delete: 6 files from spec §5

- [ ] **Step 1: Add filter + test**

`lecture_transcript_event_filter.dart`:

```dart
import 'package:lecture_common/lecture_common.dart';

import 'lecture_supported_modules.dart';

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

`lecture_transcript_event_filter_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lecture_common/lecture_common.dart';
import 'package:lecture_viewer_v3/features/lecture_session/domain/transcript/lecture_transcript_event_filter.dart';

void main() {
  test('drops unsupported module types', () {
    const events = [
      TranscriptTextEvent(
        text: 'x',
        isFinal: true,
        textId: '1',
        sender: 'S',
        rawSender: 'summarizer:0',
        isEndParagraph: false,
        senderDetail: TranscriptSenderDetail(),
      ),
      TranscriptTextEvent(
        text: 'ok',
        isFinal: true,
        textId: '2',
        sender: 'S',
        rawSender: 'mt:0',
        isEndParagraph: false,
        senderDetail: TranscriptSenderDetail(),
      ),
    ];
    final filtered = filterLectureTranscriptEvents(events);
    expect(filtered, hasLength(1));
    expect(filtered.single.rawSender, 'mt:0');
  });

  test('drops empty trimmed text', () {
    const events = [
      TranscriptTextEvent(
        text: '   ',
        isFinal: true,
        textId: '1',
        sender: 'S',
        rawSender: 'mt:0',
        isEndParagraph: false,
        senderDetail: TranscriptSenderDetail(),
      ),
    ];
    expect(filterLectureTranscriptEvents(events), isEmpty);
  });
}
```

- [ ] **Step 2: Rewrite `lecture_inbound_parser.dart` texts/raw_pcm branches**

Replace local `_parseTexts` / `_parseRawPcm` with:

```dart
import 'package:lecture_common/lecture_common.dart';
// ... keep existing imports except remove lecture_tts_pcm_event.dart
import 'package:lecture_viewer_v3/features/lecture_session/domain/transcript/lecture_transcript_event_filter.dart';

// In parseLectureInbound switch:
'texts' => () {
  final parsed = parseInboundTextsPayload(decoded);
  if (parsed == null) return const LectureInboundIgnored();
  final events = filterLectureTranscriptEvents(parsed);
  if (events.isEmpty) return const LectureInboundIgnored();
  return LectureInboundTexts(events);
}(),
'raw_pcm' => () {
  final event = parseInboundRawPcmPayload(decoded);
  if (event == null) return const LectureInboundIgnored();
  return LectureInboundTtsPcm(event);
}(),
```

Use `decodeInboundJsonMap(raw)` at top instead of inline `jsonDecode`.

Remove private `_parseTexts` and `_parseRawPcm` methods.

- [ ] **Step 3: Update `LectureInboundTtsPcm` to use `TtsPcmEvent`**

In `lecture_inbound_message.dart`:

```dart
final class LectureInboundTtsPcm extends LectureInboundMessage {
  const LectureInboundTtsPcm(this.event);
  final TtsPcmEvent event;
}
```

Update `lecture_session_notifier.dart` `_handleTtsPcm(TtsPcmEvent event)` and `lecture_tts_language.dart` parameter type.

- [ ] **Step 4: Update WS + TTS imports; delete moved files**

Same pattern as Task 5 for `lecture_session_websocket_client.dart` and `tts_soloud_pane_engine.dart`.

Delete:

```bash
cd /Users/truong-d/Documents/code/lecture_viewer_v3
rm lib/features/lecture_session/data/inbound/lecture_tts_pcm_event.dart
rm lib/features/lecture_session/data/websocket/ws_reconnect_policy.dart
rm lib/features/lecture_session/domain/tts/tts_pcm_http_fetch.dart
rm lib/features/lecture_session/domain/tts/tts_pcm_base64_payload.dart
rm lib/features/lecture_session/domain/tts/tts_play_start_resolver.dart
rm lib/features/lecture_session/domain/tts/tts_resume_after_duck_resolver.dart
```

Delete duplicated TTS tests from viewer if ported to common.

- [ ] **Step 5: Run viewer tests**

```bash
cd /Users/truong-d/Documents/code/lecture_viewer_v3 && flutter pub get && flutter test test/features/lecture_session/
```

Expected: PASS

- [ ] **Step 6: Commit**

```bash
cd /Users/truong-d/Documents/code/lecture_viewer_v3
git add -A lib/features/lecture_session/ test/features/lecture_session/
git commit -m "refactor(viewer): use lecture_common wire protocol and TTS utilities"
```

---

### Task 7: Final verification (all packages)

- [ ] **Step 1: Run full test suites**

```bash
cd /Users/truong-d/Documents/code/lecture_common && flutter test
cd /Users/truong-d/Documents/code/app_2way_v3 && flutter test
cd /Users/truong-d/Documents/code/lecture_viewer_v3 && flutter test
```

Expected: all PASS

- [ ] **Step 2: Analyze**

```bash
cd /Users/truong-d/Documents/code/lecture_common && dart analyze
cd /Users/truong-d/Documents/code/app_2way_v3 && dart analyze
cd /Users/truong-d/Documents/code/lecture_viewer_v3 && dart analyze
```

Expected: no errors

- [ ] **Step 3: Manual smoke (optional)**

- 2-way: start session, confirm transcript + TTS PCM still work; confirm uplink still sends.
- Viewer: join session, confirm transcript filters summarizer/tts text modules; TTS playback works.

---

## Spec coverage checklist

| Spec requirement | Task |
|------------------|------|
| Shared `decodeInboundJsonMap` | Task 2 |
| Permissive `parseInboundTextsPayload` | Task 2 |
| `parseInboundRawPcmPayload` + `lt2srvSessionId` | Task 1–2 |
| Unified `TtsPcmEvent` | Task 1 |
| `ws_reconnect_policy` | Task 3 |
| TTS PCM utilities | Task 4 |
| 2-way thin parser | Task 5 |
| Viewer filter after parse | Task 6 |
| PCM uplink stays in 2-way | Task 5/7 (no WS send changes) |
| Tests in common + app parser tests | Tasks 1–2, 4–7 |

## Execution handoff

Plan complete and saved to `lecture_common/docs/superpowers/plans/2026-05-19-session-wire-protocol-implementation-plan.md`.

**Two execution options:**

1. **Subagent-Driven (recommended)** — fresh subagent per task, review between tasks  
2. **Inline Execution** — implement tasks in this session with checkpoints  

Which approach do you want?
