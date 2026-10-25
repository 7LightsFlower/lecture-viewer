# TTS Collapsed Slider Gate Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show the collapsed seek slider only after the user taps AppBar Play while a TTS-supported language is selected; hide it on pause and when switching to Transcript or an unsupported language.

**Architecture:** Add `ttsCollapsedSliderVisible` to `LectureSessionState`. Notifier sets/clears the flag on AppBar play engage, pause, and language change. A small pure helper decides when language change clears the gate. UI reads the flag in `LectureSessionControls`; AppBar calls `engageTtsCollapsedSlider()` before existing play logic. No engine or `lecture_common` changes.

**Tech stack:** Flutter 3.10+, Riverpod (`NotifierProvider.autoDispose.family`), `lecture_common` (`TtsPaneSnapshot`, `TranslationTtsTransport`, `TtsVoiceAvailability`).

**Spec reference:** `docs/superpowers/specs/2026-06-05-lecture-viewer-tts-collapsed-slider-gate-design.md`

---

## File map

| Path | Action | Responsibility |
|------|--------|----------------|
| `lib/features/lecture_session/presentation/lecture_session_state.dart` | Modify | `ttsCollapsedSliderVisible` field + `copyWith` |
| `lib/features/lecture_session/domain/tts/tts_collapsed_slider_gate.dart` | Create | Pure helper: clear gate on language change? |
| `lib/features/lecture_session/presentation/providers/lecture_session_notifier.dart` | Modify | `engageTtsCollapsedSlider`, pause/language gate hooks |
| `lib/features/lecture_session/presentation/lecture_tts_app_bar_button.dart` | Modify | Call engage before play |
| `lib/features/lecture_session/presentation/lecture_session_controls.dart` | Modify | Gate condition on collapsed seek row |
| `test/features/lecture_session/tts_collapsed_slider_gate_test.dart` | Create | Pure helper tests |
| `test/features/lecture_session/lecture_session_notifier_tts_gate_test.dart` | Create | Notifier engage/pause tests via `ProviderContainer` |
| `test/features/lecture_session/lecture_session_controls_tts_gate_test.dart` | Create | Widget test: slider hidden until engaged |

---

### Task 1: State field `ttsCollapsedSliderVisible`

**Files:**
- Modify: `lib/features/lecture_session/presentation/lecture_session_state.dart`
- Test: `test/features/lecture_session/lecture_session_notifier_tts_gate_test.dart` (scaffold only)

- [ ] **Step 1: Write failing notifier test for engage**

Create `test/features/lecture_session/lecture_session_notifier_tts_gate_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lecture_common/lecture_common.dart';
import 'package:lecture_viewer_v3/features/lecture_session/presentation/lecture_session_scope.dart';
import 'package:lecture_viewer_v3/features/lecture_session/presentation/lecture_session_state.dart';
import 'package:lecture_viewer_v3/features/lecture_session/presentation/providers/lecture_session_notifier.dart';

const _scope = (
  sessionId: 'gate-test',
  linkRecord: 'example.edu/mobile/session/gate-test',
);

const _ttsSenders = {
  'tts:1_de': ComputedSenderInfo(
    language: 'German',
    type: 'tts',
    percent: 0,
  ),
};

class _GateTestNotifier extends LectureSessionNotifier {
  @override
  LectureSessionState build(LectureSessionScope scope) {
    return LectureSessionState(
      sessionId: scope.sessionId,
      hasReceivedInfo: true,
      activeLanguages: const ['German', 'Transcript'],
      computedSenders: _ttsSenders,
      selectedLanguage: 'German',
      selectedRawSender: 'tts:1_de',
    );
  }

  void seedPlayingWithSliderVisible() {
    state = state.copyWith(
      ttsCollapsedSliderVisible: true,
      tts: const TtsPaneSnapshot(
        isPlaying: true,
        bufferedDurationSec: 12,
        playbackPositionSec: 3,
      ),
    );
  }
}

void main() {
  group('LectureSessionNotifier TTS collapsed slider gate', () {
    late ProviderContainer container;
    late LectureSessionNotifier notifier;

    setUp(() {
      container = ProviderContainer(
        overrides: [
          lectureSessionProvider.overrideWith(_GateTestNotifier.new),
        ],
      );
      notifier = container.read(lectureSessionProvider(_scope).notifier);
    });

    tearDown(() => container.dispose());

    test('engageTtsCollapsedSlider sets visible', () {
      expect(
        container.read(lectureSessionProvider(_scope)).ttsCollapsedSliderVisible,
        isFalse,
      );

      notifier.engageTtsCollapsedSlider();

      expect(
        container.read(lectureSessionProvider(_scope)).ttsCollapsedSliderVisible,
        isTrue,
      );
    });

    test('ttsPlayPause clears visible when pausing', () {
      (notifier as _GateTestNotifier).seedPlayingWithSliderVisible();

      notifier.ttsPlayPause();

      expect(
        container.read(lectureSessionProvider(_scope)).ttsCollapsedSliderVisible,
        isFalse,
      );
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run from `lecture_viewer_v3/`:

```bash
flutter test test/features/lecture_session/lecture_session_notifier_tts_gate_test.dart
```

Expected: FAIL — `ttsCollapsedSliderVisible` getter / `engageTtsCollapsedSlider` not defined.

- [ ] **Step 3: Add field to `LectureSessionState`**

In `lib/features/lecture_session/presentation/lecture_session_state.dart`:

```dart
class LectureSessionState {
  const LectureSessionState({
    required this.sessionId,
    // ... existing params ...
    this.ttsCollapsedSliderVisible = false,
  });

  // ... existing fields ...
  final bool ttsCollapsedSliderVisible;

  LectureSessionState copyWith({
    // ... existing params ...
    bool? ttsCollapsedSliderVisible,
    bool clearError = false,
  }) {
    return LectureSessionState(
      sessionId: sessionId,
      // ... existing fields ...
      ttsCollapsedSliderVisible:
          ttsCollapsedSliderVisible ?? this.ttsCollapsedSliderVisible,
    );
  }
}
```

- [ ] **Step 4: Add `engageTtsCollapsedSlider` and pause clear stub in notifier**

In `lib/features/lecture_session/presentation/providers/lecture_session_notifier.dart`:

```dart
  void engageTtsCollapsedSlider() {
    if (state.ttsCollapsedSliderVisible) return;
    state = state.copyWith(ttsCollapsedSliderVisible: true);
  }

  void ttsPlayPause() {
    final wasPlaying = state.tts.isPlaying;
    if (wasPlaying) {
      state = state.copyWith(ttsCollapsedSliderVisible: false);
    }
    unawaited(
      _ensureTts().playPauseFromUser(isPlaying: wasPlaying),
    );
  }
```

- [ ] **Step 5: Run tests to verify they pass**

```bash
flutter test test/features/lecture_session/lecture_session_notifier_tts_gate_test.dart
```

Expected: PASS (2 tests).

- [ ] **Step 6: Commit**

```bash
git add \
  lib/features/lecture_session/presentation/lecture_session_state.dart \
  lib/features/lecture_session/presentation/providers/lecture_session_notifier.dart \
  test/features/lecture_session/lecture_session_notifier_tts_gate_test.dart
git commit -m "feat(viewer): add TTS collapsed slider visibility state and engage hook"
```

---

### Task 2: Language-change gate helper + notifier hook

**Files:**
- Create: `lib/features/lecture_session/domain/tts/tts_collapsed_slider_gate.dart`
- Modify: `lib/features/lecture_session/presentation/providers/lecture_session_notifier.dart`
- Test: `test/features/lecture_session/tts_collapsed_slider_gate_test.dart`
- Test: `test/features/lecture_session/lecture_session_notifier_tts_gate_test.dart`

- [ ] **Step 1: Write failing pure helper tests**

Create `test/features/lecture_session/tts_collapsed_slider_gate_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lecture_viewer_v3/features/lecture_session/domain/tts/lecture_tts_language.dart';
import 'package:lecture_viewer_v3/features/lecture_session/domain/tts/tts_collapsed_slider_gate.dart';

void main() {
  group('shouldClearTtsCollapsedSliderOnLanguageChange', () {
    test('clears for Transcript', () {
      expect(
        shouldClearTtsCollapsedSliderOnLanguageChange(
          TtsVoiceAvailability.transcriptMode,
        ),
        isTrue,
      );
    });

    test('clears for unsupported language', () {
      expect(
        shouldClearTtsCollapsedSliderOnLanguageChange(
          TtsVoiceAvailability.languageUnsupported,
        ),
        isTrue,
      );
    });

    test('preserves for available TTS language', () {
      expect(
        shouldClearTtsCollapsedSliderOnLanguageChange(
          TtsVoiceAvailability.available,
        ),
        isFalse,
      );
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
flutter test test/features/lecture_session/tts_collapsed_slider_gate_test.dart
```

Expected: FAIL — `shouldClearTtsCollapsedSliderOnLanguageChange` not defined.

- [ ] **Step 3: Implement pure helper**

Create `lib/features/lecture_session/domain/tts/tts_collapsed_slider_gate.dart`:

```dart
import 'package:lecture_viewer_v3/features/lecture_session/domain/tts/lecture_tts_language.dart';

bool shouldClearTtsCollapsedSliderOnLanguageChange(
  TtsVoiceAvailability availability,
) {
  return availability == TtsVoiceAvailability.transcriptMode ||
      availability == TtsVoiceAvailability.languageUnsupported;
}
```

- [ ] **Step 4: Wire language change in notifier**

Import the helper in `lecture_session_notifier.dart`. Update `_applyLanguageChange`:

```dart
  Future<void> _applyLanguageChange(String language) async {
    await _clearTtsForLanguageChange(language);
    final rawSender = defaultRawSenderForLanguage(
      selectedLanguage: language,
      computedSenders: state.computedSenders,
    );
    final availability = ttsVoiceAvailability(
      selectedLanguage: language,
      computedSenders: state.computedSenders,
    );
    final clearSlider = shouldClearTtsCollapsedSliderOnLanguageChange(
      availability,
    );
    state = state.copyWith(
      selectedLanguage: language,
      selectedRawSender: rawSender ?? '',
      ttsCollapsedSliderVisible:
          clearSlider ? false : state.ttsCollapsedSliderVisible,
    );
    // ... existing debug + persist ...
  }
```

- [ ] **Step 5: Add notifier integration test for language change**

Append to `lecture_session_notifier_tts_gate_test.dart`:

```dart
    test('setLanguage to Transcript clears visible', () async {
      notifier.engageTtsCollapsedSlider();
      expect(
        container.read(lectureSessionProvider(_scope)).ttsCollapsedSliderVisible,
        isTrue,
      );

      notifier.setLanguage('Transcript');
      await Future<void>.delayed(Duration.zero);

      expect(
        container.read(lectureSessionProvider(_scope)).ttsCollapsedSliderVisible,
        isFalse,
      );
      expect(
        container.read(lectureSessionProvider(_scope)).selectedLanguage,
        'Transcript',
      );
    });

    test('setLanguage between TTS languages preserves visible', () async {
      notifier.engageTtsCollapsedSlider();
      (notifier as _GateTestNotifier).state = (notifier as _GateTestNotifier)
          .state
          .copyWith(
            computedSenders: {
              ..._ttsSenders,
              'tts:1_en': const ComputedSenderInfo(
                language: 'English',
                type: 'tts',
                percent: 0,
              ),
            },
            activeLanguages: const ['German', 'English'],
          );

      notifier.setLanguage('English');
      await Future<void>.delayed(Duration.zero);

      expect(
        container.read(lectureSessionProvider(_scope)).ttsCollapsedSliderVisible,
        isTrue,
      );
    });
```

Note: `_GateTestNotifier` needs a public `state` setter for the second test, or add a `seedTtsLanguages()` helper method on the test class instead of casting.

Preferred test-class helper:

```dart
  void seedEnglishTts() {
    state = state.copyWith(
      activeLanguages: const ['German', 'English'],
      computedSenders: {
        ..._ttsSenders,
        'tts:1_en': const ComputedSenderInfo(
          language: 'English',
          type: 'tts',
          percent: 0,
        ),
      },
    );
  }
```

Use `notifier.seedEnglishTts()` in the test (cast to `_GateTestNotifier` once in setUp or store typed reference).

- [ ] **Step 6: Run all gate tests**

```bash
flutter test test/features/lecture_session/tts_collapsed_slider_gate_test.dart test/features/lecture_session/lecture_session_notifier_tts_gate_test.dart
```

Expected: PASS (all tests).

- [ ] **Step 7: Commit**

```bash
git add \
  lib/features/lecture_session/domain/tts/tts_collapsed_slider_gate.dart \
  lib/features/lecture_session/presentation/providers/lecture_session_notifier.dart \
  test/features/lecture_session/tts_collapsed_slider_gate_test.dart \
  test/features/lecture_session/lecture_session_notifier_tts_gate_test.dart
git commit -m "feat(viewer): clear TTS collapsed slider on transcript or unsupported language"
```

---

### Task 3: AppBar engage on play tap

**Files:**
- Modify: `lib/features/lecture_session/presentation/lecture_tts_app_bar_button.dart`

- [ ] **Step 1: Call engage before existing play logic**

In `lecture_tts_app_bar_button.dart`, update the available-voice `IconButton`:

```dart
    return IconButton(
      tooltip: snapshot.isPlaying ? 'Pause TTS' : 'Play TTS',
      iconSize: 32,
      onPressed: () {
        if (!snapshot.isPlaying) {
          notifier.engageTtsCollapsedSlider();
        }
        onLectureTtsPlayPressed(
          context,
          canPlayTts: canPlayTts,
          onPlayPause: notifier.ttsPlayPause,
          blockedMessage: blockedMessage,
        );
      },
      icon: Icon(
        snapshot.isPlaying ? Icons.volume_up_rounded : Icons.volume_off_rounded,
      ),
    );
```

Only engage on Play tap (not Pause), matching spec: pause clears gate via `ttsPlayPause`; next Play re-engages.

- [ ] **Step 2: Run analyzer**

```bash
flutter analyze lib/features/lecture_session/presentation/lecture_tts_app_bar_button.dart
```

Expected: No issues.

- [ ] **Step 3: Commit**

```bash
git add lib/features/lecture_session/presentation/lecture_tts_app_bar_button.dart
git commit -m "feat(viewer): engage collapsed TTS slider on AppBar play tap"
```

---

### Task 4: Controls gate condition + widget test

**Files:**
- Modify: `lib/features/lecture_session/presentation/lecture_session_controls.dart`
- Test: `test/features/lecture_session/lecture_session_controls_tts_gate_test.dart`

- [ ] **Step 1: Write failing widget test**

Create `test/features/lecture_session/lecture_session_controls_tts_gate_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lecture_common/lecture_common.dart';
import 'package:lecture_viewer_v3/features/lecture_session/presentation/lecture_session_controls.dart';
import 'package:lecture_viewer_v3/features/lecture_session/presentation/lecture_session_scope.dart';
import 'package:lecture_viewer_v3/features/lecture_session/presentation/lecture_session_state.dart';
import 'package:lecture_viewer_v3/features/lecture_session/presentation/providers/lecture_session_notifier.dart';

const _scope = (
  sessionId: 'controls-gate',
  linkRecord: 'example.edu/mobile/session/controls-gate',
);

class _ControlsGateTestNotifier extends LectureSessionNotifier {
  _ControlsGateTestNotifier(this.initial);

  final LectureSessionState initial;

  @override
  LectureSessionState build(LectureSessionScope scope) => initial;
}

void main() {
  testWidgets('collapsed controls hide slider until gate visible', (
    WidgetTester tester,
  ) async {
    const base = LectureSessionState(
      sessionId: _scope.sessionId,
      hasReceivedInfo: true,
      activeLanguages: ['German'],
      computedSenders: {
        'tts:1_de': ComputedSenderInfo(
          language: 'German',
          type: 'tts',
          percent: 0,
        ),
      },
      selectedLanguage: 'German',
      selectedRawSender: 'tts:1_de',
      tts: TtsPaneSnapshot(bufferedDurationSec: 8),
      ttsCollapsedSliderVisible: false,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          lectureSessionProvider.overrideWith(
            () => _ControlsGateTestNotifier(base),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: LectureSessionControls(
              scope: _scope,
              expanded: false,
            ),
          ),
        ),
      ),
    );

    expect(find.byType(Slider), findsNothing);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          lectureSessionProvider.overrideWith(
            () => _ControlsGateTestNotifier(
              base.copyWith(ttsCollapsedSliderVisible: true),
            ),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: LectureSessionControls(
              scope: _scope,
              expanded: false,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(Slider), findsOneWidget);
    expect(find.text('00:08'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
flutter test test/features/lecture_session/lecture_session_controls_tts_gate_test.dart
```

Expected: FAIL — slider found when gate is false (current code shows slider whenever voice available).

- [ ] **Step 3: Update controls gate condition**

In `lecture_session_controls.dart`, watch the flag and gate the row:

```dart
    final ttsCollapsedSliderVisible = ref.watch(
      lectureSessionProvider(scope).select(
        (s) => s.ttsCollapsedSliderVisible,
      ),
    );

    final collapsedSeekRow = !expanded &&
        voiceAvailability == TtsVoiceAvailability.available &&
        ttsCollapsedSliderVisible;
```

- [ ] **Step 4: Run widget test**

```bash
flutter test test/features/lecture_session/lecture_session_controls_tts_gate_test.dart
```

Expected: PASS.

- [ ] **Step 5: Run full lecture_session test suite**

```bash
flutter test test/features/lecture_session/
```

Expected: All PASS.

- [ ] **Step 6: Commit**

```bash
git add \
  lib/features/lecture_session/presentation/lecture_session_controls.dart \
  test/features/lecture_session/lecture_session_controls_tts_gate_test.dart
git commit -m "feat(viewer): gate collapsed TTS seek row behind AppBar play engagement"
```

---

## Manual verification

- [ ] Open session, select TTS language, collapse controls → no slider row
- [ ] Tap AppBar Play (buffer may be empty) → slider row appears at 0:00
- [ ] Tap AppBar Pause → slider row disappears
- [ ] Tap AppBar Play again → slider row reappears
- [ ] Expand controls while playing → no slider; collapse → slider returns if gate still true
- [ ] Change language to Transcript → slider hidden; AppBar shows unavailable icon
- [ ] Switch German → English (both TTS) while gate true → slider stays without re-tapping Play

---

## Spec coverage checklist

| Spec requirement | Task |
|------------------|------|
| `ttsCollapsedSliderVisible` in state | Task 1 |
| `engageTtsCollapsedSlider()` on AppBar Play | Task 1 + Task 3 |
| Pause clears gate | Task 1 |
| Transcript/unsupported language clears gate | Task 2 |
| TTS→TTS preserves gate | Task 2 test |
| Controls `collapsedSeekRow` uses flag | Task 4 |
| Empty-buffer play still engages gate | Task 3 (engage before `canPlayTts` check) |
| Remote play/pause unchanged | No task (out of scope) |
| No `lecture_common` changes | No task |
