# Lecture Viewer TTS Unavailable UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Grey speaker icon (no slider) when TTS voice is unavailable; SnackBar with context-specific messages; keep full transport when TTS is supported — per `docs/superpowers/specs/2026-05-30-lecture-viewer-tts-unavailable-ui-design.md`.

**Architecture:** Add `TtsVoiceAvailability` enum and helpers in `lecture_tts_language.dart`. Replace duplicated transport wiring in `lecture_session_controls.dart` with `_LectureTtsControls` that branches unavailable → grey `Icons.volume_up`, available → existing `TranslationTtsTransport`.

**Tech stack:** Flutter 3.10+, Riverpod, `lecture_common` (`TranslationTtsTransport`, `TtsPaneSnapshot`).

**Spec reference:** `docs/superpowers/specs/2026-05-30-lecture-viewer-tts-unavailable-ui-design.md`

---

## File map

| Path | Action | Responsibility |
|------|--------|----------------|
| `lib/features/lecture_session/domain/tts/lecture_tts_language.dart` | Modify | `TtsVoiceAvailability`, `ttsVoiceAvailability()`, `ttsVoiceUnavailableMessage()` |
| `test/features/lecture_session/lecture_tts_language_test.dart` | Modify | Unit tests for availability + messages |
| `lib/features/lecture_session/presentation/lecture_session_controls.dart` | Modify | `_LectureTtsControls`; remove static hints; wire collapsed + expanded |

---

### Task 1: Domain — voice availability helpers (TDD)

**Files:**
- Modify: `lib/features/lecture_session/domain/tts/lecture_tts_language.dart`
- Test: `test/features/lecture_session/lecture_tts_language_test.dart`

- [ ] **Step 1: Write failing tests**

Append to `test/features/lecture_session/lecture_tts_language_test.dart`:

```dart
  group('ttsVoiceAvailability', () {
    test('Transcript language is transcriptMode', () {
      expect(
        ttsVoiceAvailability(
          selectedLanguage: 'Transcript',
          computedSenders: senders,
        ),
        TtsVoiceAvailability.transcriptMode,
      );
    });

    test('language with tts route is available', () {
      expect(
        ttsVoiceAvailability(
          selectedLanguage: 'German',
          computedSenders: senders,
        ),
        TtsVoiceAvailability.available,
      );
    });

    test('language without tts route is languageUnsupported', () {
      expect(
        ttsVoiceAvailability(
          selectedLanguage: 'Japanese',
          computedSenders: senders,
        ),
        TtsVoiceAvailability.languageUnsupported,
      );
    });

    test('empty language is languageUnsupported', () {
      expect(
        ttsVoiceAvailability(
          selectedLanguage: '',
          computedSenders: senders,
        ),
        TtsVoiceAvailability.languageUnsupported,
      );
    });
  });

  group('ttsVoiceUnavailableMessage', () {
    test('transcriptMode message', () {
      expect(
        ttsVoiceUnavailableMessage(TtsVoiceAvailability.transcriptMode),
        'For Voice output, please select a language',
      );
    });

    test('languageUnsupported message', () {
      expect(
        ttsVoiceUnavailableMessage(TtsVoiceAvailability.languageUnsupported),
        'Voice output not available for this language',
      );
    });
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /Users/macbook/Works/Lecture_Translation_Alex/lecture_viewer_v3 && flutter test test/features/lecture_session/lecture_tts_language_test.dart`

Expected: FAIL — `ttsVoiceAvailability` / `TtsVoiceAvailability` not defined.

- [ ] **Step 3: Implement domain helpers**

Replace full content of `lib/features/lecture_session/domain/tts/lecture_tts_language.dart` with:

```dart
import 'package:lecture_common/lecture_common.dart';

enum TtsVoiceAvailability {
  available,
  transcriptMode,
  languageUnsupported,
}

const kTtsTranscriptModeMessage =
    'For Voice output, please select a language';
const kTtsLanguageUnsupportedMessage =
    'Voice output not available for this language';

String? resolveLectureTtsLanguage(
  TtsPcmEvent event,
  Map<String, ComputedSenderInfo> computedSenders,
) {
  final hint = event.languageFromPayload;
  if (hint != null && hint.isNotEmpty) return hint;
  return computedSenders[event.rawSender]?.language;
}

/// Whether the session exposes a `tts:*` route for [language].
bool isTtsSupportedForLanguage(
  String language,
  Map<String, ComputedSenderInfo> computedSenders,
) {
  if (language.isEmpty) return false;
  return computedSenders.values.any(
    (info) => info.type == 'tts' && info.language == language,
  );
}

TtsVoiceAvailability ttsVoiceAvailability({
  required String selectedLanguage,
  required Map<String, ComputedSenderInfo> computedSenders,
}) {
  if (selectedLanguage == 'Transcript') {
    return TtsVoiceAvailability.transcriptMode;
  }
  if (isTtsSupportedForLanguage(selectedLanguage, computedSenders)) {
    return TtsVoiceAvailability.available;
  }
  return TtsVoiceAvailability.languageUnsupported;
}

String ttsVoiceUnavailableMessage(TtsVoiceAvailability availability) {
  return switch (availability) {
    TtsVoiceAvailability.transcriptMode => kTtsTranscriptModeMessage,
    TtsVoiceAvailability.languageUnsupported => kTtsLanguageUnsupportedMessage,
    TtsVoiceAvailability.available => throw ArgumentError(
        'ttsVoiceUnavailableMessage called for available state',
      ),
  };
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd /Users/macbook/Works/Lecture_Translation_Alex/lecture_viewer_v3 && flutter test test/features/lecture_session/lecture_tts_language_test.dart`

Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
cd /Users/macbook/Works/Lecture_Translation_Alex/lecture_viewer_v3
git add lib/features/lecture_session/domain/tts/lecture_tts_language.dart \
  test/features/lecture_session/lecture_tts_language_test.dart
git commit -m "$(cat <<'EOF'
feat: add TTS voice availability domain helpers

Expose transcript vs unsupported language states and SnackBar messages
for lecture viewer TTS controls.
EOF
)"
```

---

### Task 2: Presentation — `_LectureTtsControls` widget

**Files:**
- Modify: `lib/features/lecture_session/presentation/lecture_session_controls.dart`

- [ ] **Step 1: Refactor controls to use availability + wrapper widget**

Key changes in `lecture_session_controls.dart`:

1. Replace `ttsSupported` / `ttsPlayHint` locals with:

```dart
    final voiceAvailability = ttsVoiceAvailability(
      selectedLanguage: controls.selectedLanguage,
      computedSenders: controls.computedSenders,
    );
    final canPlayTts =
        voiceAvailability == TtsVoiceAvailability.available &&
        tts.bufferedDurationSec > 0;
    final ttsPlayBlockedMessage = _ttsPlayBlockedMessage(
      voiceAvailability: voiceAvailability,
      tts: tts,
    );
```

2. Remove blocks at lines 224–243 (`if (!ttsSupported) Padding...` and `if (ttsPlayHint != null) Padding...`).

3. Replace both `TranslationTtsTransport(...)` usages (collapsed ~line 82 and expanded ~line 244) with:

```dart
                      _LectureTtsControls(
                        voiceAvailability: voiceAvailability,
                        snapshot: tts,
                        onPlayPause: notifier.ttsPlayPause,
                        onSeekEnd: notifier.ttsSeekEnd,
                        onNoBufferPlayTap: canPlayTts
                            ? null
                            : () => _onTtsPlayPressed(
                                  context,
                                  voiceAvailability: voiceAvailability,
                                  canPlayTts: false,
                                  onPlayPause: notifier.ttsPlayPause,
                                  blockedMessage: ttsPlayBlockedMessage,
                                ),
                      )
```

4. Update `_onTtsPlayPressed` signature — replace `ttsSupported` with `voiceAvailability`:

```dart
  void _onTtsPlayPressed(
    BuildContext context, {
    required TtsVoiceAvailability voiceAvailability,
    required bool canPlayTts,
    required VoidCallback onPlayPause,
    required String blockedMessage,
  }) {
    if (canPlayTts) {
      onPlayPause();
      return;
    }
    if (voiceAvailability == TtsVoiceAvailability.available) {
      onPlayPause();
      return;
    }
    _showTtsPlayBlockedSnack(context, blockedMessage);
  }
```

5. Update `_ttsPlayBlockedMessage` — remove old `_ttsUnavailableMessage`; use domain messages for unavailable:

```dart
  String _ttsPlayBlockedMessage({
    required TtsVoiceAvailability voiceAvailability,
    required TtsPaneSnapshot tts,
  }) {
    if (voiceAvailability != TtsVoiceAvailability.available) {
      return ttsVoiceUnavailableMessage(voiceAvailability);
    }
    if (tts.pendingDownloadCount > 0) return _ttsDownloadingAudioMessage;
    return _ttsWaitingForAudioMessage;
  }
```

6. Delete: `_ttsUnavailableMessage` constant, `_ttsPlayHint` method, and `ttsPlayHint` local variable.

7. Append `_LectureTtsControls` at end of file (before closing brace of file):

```dart
class _LectureTtsControls extends StatelessWidget {
  const _LectureTtsControls({
    required this.voiceAvailability,
    required this.snapshot,
    required this.onPlayPause,
    required this.onSeekEnd,
    this.onNoBufferPlayTap,
  });

  final TtsVoiceAvailability voiceAvailability;
  final TtsPaneSnapshot snapshot;
  final VoidCallback onPlayPause;
  final void Function(double normalizedPosition) onSeekEnd;
  final VoidCallback? onNoBufferPlayTap;

  @override
  Widget build(BuildContext context) {
    if (voiceAvailability != TtsVoiceAvailability.available) {
      final scheme = Theme.of(context).colorScheme;
      final message = ttsVoiceUnavailableMessage(voiceAvailability);
      return Align(
        alignment: Alignment.centerLeft,
        child: IconButton(
          tooltip: 'Voice output unavailable',
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(message)),
            );
          },
          style: IconButton.styleFrom(
            visualDensity: VisualDensity.compact,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          icon: Icon(
            Icons.volume_up,
            color: scheme.onSurface.withValues(alpha: 0.38),
          ),
        ),
      );
    }

    return TranslationTtsTransport(
      snapshot: snapshot,
      onPlayPause: onPlayPause,
      onSeekEnd: onSeekEnd,
      onNoBufferPlayTap: onNoBufferPlayTap,
    );
  }
}
```

- [ ] **Step 2: Analyze for errors**

Run: `cd /Users/macbook/Works/Lecture_Translation_Alex/lecture_viewer_v3 && dart analyze lib/features/lecture_session/presentation/lecture_session_controls.dart lib/features/lecture_session/domain/tts/lecture_tts_language.dart`

Expected: No issues.

- [ ] **Step 3: Run full lecture_session tests**

Run: `cd /Users/macbook/Works/Lecture_Translation_Alex/lecture_viewer_v3 && flutter test test/features/lecture_session/`

Expected: All tests PASS.

- [ ] **Step 4: Commit**

```bash
cd /Users/macbook/Works/Lecture_Translation_Alex/lecture_viewer_v3
git add lib/features/lecture_session/presentation/lecture_session_controls.dart
git commit -m "$(cat <<'EOF'
feat: grey speaker icon when TTS voice unavailable

Hide slider for Transcript and unsupported languages; show SnackBar on
tap. Remove static hint text from expanded controls.
EOF
)"
```

---

### Task 3: Manual verification

**Files:** None (device/simulator)

- [ ] **Step 1:** Join live session with Transcript as default language.

Expected: Collapsed row shows grey `volume_up` only (no slider). Tap → SnackBar *For Voice output, please select a language*.

- [ ] **Step 2:** Select a translated language that has TTS (e.g. German/English per session).

Expected: Play + slider appear. Before buffer, tap play → waiting/download SnackBar. After buffer → play/pause/seek work.

- [ ] **Step 3:** If session includes a language without `tts:*`, select it.

Expected: Grey speaker, no slider. Tap → *Voice output not available for this language*.

- [ ] **Step 4:** Expand Controls.

Expected: No static hint lines above transport; transport matches collapsed behavior.

---

## Spec coverage checklist

| Spec requirement | Task |
|------------------|------|
| `transcriptMode` when `selectedLanguage == "Transcript"` | Task 1 |
| `languageUnsupported` when no `tts:*` | Task 1 |
| SnackBar messages (transcript / unsupported) | Task 1, Task 2 |
| Grey speaker, no slider when unavailable | Task 2 |
| Keep `TranslationTtsTransport` when available | Task 2 |
| Buffer-wait SnackBars unchanged | Task 2 (`_ttsPlayBlockedMessage`) |
| Remove static hint text | Task 2 |
| Collapsed + expanded same widget | Task 2 |
| Unit tests | Task 1 |
| Manual test plan | Task 3 |
