# Transcript content formats (HTML / Markdown / plain)

## 1. Context

- **Product ask:** Transcript text from the server can include HTML markup or Markdown, depending on module. Plain `Text` / `Text.rich` shows entities and syntax literally.
- **Scope:** Shared rendering in `lecture_common` so **app_2way_v3** and **lecture_viewer_v3** both benefit via `TranslationResultTranscriptView`.
- **Clarifications (brainstorming):**
  - Each module (`rawSender`, e.g. `mt:0`, `asr:0`) returns **one** format only — never mixed within a module.
  - Format is determined **client-side** by module **type** (prefix before `:`), not server metadata in v1.
  - **Plain text** modules (`asr`, `mt`): show strings **exactly as received** — no HTML entity decoding.
  - **app_2way_v3:** Partner and You panels both display **mt** transcript buckets (language-keyed). `asr:*` is used for live preview only, not stored in transcript buckets.

## 2. Module type → format mapping

| Module type (`rawSender` prefix) | `TranscriptContentFormat` |
|----------------------------------|---------------------------|
| `asr` | `plain` |
| `mt` | `plain` |
| `textstructurer` | `html` |
| `summarizer` | `markdown` |
| `postproduction` | `markdown` |
| Unknown (e.g. `tts`) | `plain` |

```dart
enum TranscriptContentFormat { plain, html, markdown }

String moduleTypeFromRawSender(String rawSender) =>
    rawSender.split(':').first;

TranscriptContentFormat contentFormatForModuleType(String type) =>
    switch (type) {
      'textstructurer' => TranscriptContentFormat.html,
      'summarizer' || 'postproduction' => TranscriptContentFormat.markdown,
      _ => TranscriptContentFormat.plain,
    };
```

## 3. Goals and non-goals

**Goals**

1. Render finalized paragraph bodies and partial lines according to the active bucket’s format.
2. Keep speaker labels as plain `Text` (outside formatted body).
3. Preserve existing segment spacing rules (`needsInsertedSpaceBetween`, `partialWithGap`).
4. Single shared API in `lecture_common`; apps pass `contentFormat` into `TranslationResultTranscriptView`.
5. Graceful fallback: parse/render errors show raw string as plain `Text`.

**Non-goals (v1)**

- Server-provided `contentFormat` on `computedSenders` or text events.
- HTML entity decoding on `plain` modules.
- Session share summarization UI in app_2way_v3 (`session_share_sheet` markdown preview).
- TTS overlay text in `translation_tts_transport.dart`.
- Auto-detect format from content heuristics.

## 4. Architecture

### 4.1 New / changed files (`lecture_common`)

| File | Role |
|------|------|
| `lib/transcript/domain/transcript_content_format.dart` | Enum + `moduleTypeFromRawSender` + `contentFormatForModuleType` |
| `lib/transcript/presentation/transcript_formatted_body.dart` | Renders one string by format (`plain` / `html` / `markdown`) |
| `lib/transcript/presentation/transcript_paragraph_tile.dart` | Speaker label + formatted body per paragraph |
| `lib/transcript/presentation/translation_result_transcript_view.dart` | Add required `contentFormat`; branch list item builder |
| `lib/lecture_common.dart` | Export new public API |

**Dependencies** (add to `lecture_common/pubspec.yaml` only):

- `flutter_html` — HTML body for `textstructurer`
- `flutter_markdown` — Markdown body for `summarizer` / `postproduction`

### 4.2 Paragraph assembly

1. For each `TranscriptParagraph`, join segment `text` values using existing `needsInsertedSpaceBetween` (same as `TranscriptInlineFormat` today).
2. If a speaker label should show (`speakerLabelByCompoundId`), render plain `Text` for name, then formatted body below.
3. For `plain`, keep current `Text.rich` + `TranscriptInlineFormat.paragraphInlineSpans` path (no behavior change except explicit format param).

### 4.3 Formatted body widgets

| Format | Widget | Notes |
|--------|--------|-------|
| `plain` | `Text.rich` | Literal bytes; `&amp;` stays `&amp;` |
| `html` | `HtmlWidget` / `flutter_html` | `shrinkWrap: true`; style from `theme.textTheme.bodyLarge`; disallow `script`, `iframe` |
| `markdown` | `MarkdownBody` | `shrinkWrap: true`; `physics: NeverScrollableScrollPhysics()`; stylesheet from theme |

Apply `textScaler` where the package supports it; otherwise document limitation.

### 4.4 Partial line

- Use same `contentFormat` as the active view.
- Apply `partialWithGap` before rendering.
- Incomplete markdown/HTML during live streaming may look rough briefly — acceptable for v1.

### 4.5 `TranslationResultTranscriptView` API

```dart
TranslationResultTranscriptView({
  required TextScaler textScaler,
  required TranscriptBucket activeBucket,
  required TranscriptContentFormat contentFormat,
  ScrollController? scrollController,
});
```

## 5. App integration

### 5.1 lecture_viewer_v3

Bucket is selected by `selectedRawSender` (module). Pass:

```dart
contentFormat: contentFormatForModuleType(
  moduleTypeFromRawSender(state.selectedRawSender),
),
```

Wire at `lecture_session_screen.dart` (and any other `TranslationResultTranscriptView` call sites).

### 5.2 app_2way_v3

- **Partner** and **You** panels both read **mt** content from language-keyed buckets (`partnerActiveDisplayKey` / `youActiveDisplayKey`).
- **ASR** (`asr:*`) events are not applied to transcript buckets; they feed middle-strip live preview only.
- Both panels use:

```dart
contentFormat: contentFormatForModuleType('mt'), // → plain
```

Wire at `translation_screen.dart` and `translation_result_panel.dart` call sites.

## 6. Error handling

- HTML/markdown widget build failures → `Text(rawString)` with `bodyStyle`.
- Do not crash the session UI on malformed markup.
- No network loads from rendered HTML (no remote images/scripts in v1 if configurable).

## 7. Testing

| Test file | Coverage |
|-----------|----------|
| `test/transcript/transcript_content_format_test.dart` | All module types + unknown → expected format |
| `test/transcript/transcript_formatted_body_test.dart` | Widget: `**bold**` renders bold; `<b>x</b>` bold; plain shows literal `&amp;` |
| Existing reducer / JSON tests | Unchanged — storage remains raw strings |

## 8. Approach chosen

**Widget-based renderers (Approach 1)** in `lecture_common`:

- Plain stays `Text.rich`.
- HTML and Markdown use established packages per paragraph.
- Apps only supply `contentFormat`; no duplicated rendering logic.

Rejected alternatives: pre-parsing to `InlineSpan` only (weak block support); format handling only in apps (duplication).
