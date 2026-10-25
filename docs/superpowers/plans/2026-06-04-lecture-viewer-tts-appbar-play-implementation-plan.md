# Lecture Viewer TTS AppBar Play Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move TTS play/pause to AppBar (left of expand toggle); keep seek slider + duration in collapsed controls row via `TranslationTtsTransport(showPlayButton: false)`.

**Architecture:** Add optional `showPlayButton` to shared `TranslationTtsTransport` in `lecture_common`. Extract play-button widget + snackbar helpers into a viewer presentation file. Wire AppBar action in `lecture_session_screen.dart`; simplify collapsed row in `lecture_session_controls.dart`. No TTS engine/state changes.

**Tech stack:** Flutter 3.10+, Riverpod, `lecture_common` (`TranslationTtsTransport`, `TtsPaneSnapshot`, `TtsVoiceAvailability`).

**Spec reference:** `docs/superpowers/specs/2026-06-04-lecture-viewer-tts-appbar-play-design.md`

---

## File map

| Path | Action | Responsibility |
|------|--------|----------------|
| `../lecture_common/lib/tts/presentation/translation_tts_transport.dart` | Modify | `showPlayButton` param (default `true`) |
| `../lecture_common/test/tts/translation_tts_transport_test.dart` | Modify | Widget test for `showPlayButton: false` |
| `lib/features/lecture_session/presentation/lecture_tts_app_bar_button.dart` | Create | AppBar play/pause + blocked-play snack helpers |
| `lib/features/lecture_session/presentation/lecture_session_screen.dart` | Modify | Insert `LectureTtsAppBarButton` before toggle |
| `lib/features/lecture_session/presentation/lecture_session_controls.dart` | Modify | Seek-only transport when collapsed; remove `_LectureTtsControls` |

---

### Task 1: `lecture_common` — `showPlayButton` on transport (TDD)

**Files:**
- Modify: `../lecture_common/lib/tts/presentation/translation_tts_transport.dart`
- Test: `../lecture_common/test/tts/translation_tts_transport_test.dart`

- [ ] **Step 1: Write failing test**

Append to `../lecture_common/test/tts/translation_tts_transport_test.dart`:

```dart
  testWidgets('showPlayButton false hides play icon but keeps slider', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 200,
              child: TranslationTtsTransport(
                showPlayButton: false,
                snapshot: const TtsPaneSnapshot(
                  bufferedDurationSec: 10,
                  pendingDownloadCount: 0,
                ),
                onPlayPause: () {},
                onSeekEnd: (_) {},
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.play_arrow), findsNothing);
    expect(find.byIcon(Icons.pause), findsNothing);
    expect(find.byType(Slider), findsOneWidget);
    expect(find.text('00:10'), findsOneWidget);
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run from `lecture_common/`:

```bash
flutter test test/tts/translation_tts_transport_test.dart --name "showPlayButton false"
```

Expected: FAIL — `showPlayButton` parameter not defined.

- [ ] **Step 3: Implement `showPlayButton`**

In `../lecture_common/lib/tts/presentation/translation_tts_transport.dart`, update constructor and row:

```dart
class TranslationTtsTransport extends StatefulWidget {
  const TranslationTtsTransport({
    super.key,
    required this.snapshot,
    required this.onPlayPause,
    required this.onSeekEnd,
    this.onNoBufferPlayTap,
    this.showPlayButton = true,
  });

  final TtsPaneSnapshot snapshot;
  final VoidCallback onPlayPause;
  final void Function(double normalizedPosition) onSeekEnd;
  final VoidCallback? onNoBufferPlayTap;
  final bool showPlayButton;
```

Wrap play `IconButton` in `if (widget.showPlayButton)` inside the `Row`:

```dart
        return Row(
          children: [
            if (widget.showPlayButton)
              IconButton(
                tooltip: snapshot.isPlaying ? 'Pause TTS' : 'Play TTS',
                onPressed: hasBuffer
                    ? widget.onPlayPause
                    : widget.onNoBufferPlayTap,
                style: IconButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: Icon(snapshot.isPlaying ? Icons.pause : Icons.play_arrow),
              ),
            if (showSlider)
              Expanded(
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd ../lecture_common && flutter test test/tts/translation_tts_transport_test.dart
```

Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
cd ../lecture_common
git add lib/tts/presentation/translation_tts_transport.dart test/tts/translation_tts_transport_test.dart
git commit -m "feat(common): add showPlayButton to TranslationTtsTransport"
```

---

### Task 2: Viewer — AppBar play button widget

**Files:**
- Create: `lib/features/lecture_session/presentation/lecture_tts_app_bar_button.dart`

- [ ] **Step 1: Create `lecture_tts_app_bar_button.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lecture_common/lecture_common.dart';

import 'package:lecture_viewer_v3/features/lecture_session/domain/tts/lecture_tts_language.dart';
import 'package:lecture_viewer_v3/features/lecture_session/presentation/lecture_session_scope.dart';
import 'package:lecture_viewer_v3/features/lecture_session/presentation/providers/lecture_session_notifier.dart';

const _ttsWaitingForAudioMessage =
    'Waiting for audio. Play will be available once translation audio is buffered.';

String lectureTtsPlayBlockedMessage({
  required TtsVoiceAvailability voiceAvailability,
}) {
  if (voiceAvailability != TtsVoiceAvailability.available) {
    return ttsVoiceUnavailableMessage(voiceAvailability);
  }
  return _ttsWaitingForAudioMessage;
}

void showLectureTtsPlayBlockedSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
}

void onLectureTtsPlayPressed(
  BuildContext context, {
  required bool canPlayTts,
  required VoidCallback onPlayPause,
  required String blockedMessage,
}) {
  if (canPlayTts) {
    onPlayPause();
    return;
  }
  showLectureTtsPlayBlockedSnack(context, blockedMessage);
}

class LectureTtsAppBarButton extends ConsumerWidget {
  const LectureTtsAppBarButton({
    required this.scope,
    super.key,
  });

  final LectureSessionScope scope;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(
      lectureSessionProvider(scope).select(
        (s) => (
          tts: s.tts,
          selectedLanguage: s.selectedLanguage,
          computedSenders: s.computedSenders,
        ),
      ),
    );
    final notifier = ref.read(lectureSessionProvider(scope).notifier);
    final voiceAvailability = ttsVoiceAvailability(
      selectedLanguage: session.selectedLanguage,
      computedSenders: session.computedSenders,
    );
    final canPlayTts =
        voiceAvailability == TtsVoiceAvailability.available &&
        session.tts.bufferedDurationSec > 0;
    final blockedMessage = lectureTtsPlayBlockedMessage(
      voiceAvailability: voiceAvailability,
    );
    final scheme = Theme.of(context).colorScheme;

    if (voiceAvailability != TtsVoiceAvailability.available) {
      return IconButton(
        tooltip: 'Voice output unavailable',
        iconSize: 36,
        onPressed: () => showLectureTtsPlayBlockedSnack(
          context,
          ttsVoiceUnavailableMessage(voiceAvailability),
        ),
        icon: Icon(
          Icons.play_arrow,
          color: scheme.onSurface.withValues(alpha: 0.38),
        ),
      );
    }

    final snapshot = session.tts;
    return IconButton(
      tooltip: snapshot.isPlaying ? 'Pause TTS' : 'Play TTS',
      iconSize: 36,
      onPressed: () => onLectureTtsPlayPressed(
        context,
        canPlayTts: canPlayTts,
        onPlayPause: notifier.ttsPlayPause,
        blockedMessage: blockedMessage,
      ),
      icon: Icon(snapshot.isPlaying ? Icons.pause : Icons.play_arrow),
    );
  }
}
```

- [ ] **Step 2: Analyze new file**

Run from `lecture_viewer_v3/`:

```bash
dart analyze lib/features/lecture_session/presentation/lecture_tts_app_bar_button.dart
```

Expected: no issues.

- [ ] **Step 3: Commit**

```bash
git add lib/features/lecture_session/presentation/lecture_tts_app_bar_button.dart
git commit -m "feat(viewer): add LectureTtsAppBarButton widget"
```

---

### Task 3: Wire AppBar action

**Files:**
- Modify: `lib/features/lecture_session/presentation/lecture_session_screen.dart`

- [ ] **Step 1: Add import and AppBar action**

Add import:

```dart
import 'package:lecture_viewer_v3/features/lecture_session/presentation/lecture_tts_app_bar_button.dart';
```

Replace AppBar `actions` (currently toggle only):

```dart
          actions: [
            LectureTtsAppBarButton(scope: scope),
            IconButton(
              tooltip: _controlsExpanded ? 'Collapse controls' : 'Expand controls',
              iconSize: 36,
              onPressed: () =>
                  setState(() => _controlsExpanded = !_controlsExpanded),
              icon: Icon(
                _controlsExpanded ? Icons.expand_less : Icons.expand_more,
              ),
            ),
          ],
```

- [ ] **Step 2: Analyze**

```bash
dart analyze lib/features/lecture_session/presentation/lecture_session_screen.dart
```

Expected: no issues.

- [ ] **Step 3: Commit**

```bash
git add lib/features/lecture_session/presentation/lecture_session_screen.dart
git commit -m "feat(viewer): wire TTS play button into session AppBar"
```

---

### Task 4: Simplify collapsed controls row (seek only)

**Files:**
- Modify: `lib/features/lecture_session/presentation/lecture_session_controls.dart`

- [ ] **Step 1: Replace collapsed `_LectureTtsControls` with seek-only transport**

Add import:

```dart
import 'package:lecture_viewer_v3/features/lecture_session/presentation/lecture_tts_app_bar_button.dart';
```

Remove unused play helpers from `LectureSessionControls` class:
- Delete `_ttsWaitingForAudioMessage` constant
- Delete `_onTtsPlayPressed`, `_showTtsPlayBlockedSnack`, `_ttsPlayBlockedMessage` instance methods
- Delete entire `_LectureTtsControls` class at bottom of file

Remove `canPlayTts` and `ttsPlayBlockedMessage` variables from `build` (no longer needed here).

Replace the `if (!expanded) _LectureTtsControls(...)` block with:

```dart
            if (!expanded &&
                voiceAvailability == TtsVoiceAvailability.available)
              TranslationTtsTransport(
                showPlayButton: false,
                snapshot: tts,
                onPlayPause: notifier.ttsPlayPause,
                onSeekEnd: notifier.ttsSeekEnd,
              ),
```

Wrap the `Material` return so empty collapsed panel is hidden when voice unavailable:

Replace the top-level `return Material(...)` with:

```dart
    final collapsedSeekRow = !expanded &&
        voiceAvailability == TtsVoiceAvailability.available;

    if (!expanded && !collapsedSeekRow) {
      return const SizedBox.shrink();
    }

    return Material(
```

This avoids an empty elevation bar when collapsed + voice unavailable (AppBar already shows grey play).

- [ ] **Step 2: Analyze**

```bash
dart analyze lib/features/lecture_session/presentation/lecture_session_controls.dart
```

Expected: no issues. If `lecture_tts_app_bar_button.dart` import is unused after removing helpers, drop that import (helpers were deleted from controls; import only needed if unused — **remove the import** since controls no longer calls those helpers).

- [ ] **Step 3: Run viewer tests**

```bash
flutter test
```

Expected: all existing tests PASS.

- [ ] **Step 4: Commit**

```bash
git add lib/features/lecture_session/presentation/lecture_session_controls.dart
git commit -m "feat(viewer): seek-only TTS row in collapsed controls"
```

---

### Task 5: Manual verification

- [ ] **Step 1: Run app and verify collapsed layout**

```bash
flutter run
```

Checklist:
- AppBar shows `[play/pause] [expand]` left-to-right; toggle is rightmost
- Collapsed controls row shows slider + duration, **no** play button in row
- Tap play on AppBar starts/pauses TTS
- Tap play with empty buffer shows "Waiting for audio…" SnackBar
- Unavailable voice: grey play in AppBar; controls row hidden (no empty bar)
- Expand panel: dropdowns visible; slider row hidden; AppBar play still works
- Collapse while playing: slider reappears; pause icon on AppBar

- [ ] **Step 2: Final analyze**

```bash
dart analyze
```

Expected: no issues.

---

## Spec coverage checklist

| Spec requirement | Task |
|------------------|------|
| Play/pause in AppBar left of toggle | Task 2, 3 |
| Slider + duration unchanged when collapsed | Task 1, 4 |
| Unavailable voice: grey play AppBar, no slider row | Task 2, 4 |
| `showPlayButton` in `lecture_common` | Task 1 |
| No TTS engine changes | — (no tasks) |
| Widget test for `showPlayButton: false` | Task 1 |

## Self-review notes

- Play blocked message logic moved from `LectureSessionControls` to `lecture_tts_app_bar_button.dart` (single source).
- `onPlayPause` still required on seek-only `TranslationTtsTransport` (API unchanged); pass `notifier.ttsPlayPause` even though play button hidden.
- Empty collapsed panel avoided via `SizedBox.shrink()` when voice unavailable.
