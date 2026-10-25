# Lecture Viewer TTS Playback Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add selected-language TTS playback to the lecture meeting view with collapsed play/pause and expanded `TranslationTtsTransport`, continuous play after user taps Play until Pause.

**Architecture:** Viewer-local stack ported from `app_2way_v3`: parse `raw_pcm`, gate by `selectedLanguage`, single `TtsSoloudPaneEngine` behind `LectureTtsController`, Riverpod state on `LectureSessionNotifier`, UI in `LectureSessionControls`. Shared widgets from `lecture_common` only.

**Tech stack:** Flutter 3.10+, `flutter_soloud` ^3.5.4, `http`, `lecture_common`, `flutter_riverpod`.

**Spec:** `docs/superpowers/specs/2026-05-18-lecture-viewer-tts-design.md`

---

## File map

### Create (`lecture_viewer_v3`)

| Path | Responsibility |
|------|----------------|
| `lib/core/bootstrap/soloud_engine.dart` | Init/deinit SoLoud (from 2-way) |
| `lib/app/soloud_lifecycle_binding.dart` | Lifecycle teardown |
| `lib/features/lecture_session/data/inbound/lecture_tts_pcm_event.dart` | PCM event model |
| `lib/features/lecture_session/domain/tts/tts_pcm_base64_payload.dart` | Base64 decode (from 2-way) |
| `lib/features/lecture_session/domain/tts/tts_pcm_http_fetch.dart` | HTTP fetch with retries |
| `lib/features/lecture_session/domain/tts/tts_play_start_resolver.dart` | Playhead tail-join (from 2-way) |
| `lib/features/lecture_session/domain/tts/tts_resume_after_duck_resolver.dart` | Used by engine port |
| `lib/features/lecture_session/domain/tts/tts_soloud_pane_engine.dart` | SoLoud buffer + continuous play |
| `lib/features/lecture_session/domain/tts/lecture_tts_controller.dart` | Thin wrapper: enqueue, toggle, seek, reset |
| `lib/features/lecture_session/domain/tts/lecture_tts_language.dart` | `resolveLectureTtsLanguage` |
| `test/features/lecture_session/lecture_tts_language_test.dart` | Language resolve tests |
| `test/features/lecture_session/lecture_tts_gate_test.dart` | Gate helper tests (pure function) |
| `test/features/lecture_session/lecture_session_controls_tts_test.dart` | Widget: collapsed play enabled/disabled |

### Modify

| Path | Change |
|------|--------|
| `pubspec.yaml` | `flutter_soloud`, `http` |
| `lib/main.dart` | `initializeSoloudEngine()`, wrap `SoloudLifecycleBinding` |
| `lib/features/lecture_session/data/inbound/lecture_inbound_message.dart` | `LectureInboundTtsPcm` variant |
| `lib/features/lecture_session/data/inbound/lecture_inbound_parser.dart` | `raw_pcm` branch |
| `test/features/lecture_session/lecture_inbound_parser_test.dart` | PCM parser tests |
| `lib/features/lecture_session/presentation/lecture_session_state.dart` | `tts: TtsPaneSnapshot` |
| `lib/features/lecture_session/presentation/providers/lecture_session_notifier.dart` | PCM routing, TTS APIs, language reset |
| `lib/features/lecture_session/presentation/lecture_session_controls.dart` | Collapsed play + expanded transport |

---

## Phase 1 — Dependencies & SoLoud bootstrap

### Task 1: Add packages and SoLoud init

**Files:**
- Modify: `lecture_viewer_v3/pubspec.yaml`
- Create: `lib/core/bootstrap/soloud_engine.dart`
- Create: `lib/app/soloud_lifecycle_binding.dart`
- Modify: `lib/main.dart`

- [ ] **Step 1:** Add to `pubspec.yaml` under `dependencies`:

```yaml
  flutter_soloud: ^3.5.4
  http: ^1.2.2
```

- [ ] **Step 2:** Copy `app_2way_v3/lib/common/bootstrap/soloud_engine.dart` → `lib/core/bootstrap/soloud_engine.dart` (update imports only if needed — file has no app-specific imports).

- [ ] **Step 3:** Copy `app_2way_v3/lib/common/bootstrap/soloud_lifecycle_binding.dart` → `lib/app/soloud_lifecycle_binding.dart`, change import to:

```dart
import 'package:lecture_viewer_v3/core/bootstrap/soloud_engine.dart';
```

- [ ] **Step 4:** Update `lib/main.dart`:

```dart
import 'package:lecture_viewer_v3/app/soloud_lifecycle_binding.dart';
import 'package:lecture_viewer_v3/core/bootstrap/soloud_engine.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeSoloudEngine();
  await FlutterBranchSdk.init();
  // ... existing code ...
  runApp(
    ProviderScope(
      overrides: [/* ... */],
      child: const SoloudLifecycleBinding(
        child: WakelockLifecycleBinding(
          child: BranchSessionListener(
            child: LectureViewerApp(),
          ),
        ),
      ),
    ),
  );
}
```

(`SoloudLifecycleBinding` wraps the existing tree — same nesting as `app_2way_v3/main.dart`.)

- [ ] **Step 5:** Run:

```bash
cd /Users/truong-d/Documents/code/lecture_viewer_v3 && flutter pub get && flutter analyze lib/main.dart lib/core/bootstrap/soloud_engine.dart lib/app/soloud_lifecycle_binding.dart
```

Expected: no errors.

- [ ] **Step 6: Commit**

```bash
cd /Users/truong-d/Documents/code/lecture_viewer_v3
git add pubspec.yaml pubspec.lock lib/core/bootstrap/soloud_engine.dart lib/app/soloud_lifecycle_binding.dart lib/main.dart
git commit -m "feat(viewer): add flutter_soloud bootstrap for lecture TTS"
```

---

## Phase 2 — Port playback engine from 2-way

### Task 2: PCM helpers and play resolvers

**Files:**
- Create: `lib/features/lecture_session/domain/tts/tts_pcm_base64_payload.dart`
- Create: `lib/features/lecture_session/domain/tts/tts_pcm_http_fetch.dart`
- Create: `lib/features/lecture_session/domain/tts/tts_play_start_resolver.dart`
- Create: `lib/features/lecture_session/domain/tts/tts_resume_after_duck_resolver.dart`
- Create: `lib/features/lecture_session/domain/tts/tts_play_start_debug.dart` (if referenced by engine — copy from 2-way or strip debug calls)

Copy from `app_2way_v3/lib/features/translation_session/domain/tts/` counterparts. Fix imports to `package:lecture_viewer_v3/...`.

- [ ] **Step 1:** Copy files; run:

```bash
cd /Users/truong-d/Documents/code/lecture_viewer_v3 && flutter analyze lib/features/lecture_session/domain/tts/
```

- [ ] **Step 2:** Copy resolver unit tests (optional but recommended):

```bash
cp ../app_2way_v3/test/features/translation_session/domain/tts/tts_play_start_resolver_test.dart \
   test/features/lecture_session/tts_play_start_resolver_test.dart
```

Update imports to viewer package paths. Run:

```bash
flutter test test/features/lecture_session/tts_play_start_resolver_test.dart
```

Expected: PASS.

- [ ] **Step 3: Commit**

```bash
git add lib/features/lecture_session/domain/tts/ test/features/lecture_session/
git commit -m "feat(viewer): port TTS PCM fetch and play-start resolvers"
```

---

### Task 3: `TtsSoloudPaneEngine` + `LectureTtsController`

**Files:**
- Create: `lib/features/lecture_session/domain/tts/tts_soloud_pane_engine.dart`
- Create: `lib/features/lecture_session/domain/tts/lecture_tts_controller.dart`

- [ ] **Step 1:** Copy `tts_soloud_pane_engine.dart` from 2-way. Change:

```dart
import 'package:lecture_common/lecture_common.dart' show TtsPaneSnapshot;
```

Remove any local `tts_pane_snapshot.dart` import. Keep `_userWantsPlayback` / `_resumePlaybackIfNeededAfterAppend` logic **unchanged** (continuous play after Play).

- [ ] **Step 2:** Create `lecture_tts_controller.dart`:

```dart
import 'package:lecture_common/lecture_common.dart';

import 'tts_soloud_pane_engine.dart';

final class LectureTtsController {
  LectureTtsController({required void Function(TtsPaneSnapshot) onSnapshot})
      : _engine = TtsSoloudPaneEngine(onSnapshot: onSnapshot);

  final TtsSoloudPaneEngine _engine;

  void enqueue(String url) => _engine.enqueue(url);

  Future<void> playPauseFromUser() async {
    // Engine updates snapshot via callback; read playing state from latest
    // callback before tap — notifier should track via state.tts.isPlaying.
    // Simplest: pass isPlaying into this method from notifier:
    // playPauseFromUser({required bool isPlaying}) ...
    if (isPlaying) {
      await _engine.pauseFromUserTap();
    } else {
      await _engine.playFromUserTap();
    }
  }

  void seekEnd(double normalized) => _engine.seekToNormalized(normalized);

  Future<void> reset() => _engine.clear();

  Future<void> dispose() => _engine.dispose();
}
```

**Notifier calls:** `playPauseFromUser(isPlaying: state.tts.isPlaying)` so toggle uses Riverpod state, not a stale local field. Engine `clear()` clears buffer and sets `_userWantsPlayback = false` (per 2-way).

- [ ] **Step 3:** Run `flutter analyze` on both files.

- [ ] **Step 4: Commit**

```bash
git add lib/features/lecture_session/domain/tts/tts_soloud_pane_engine.dart \
        lib/features/lecture_session/domain/tts/lecture_tts_controller.dart
git commit -m "feat(viewer): add single-pane TTS SoLoud engine and controller"
```

---

## Phase 3 — Inbound parse & language routing (TDD)

### Task 4: PCM event + parser tests

**Files:**
- Create: `lib/features/lecture_session/data/inbound/lecture_tts_pcm_event.dart`
- Modify: `lib/features/lecture_session/data/inbound/lecture_inbound_message.dart`
- Modify: `lib/features/lecture_session/data/inbound/lecture_inbound_parser.dart`
- Modify: `test/features/lecture_session/lecture_inbound_parser_test.dart`

- [ ] **Step 1: Write failing parser tests** — append to `lecture_inbound_parser_test.dart`:

```dart
  test('parses raw_pcm for tts sender', () {
    const json = '''
{"objectType":"raw_pcm","data":{"url":"https://example.com/pcm","rawSender":"tts:1","language":"German","index":3}}
''';
    final message = parseLectureInbound(json);
    expect(message, isA<LectureInboundTtsPcm>());
    final pcm = message as LectureInboundTtsPcm;
    expect(pcm.event.url, 'https://example.com/pcm');
    expect(pcm.event.rawSender, 'tts:1');
    expect(pcm.event.languageFromPayload, 'German');
    expect(pcm.event.index, 3);
  });

  test('raw_pcm without url is ignored', () {
    const json =
        '{"objectType":"raw_pcm","data":{"rawSender":"tts:0","language":"English"}}';
    expect(parseLectureInbound(json), isA<LectureInboundIgnored>());
  });

  test('raw_pcm with non-tts rawSender is ignored', () {
    const json =
        '{"objectType":"raw_pcm","data":{"url":"https://x","rawSender":"mt:0","language":"English"}}';
    expect(parseLectureInbound(json), isA<LectureInboundIgnored>());
  });
```

- [ ] **Step 2:** Run — expect FAIL (undefined `LectureInboundTtsPcm`):

```bash
flutter test test/features/lecture_session/lecture_inbound_parser_test.dart
```

- [ ] **Step 3:** Add `lecture_tts_pcm_event.dart`:

```dart
class LectureTtsPcmEvent {
  const LectureTtsPcmEvent({
    required this.url,
    required this.rawSender,
    this.languageFromPayload,
    this.index,
  });

  final String url;
  final String rawSender;
  final String? languageFromPayload;
  final int? index;
}
```

Add to `lecture_inbound_message.dart`:

```dart
final class LectureInboundTtsPcm extends LectureInboundMessage {
  const LectureInboundTtsPcm(this.event);
  final LectureTtsPcmEvent event;
}
```

Update parser switch:

```dart
    return switch (decoded['objectType']) {
      'info' => _parseInfo(decoded),
      'texts' => _parseTexts(decoded),
      'raw_pcm' => _parseRawPcm(decoded) ?? const LectureInboundIgnored(),
      _ => const LectureInboundIgnored(),
    };
```

Add `_parseRawPcm` — copy body from `app_2way_v3/.../translation_inbound_parser.dart` `_parseRawPcm`, returning `LectureInboundTtsPcm(LectureTtsPcmEvent(...))` (omit `lt2srvSessionId` unless needed later).

- [ ] **Step 4:** Run tests — expect PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/lecture_session/data/inbound/ test/features/lecture_session/lecture_inbound_parser_test.dart
git commit -m "feat(viewer): parse raw_pcm TTS inbound messages"
```

---

### Task 5: Language resolution + gate

**Files:**
- Create: `lib/features/lecture_session/domain/tts/lecture_tts_language.dart`
- Create: `lib/features/lecture_session/domain/tts/lecture_tts_gate.dart`
- Create: `test/features/lecture_session/lecture_tts_language_test.dart`
- Create: `test/features/lecture_session/lecture_tts_gate_test.dart`

- [ ] **Step 1: Write failing tests** for `lecture_tts_language_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lecture_viewer_v3/features/lecture_session/data/inbound/lecture_tts_pcm_event.dart';
import 'package:lecture_viewer_v3/features/lecture_session/domain/transcript/computed_sender_info.dart';
import 'package:lecture_viewer_v3/features/lecture_session/domain/tts/lecture_tts_language.dart';

void main() {
  final senders = {
    'tts:1': const ComputedSenderInfo(
      language: 'German',
      type: 'tts',
      percent: 0,
    ),
  };

  test('prefers languageFromPayload', () {
    const event = LectureTtsPcmEvent(
      url: 'u',
      rawSender: 'tts:1',
      languageFromPayload: 'German',
    );
    expect(resolveLectureTtsLanguage(event, senders), 'German');
  });

  test('falls back to computedSenders', () {
    const event = LectureTtsPcmEvent(url: 'u', rawSender: 'tts:1');
    expect(resolveLectureTtsLanguage(event, senders), 'German');
  });

  test('returns null when unknown', () {
    const event = LectureTtsPcmEvent(url: 'u', rawSender: 'tts:9');
    expect(resolveLectureTtsLanguage(event, senders), isNull);
  });
}
```

`lecture_tts_gate_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lecture_viewer_v3/features/lecture_session/domain/tts/lecture_tts_gate.dart';

void main() {
  test('shouldEnqueue when language matches selected', () {
    expect(shouldEnqueueTtsForLanguage('German', 'German'), isTrue);
    expect(shouldEnqueueTtsForLanguage('English', 'German'), isFalse);
  });
}
```

- [ ] **Step 2:** Run tests — expect FAIL.

- [ ] **Step 3:** Implement:

```dart
// lecture_tts_language.dart
String? resolveLectureTtsLanguage(
  LectureTtsPcmEvent event,
  Map<String, ComputedSenderInfo> computedSenders,
) {
  final hint = event.languageFromPayload;
  if (hint != null && hint.isNotEmpty) return hint;
  return computedSenders[event.rawSender]?.language;
}
```

```dart
// lecture_tts_gate.dart
bool shouldEnqueueTtsForLanguage(String resolved, String selectedLanguage) =>
    resolved == selectedLanguage;
```

- [ ] **Step 4:** Run tests — PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/lecture_session/domain/tts/lecture_tts_language.dart \
        lib/features/lecture_session/domain/tts/lecture_tts_gate.dart \
        test/features/lecture_session/lecture_tts_language_test.dart \
        test/features/lecture_session/lecture_tts_gate_test.dart
git commit -m "feat(viewer): add TTS language resolve and enqueue gate"
```

---

## Phase 4 — Notifier wiring

### Task 6: `LectureSessionState` + `LectureSessionNotifier`

**Files:**
- Modify: `lib/features/lecture_session/presentation/lecture_session_state.dart`
- Modify: `lib/features/lecture_session/presentation/providers/lecture_session_notifier.dart`

- [ ] **Step 1:** Add to `LectureSessionState`:

```dart
  this.tts = const TtsPaneSnapshot(),
  // field:
  final TtsPaneSnapshot tts;
  // copyWith: TtsPaneSnapshot? tts,
```

- [ ] **Step 2:** In `LectureSessionNotifier`:

```dart
  LectureTtsController? _tts;

  LectureTtsController _ensureTts() {
    return _tts ??= LectureTtsController(
      onSnapshot: (snap) {
        state = state.copyWith(tts: snap);
      },
    );
  }

  void _handleTtsPcm(LectureTtsPcmEvent event) {
    final lang = resolveLectureTtsLanguage(event, state.computedSenders);
    if (lang == null) return;
    if (!shouldEnqueueTtsForLanguage(lang, state.selectedLanguage)) return;
    _ensureTts().enqueue(event.url);
  }

  void ttsPlayPause() {
    unawaited(_ensureTts().playPauseFromUser(isPlaying: state.tts.isPlaying));
  }

  void ttsSeekEnd(double normalized) {
    _ensureTts().seekEnd(normalized);
  }

  Future<void> _resetTtsForLanguageChange() async {
    await _tts?.reset();
    state = state.copyWith(tts: const TtsPaneSnapshot());
  }
```

- [ ] **Step 3:** In `_onRawMessage`, add case:

```dart
      case LectureInboundTtsPcm(:final event):
        _handleTtsPcm(event);
```

Remove or narrow `LectureInboundIgnored` debug for valid PCM (optional).

- [ ] **Step 4:** In `setLanguage`, **before** `copyWith(selectedLanguage: ...)`:

```dart
    if (language != state.selectedLanguage) {
      unawaited(_resetTtsForLanguageChange());
    }
```

- [ ] **Step 5:** In `ref.onDispose` / `_dispose`, add `_tts?.dispose(); _tts = null;`.

- [ ] **Step 6:** Run:

```bash
flutter analyze lib/features/lecture_session/presentation/
```

- [ ] **Step 7: Commit**

```bash
git add lib/features/lecture_session/presentation/
git commit -m "feat(viewer): wire TTS PCM enqueue and playback to session notifier"
```

---

## Phase 5 — UI

### Task 7: `LectureSessionControls` TTS UI

**Files:**
- Modify: `lib/features/lecture_session/presentation/lecture_session_controls.dart`
- Create: `test/features/lecture_session/lecture_session_controls_tts_test.dart`

- [ ] **Step 1: Widget test** — pump controls with overridden provider, empty `tts` → play `IconButton` disabled; `bufferedDurationSec: 5` → enabled.

- [ ] **Step 2:** In `lecture_session_controls.dart`:

Watch TTS:

```dart
    final tts = ref.watch(
      lectureSessionProvider(widget.sessionId).select((s) => s.tts),
    );
    final notifier = ref.read(lectureSessionProvider(widget.sessionId).notifier);
```

Collapsed row — insert before summary `Expanded`:

```dart
                    IconButton(
                      tooltip: tts.isPlaying ? 'Pause TTS' : 'Play TTS',
                      onPressed: tts.bufferedDurationSec > 0
                          ? notifier.ttsPlayPause
                          : null,
                      style: IconButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: Icon(
                        tts.isPlaying ? Icons.pause : Icons.play_arrow,
                      ),
                    ),
```

Expanded section — after font-size row, before closing `if (_expanded)`:

```dart
              TranslationTtsTransport(
                snapshot: tts,
                onPlayPause: notifier.ttsPlayPause,
                onSeekEnd: notifier.ttsSeekEnd,
              ),
```

Add import: `package:lecture_common/lecture_common.dart`.

- [ ] **Step 3:** Run:

```bash
flutter test test/features/lecture_session/lecture_session_controls_tts_test.dart
flutter analyze lib/features/lecture_session/presentation/lecture_session_controls.dart
```

- [ ] **Step 4: Commit**

```bash
git add lib/features/lecture_session/presentation/lecture_session_controls.dart \
        test/features/lecture_session/lecture_session_controls_tts_test.dart
git commit -m "feat(viewer): add collapsed and expanded TTS controls to session bar"
```

---

## Phase 6 — Verification

### Task 8: Full test pass and manual QA

- [ ] **Step 1:**

```bash
cd /Users/truong-d/Documents/code/lecture_viewer_v3 && flutter test
```

Expected: all tests PASS.

- [ ] **Step 2:**

```bash
flutter analyze
```

Expected: no issues in changed files.

- [ ] **Step 3: Manual QA** (live session):

1. Join multi-language session — only selected language buffers TTS.  
2. Tap Play once — audio continues as new chunks arrive; Pause stops.  
3. Collapsed play/pause works.  
4. Expanded seek works.  
5. Change language — buffer resets; Play again on new language.  
6. Change shortening only — TTS unchanged.  
7. Leave and re-enter session — no crash.

- [ ] **Step 4: Commit** (if any fixups):

```bash
git add -A && git commit -m "fix(viewer): address TTS playback QA findings"
```

---

## Spec coverage checklist

| Spec requirement | Task |
|------------------|------|
| Parse `raw_pcm` / `tts:` only | Task 4 |
| Selected-language gate | Task 5, 6 |
| Continuous play after Play | Task 3 (ported engine) |
| Manual start / Pause stops | Task 3, 7 |
| Language change reset | Task 6 |
| Shortening change no reset | Task 6 (only `setLanguage` resets) |
| Collapsed play/pause | Task 7 |
| Expanded `TranslationTtsTransport` | Task 7 |
| SoLoud bootstrap | Task 1 |
| `lecture_common` UI only | Task 7 import |
| Tests | Tasks 4, 5, 7, 8 |

---

## Out of scope (do not implement)

- `lecture_common` playback extract  
- `app_2way_v3` changes  
- Auto-TTS / mic  
- Multi-language TTS buffer retention  
