# Lecture Viewer — Speaker Display Formatting

**Date:** 2026-06-12  
**Project:** `lecture_viewer_v3` (viewer transcript UI)  
**Status:** Approved in brainstorming  
**Package touch:** `lecture_common` (opt-in API only; 2way defaults unchanged)

## Goal

Improve speaker blocks in the lecture viewer transcript (live session + snapshot) so that:

1. Speaker names are **bold**
2. All `#` characters are removed from speaker names
3. A **blank line** separates the previous speaker’s content from the next speaker label

Share/export text and the 2way app must keep their current behavior.

## Decisions

| Topic | Decision |
|-------|----------|
| Strip `#` | Remove every `#` in `speakerName` (`Speaker #1` → `Speaker 1`, `Speaker#1` → `Speaker1`) |
| Scope | Viewer transcript pane only (`lecture_session_screen`, `lecture_snapshot_screen`) |
| Blank line | One empty line between prior content and the next speaker label |
| First speaker in transcript | No leading blank line above the first speaker |
| Bold | Speaker label rendered with `FontWeight.bold` |
| Share / 2way | Unchanged (default options in `lecture_common`) |
| Approach | Opt-in `TranscriptSpeakerDisplayOptions` passed from viewer |

## Before / after

**Before**

```
Speaker 1
Content for speaker one.
Speaker 2
Content for speaker two.
```

**After**

```
Speaker 1
Content for speaker one.

Speaker 2
Content for speaker two.
```

(With `#` stripped and speaker lines bold in the UI.)

## Architecture

Add a small options object in `lecture_common`. Existing call sites omit it and get today’s behavior.

```dart
class TranscriptSpeakerDisplayOptions {
  const TranscriptSpeakerDisplayOptions({
    this.stripHashFromSpeakerName = false,
    this.blankLineBeforeSpeaker = false,
    this.boldSpeaker = true,
  });

  final bool stripHashFromSpeakerName;
  final bool blankLineBeforeSpeaker;
  final bool boldSpeaker;

  static const viewer = TranscriptSpeakerDisplayOptions(
    stripHashFromSpeakerName: true,
    blankLineBeforeSpeaker: true,
    boldSpeaker: true,
  );

  static const defaults = TranscriptSpeakerDisplayOptions();
}
```

Viewer wiring:

```dart
TranslationResultTranscriptFollowView(
  textScaler: textScaler,
  activeBucket: activeBucket,
  speakerDisplay: TranscriptSpeakerDisplayOptions.viewer,
  followScopeKey: followScopeKey,
)
```

Thread `speakerDisplay` through:

- `TranslationResultTranscriptFollowView`
- `TranslationResultTranscriptView`
- `TranscriptInlineFormat.paragraphInlineSpans`

## Display rules

### Name transform

When `stripHashFromSpeakerName` is true:

```dart
String displaySpeakerName(String raw) => raw.replaceAll('#', '');
```

Apply only at render time; do not mutate stored `TranscriptBucket` / snapshot JSON.

### Bold

When `boldSpeaker` is true, speaker `TextSpan` uses `fontWeight: FontWeight.bold` (same as current default).

### Blank line before speaker

When `blankLineBeforeSpeaker` is true and a speaker label is shown (`labelState.show == true`):

| Situation | Newlines before speaker name |
|-----------|------------------------------|
| Speaker after text in the **same** paragraph (`spans.isNotEmpty`) | `\n\n` (blank line after prior content) |
| Speaker at **start** of paragraph, not the first list item (`paragraphIndex > 0`, `spans.isEmpty`) | `\n` at the start of that paragraph’s rich text |
| First transcript list item (`paragraphIndex == 0`) | No extra leading newlines |

After the speaker name, keep a single `\n` before body text (unchanged).

### Example (mid-paragraph speaker change)

Rich text flow: `…content A\n\nSpeaker 2\ncontent B…`

### Example (new paragraph starts with speaker)

- Item 0: `Speaker 1\ncontent A`
- Item 1: `\nSpeaker 2\ncontent B` (leading `\n` creates the blank line above “Speaker 2”)

## Files

| File | Change |
|------|--------|
| `lecture_common/lib/transcript/domain/transcript_speaker_display_options.dart` | **New** — options + `viewer` / `defaults` presets |
| `lecture_common/lib/transcript/presentation/transcript_inline_format.dart` | Apply options; add `paragraphIndex` param |
| `lecture_common/lib/transcript/presentation/translation_result_transcript_view.dart` | Accept `speakerDisplay`; pass `paragraphIndex` |
| `lecture_common/lib/transcript/presentation/translation_result_transcript_follow_view.dart` | Forward `speakerDisplay` |
| `lecture_common/lib/lecture_common.dart` | Export new type |
| `lecture_viewer_v3/lib/features/lecture_session/presentation/lecture_transcript_pane.dart` | Pass `TranscriptSpeakerDisplayOptions.viewer` |

**Out of scope**

- `lecture_viewer_v3/.../transcript_share_text.dart`
- `2way-v2` transcript / share call sites
- Inbound parsing / reducer / stored `speakerName` values

## Testing

| File | Cases |
|------|-------|
| `lecture_common/test/transcript/transcript_speaker_display_options_test.dart` | `displaySpeakerName` strips all `#` |
| `lecture_common/test/transcript/transcript_inline_format_test.dart` | **New** — unit tests for span text: default vs viewer options; `\n\n` mid-paragraph; leading `\n` when `paragraphIndex > 0`; no leading blank on index 0 |
| `lecture_common/test/transcript/translation_result_transcript_view_test.dart` | Widget test: viewer options → plain text contains blank line between speaker blocks |

Run: `flutter test` in `lecture_common` and `lecture_viewer_v3`.

## Error handling

- Empty `speakerName` after strip: still honor `show`; render empty bold line (edge case; no crash).
- Options default preserves 2way behavior; no migration.

## Non-goals

- Markdown/HTML transcript modules (future `TranscriptContentFormat` work)
- Changing paragraph `ListView` item padding
- Share sheet or exported plain text formatting
