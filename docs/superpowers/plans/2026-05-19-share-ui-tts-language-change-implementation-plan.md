# Share UI simplification + TTS on language change Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove the redundant “Include transcript” toggle from the lecture share sheet, and keep live TTS playback intent when the user changes language while TTS is playing (auto-play new-language PCM; stay paused if TTS was paused).

**Architecture:** Share sheet becomes language/module selection only. TTS uses `clearBuffer(preserveUserPlaybackIntent:)` on `TtsSoloudPaneEngine` plus a small pure `preserveTtsPlaybackOnLanguageChange` helper for notifier decisions (testable without SoLoud). `setLanguage` clears buffer before updating `selectedLanguage`; `setModule` unchanged.

**Tech stack:** Flutter 3.10+, `flutter_riverpod`, `flutter_soloud`, `share_plus`, existing `lecture_session` feature.

**Spec:** `docs/superpowers/specs/2026-05-19-share-ui-tts-language-change-design.md`

---

## File map

| Path | Responsibility |
|------|----------------|
| `lib/features/lecture_session/presentation/lecture_share_sheet.dart` | Remove include-transcript toggle and guard |
| `test/features/lecture_session/lecture_share_sheet_test.dart` | Assert toggle absent |
| `lib/features/lecture_session/domain/tts/tts_language_change.dart` | **New** — pure preserve-intent helper |
| `test/features/lecture_session/tts_language_change_test.dart` | **New** — unit tests for helper |
| `lib/features/lecture_session/domain/tts/tts_soloud_pane_engine.dart` | `clearBuffer({preserveUserPlaybackIntent})`; `clear()` delegates |
| `lib/features/lecture_session/domain/tts/lecture_tts_controller.dart` | `userWantsPlayback` getter; `clearForLanguageChange` |
| `lib/features/lecture_session/presentation/providers/lecture_session_notifier.dart` | `_clearTtsForLanguageChange(language)` with preserve logic |

---

### Task 1: Share sheet — remove “Include transcript”

**Files:**
- Modify: `lib/features/lecture_session/presentation/lecture_share_sheet.dart`
- Modify: `test/features/lecture_session/lecture_share_sheet_test.dart`

- [ ] **Step 1: Update widget test** — in `lecture_share_sheet_test.dart`, after `pumpAndSettle` on the sheet, add:

```dart
    expect(find.text('Include transcript'), findsNothing);
```

(Keep existing `Include recording` assertion.)

- [ ] **Step 2: Run test to verify it fails**

```bash
cd /Users/macbook/Works/Lecture_Translation_Alex/lecture_viewer_v3 && flutter test test/features/lecture_session/lecture_share_sheet_test.dart -v
```

Expected: FAIL — finds one widget with text `Include transcript`.

- [ ] **Step 3: Remove toggle from sheet** — in `lecture_share_sheet.dart`:

1. Delete field `bool _includeTranscript = true;`
2. In `_shareSelected`, delete block:

```dart
    if (!_includeTranscript) {
      _showSnack('Choose transcript to share');
      return;
    }
```

3. Delete the `SwitchListTile` for “Include transcript” (lines ~190–195).

- [ ] **Step 4: Run test and analyzer**

```bash
cd /Users/macbook/Works/Lecture_Translation_Alex/lecture_viewer_v3 && flutter test test/features/lecture_session/lecture_share_sheet_test.dart -v
dart analyze lib/features/lecture_session/presentation/lecture_share_sheet.dart
```

Expected: test PASS; no analyzer issues.

- [ ] **Step 5: Commit**

```bash
cd /Users/macbook/Works/Lecture_Translation_Alex/lecture_viewer_v3
git add lib/features/lecture_session/presentation/lecture_share_sheet.dart test/features/lecture_session/lecture_share_sheet_test.dart
git commit -m "fix(viewer): remove include-transcript toggle from share sheet"
```

---

### Task 2: TTS language-change intent helper (TDD)

**Files:**
- Create: `lib/features/lecture_session/domain/tts/tts_language_change.dart`
- Create: `test/features/lecture_session/tts_language_change_test.dart`

- [ ] **Step 1: Write failing tests** — create `test/features/lecture_session/tts_language_change_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lecture_viewer_v3/features/lecture_session/domain/tts/tts_language_change.dart';

void main() {
  group('preserveTtsPlaybackOnLanguageChange', () {
    test('true when user wants playback and new language supports TTS', () {
      expect(
        preserveTtsPlaybackOnLanguageChange(
          userWantsPlayback: true,
          newLanguageSupportsTts: true,
        ),
        isTrue,
      );
    });

    test('false when user paused (no playback intent)', () {
      expect(
        preserveTtsPlaybackOnLanguageChange(
          userWantsPlayback: false,
          newLanguageSupportsTts: true,
        ),
        isFalse,
      );
    });

    test('false when new language has no TTS route', () {
      expect(
        preserveTtsPlaybackOnLanguageChange(
          userWantsPlayback: true,
          newLanguageSupportsTts: false,
        ),
        isFalse,
      );
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd /Users/macbook/Works/Lecture_Translation_Alex/lecture_viewer_v3 && flutter test test/features/lecture_session/tts_language_change_test.dart -v
```

Expected: FAIL — library / function not found.

- [ ] **Step 3: Implement helper** — create `lib/features/lecture_session/domain/tts/tts_language_change.dart`:

```dart
/// Whether [clearBuffer] should keep [_userWantsPlayback] when switching language.
bool preserveTtsPlaybackOnLanguageChange({
  required bool userWantsPlayback,
  required bool newLanguageSupportsTts,
}) =>
    userWantsPlayback && newLanguageSupportsTts;
```

- [ ] **Step 4: Run tests**

```bash
cd /Users/macbook/Works/Lecture_Translation_Alex/lecture_viewer_v3 && flutter test test/features/lecture_session/tts_language_change_test.dart -v
```

Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
cd /Users/macbook/Works/Lecture_Translation_Alex/lecture_viewer_v3
git add lib/features/lecture_session/domain/tts/tts_language_change.dart test/features/lecture_session/tts_language_change_test.dart
git commit -m "feat(viewer): add TTS preserve-intent helper for language change"
```

---

### Task 3: Engine `clearBuffer` with optional preserve

**Files:**
- Modify: `lib/features/lecture_session/domain/tts/tts_soloud_pane_engine.dart`
- Modify: `lib/features/lecture_session/domain/tts/lecture_tts_controller.dart`

- [ ] **Step 1: Refactor `TtsSoloudPaneEngine`** — replace `clear()` body with delegation:

```dart
  Future<void> clear() => clearBuffer(preserveUserPlaybackIntent: false);

  Future<void> clearBuffer({bool preserveUserPlaybackIntent = false}) async {
    _clearEpoch++;
    if (!preserveUserPlaybackIntent) {
      _userWantsPlayback = false;
    }
    _queue.clear();
    await _stopVoiceAndSource();
    _bufferedDurationSec = 0;
    _playbackPositionSec = 0;
    _bufferGeneration = 0;
    await deactivateLectureTtsAudioSession();
    _emit();
  }
```

Remove the duplicate logic from the old `clear()` implementation (do not leave two methods with divergent bodies).

- [ ] **Step 2: Extend `LectureTtsController`**

```dart
  bool get userWantsPlayback => _engine.userWantsPlayback;

  Future<void> clearForLanguageChange({
    required bool preserveUserPlaybackIntent,
  }) =>
      _engine.clearBuffer(
        preserveUserPlaybackIntent: preserveUserPlaybackIntent,
      );

  Future<void> reset() => _engine.clear();
```

Add on `TtsSoloudPaneEngine`:

```dart
  bool get userWantsPlayback => _userWantsPlayback;
```

- [ ] **Step 3: Analyze**

```bash
cd /Users/macbook/Works/Lecture_Translation_Alex/lecture_viewer_v3 && dart analyze lib/features/lecture_session/domain/tts/
```

Expected: no errors.

- [ ] **Step 4: Commit**

```bash
cd /Users/macbook/Works/Lecture_Translation_Alex/lecture_viewer_v3
git add lib/features/lecture_session/domain/tts/tts_soloud_pane_engine.dart lib/features/lecture_session/domain/tts/lecture_tts_controller.dart
git commit -m "feat(viewer): clear TTS buffer with optional playback intent preserve"
```

---

### Task 4: Notifier — preserve TTS on `setLanguage`

**Files:**
- Modify: `lib/features/lecture_session/presentation/providers/lecture_session_notifier.dart`

- [ ] **Step 1: Add imports**

```dart
import 'package:lecture_viewer_v3/features/lecture_session/domain/tts/lecture_tts_language.dart';
import 'package:lecture_viewer_v3/features/lecture_session/domain/tts/tts_language_change.dart';
```

(`lecture_tts_language.dart` may already be imported — skip duplicate.)

- [ ] **Step 2: Replace `_resetTtsForLanguageChange`**

Rename to `_clearTtsForLanguageChange` and pass target language:

```dart
  Future<void> _clearTtsForLanguageChange(String newLanguage) async {
    final controller = _tts;
    if (controller == null) {
      await lectureTtsAudioHandler?.clearMediaSession();
      return;
    }

    final preserve = preserveTtsPlaybackOnLanguageChange(
      userWantsPlayback: controller.userWantsPlayback,
      newLanguageSupportsTts: isTtsSupportedForLanguage(
        newLanguage,
        state.computedSenders,
      ),
    );

    await controller.clearForLanguageChange(
      preserveUserPlaybackIntent: preserve,
    );
    await lectureTtsAudioHandler?.clearMediaSession();
  }
```

- [ ] **Step 3: Update `_applyLanguageChange`**

Change the first line from:

```dart
    await _resetTtsForLanguageChange();
```

to:

```dart
    await _clearTtsForLanguageChange(language);
```

(`language` is the **new** selection parameter.)

- [ ] **Step 4: Confirm `setModule` does not call TTS clear** — no change; grep should show only `_applyLanguageChange` uses `_clearTtsForLanguageChange`.

- [ ] **Step 5: Run full test suite**

```bash
cd /Users/macbook/Works/Lecture_Translation_Alex/lecture_viewer_v3 && flutter test
flutter analyze
```

Expected: all tests pass.

- [ ] **Step 6: Commit**

```bash
cd /Users/macbook/Works/Lecture_Translation_Alex/lecture_viewer_v3
git add lib/features/lecture_session/presentation/providers/lecture_session_notifier.dart
git commit -m "fix(viewer): keep TTS playing intent when changing language"
```

---

### Task 5: Manual verification + docs touch-up

**Files:**
- Modify (optional): `README.md` — remove completed backlog bullets if still present

- [ ] **Step 1: Manual — share**

1. Live session → Share → confirm no “Include transcript” row.
2. Select language + Share → OS sheet with `.txt` file(s).
3. Snapshot screen → Share → same UI.

- [ ] **Step 2: Manual — TTS (device with live session + TTS routes for 2+ languages)**

1. English: start TTS playing → switch to German → TTS should resume when German PCM arrives (brief silence OK).
2. Pause TTS → switch language → must stay paused.
3. Playing TTS → switch to language without `tts:*` → playback stops; unavailable message.
4. Change module only (same language) → TTS continues without full reset.

- [ ] **Step 3: Optional README cleanup** — remove lines:

```markdown
- disable include transcript ở màn hình share
- nếu tts đang bật mà ng dùng đổi ngôn ngữ thì tts vẫn giữ nguyên không được tắt
```

only if those bullets still exist in `README.md`.

- [ ] **Step 4: Commit (if README changed)**

```bash
cd /Users/macbook/Works/Lecture_Translation_Alex/lecture_viewer_v3
git add README.md
git commit -m "docs: remove completed viewer share/TTS backlog items"
```

---

## Spec coverage checklist

| Spec requirement | Task |
|------------------|------|
| Remove include-transcript toggle | Task 1 |
| Share always exports transcript | Task 1 (guard removed) |
| Playing + language change → preserve intent, auto-play new PCM | Tasks 3–4 + manual |
| Paused + language change → no auto-play | Tasks 2–4 + manual |
| New language without TTS → full clear | Task 2 helper + Task 4 |
| `setModule` unchanged | Task 4 step 4 |
| Unit tests for preserve logic | Task 2 |
| Widget test share UI | Task 1 |

## Post-coding review (agent)

After all tasks: re-read diff for unnecessary rebuilds, confirm `clearMediaSession` still runs on language change, confirm no duplicate imports, run `flutter test` once more.
