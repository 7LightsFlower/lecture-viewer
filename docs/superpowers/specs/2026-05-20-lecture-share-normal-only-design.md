# Lecture share: Normal module only (viewer)

**Date:** 2026-05-20  
**Status:** Approved (brainstorming)  
**Scope:** `lecture_viewer_v3` share sheet only — not live session module picker or snapshot viewer controls.

## Problem

The share bottom sheet (`showLectureShareSheet`) shows a **Module** dropdown per selected language. Viewer users should not choose a module when sharing; they should always export the **Normal** transcript (`asr`, then `mt`). Postproduction (Shortening) must never be shared from this sheet.

## Goals

- Remove module selection from the share sheet UI.
- Per language, export the first **Normal** bucket with shareable content: **ASR first**, then **MT**.
- Gray out languages with no shareable Normal content; subtitle **"No transcript is available"**.
- Keep language checkboxes, Select all / Clear all, and existing export pipeline unchanged.

## Non-goals

- Changing `LectureSessionControls` or snapshot screen module dropdown.
- Changing how transcript is displayed during a live or offline session.
- Sharing postproduction or any non-Normal module type from this sheet.

## Module resolution

Add a domain helper in `lib/features/lecture_session/domain/transcript/lecture_transcript_router.dart`:

```dart
/// First Normal (asr, then mt) [rawSender] for [language] whose bucket has
/// displayable content in [transcript], or null if none.
String? normalRawSenderForShare({
  required String language,
  required Map<String, ComputedSenderInfo> computedSenders,
  required SessionTranscriptState transcript,
});
```

**Algorithm**

1. Call `moduleOptionsForLanguage(selectedLanguage: language, computedSenders: computedSenders)`.
2. Keep only options whose sender type is `asr` or `mt` (exclude `postproduction` and any other type).
3. In existing sort order (`asr` before `mt` via `_moduleTypeOrder`), iterate options.
4. For each option, resolve bucket via `lectureBucketKey` + `transcript.buckets[key]`.
5. Return the first `rawSender` where `transcriptBucketHasDisplayableContent(bucket)` is true.
6. Return `null` if no Normal option has content.

**Export:** `_shareSelected` uses this `rawSender` for each checked language. No user override.

## Share sheet UI

| Element | Behavior |
|---------|----------|
| Module dropdown | **Removed** |
| `_rawSenderByLanguage` state | **Removed** |
| Language `CheckboxListTile` | Unchanged when shareable |
| Disabled language row | `enabled: false`, subtitle **"No transcript is available"** (replaces "No transcript yet") |
| Select all / Clear all | Operates only on languages where `normalRawSenderForShare` is non-null |
| Share button | Same validation: at least one language selected; export uses resolved Normal sender |

## `LectureShareInput`

**File:** `lib/features/lecture_session/domain/share/lecture_share_input.dart`

- Remove `defaultRawSenderByLanguage` from constructor and fields.
- `languagesWithShareableContent()`: return `activeLanguages` where `normalRawSenderForShare(...)` is non-null (delegate to helper with `computedSenders` + `transcript`).

**Callers** — stop passing `defaultRawSenderByLanguage`:

- `lib/features/lecture_session/presentation/lecture_session_screen.dart`
- `lib/features/lecture_session/presentation/lecture_snapshot_screen.dart`

## Presentation

**File:** `lib/features/lecture_session/presentation/lecture_share_sheet.dart`

- `_languageSelectable(language)` → `normalRawSenderForShare(...) != null`.
- On share: for each selected language, use `normalRawSenderForShare` result (no map lookup).
- Remove `DropdownButtonFormField` block and related imports if unused.

## Error handling

Unchanged from existing share sheet:

- No language selected → SnackBar "Select at least one language".
- No exportable content after resolution → SnackBar "No transcript to share".
- Share failure → SnackBar "Could not open share sheet".

## Testing

| Test | Expectation |
|------|-------------|
| Unit: `normalRawSenderForShare` | ASR + MT both with content → ASR `rawSender` |
| Unit | Only MT with content → MT `rawSender` |
| Unit | Only postproduction with content → `null` |
| Unit | No buckets with content → `null` |
| Widget: `lecture_share_sheet_test` | No `DropdownButtonFormField`; disabled row shows "No transcript is available"; check language → Share still works with fixture |

## File touch list

| File | Change |
|------|--------|
| `domain/transcript/lecture_transcript_router.dart` | Add `normalRawSenderForShare` |
| `domain/share/lecture_share_input.dart` | Use helper; remove `defaultRawSenderByLanguage` |
| `presentation/lecture_share_sheet.dart` | Remove module UI; wire helper |
| `presentation/lecture_session_screen.dart` | Remove default map from `LectureShareInput` |
| `presentation/lecture_snapshot_screen.dart` | Same |
| `test/features/lecture_session/lecture_share_sheet_test.dart` | Update expectations |
| `test/features/lecture_session/` (new or existing) | Unit tests for helper |

## Relation to prior spec

Supersedes the **Module** row in `docs/superpowers/specs/2026-05-19-lecture-viewer-share-design.md` § Share sheet for viewer share-only behavior. Live session and offline **viewing** module pickers are unchanged.
