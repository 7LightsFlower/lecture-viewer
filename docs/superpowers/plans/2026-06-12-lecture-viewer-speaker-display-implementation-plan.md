# Lecture Viewer Speaker Display Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Viewer transcript shows bold speaker names with `#` stripped and a blank line before each new speaker block; 2way and share keep current behavior via default options.

**Architecture:** Add `TranscriptSpeakerDisplayOptions` in `lecture_common` with `viewer` and `defaults` presets. Thread optional `speakerDisplay` through transcript views into `TranscriptInlineFormat.paragraphInlineSpans`, which applies hash stripping, bold, and blank-line rules based on `paragraphIndex`. Only `lecture_viewer_v3` passes `TranscriptSpeakerDisplayOptions.viewer`.

**Tech stack:** Flutter 3.10+, Dart 3.10+, `lecture_common`, `lecture_viewer_v3`, `flutter_test`.

**Spec reference:** `docs/superpowers/specs/2026-06-12-lecture-viewer-speaker-display-design.md`

---

## File map

| Path | Action | Responsibility |
|------|--------|----------------|
| `lecture_common/lib/transcript/domain/transcript_speaker_display_options.dart` | Create | Options type, `displaySpeakerName`, presets |
| `lecture_common/lib/transcript/presentation/transcript_inline_format.dart` | Modify | Apply options + `paragraphIndex` |
| `lecture_common/lib/transcript/presentation/translation_result_transcript_view.dart` | Modify | Accept `speakerDisplay`, pass index |
| `lecture_common/lib/transcript/presentation/translation_result_transcript_follow_view.dart` | Modify | Forward `speakerDisplay` |
| `lecture_common/lib/lecture_common.dart` | Modify | Export options |
| `lecture_common/test/transcript/transcript_speaker_display_options_test.dart` | Create | Hash strip unit tests |
| `lecture_common/test/transcript/transcript_inline_format_test.dart` | Create | Span/plain-text unit tests |
| `lecture_common/test/transcript/translation_result_transcript_view_test.dart` | Modify | Widget test for viewer blank line |
| `lecture_viewer_v3/lib/features/lecture_session/presentation/lecture_transcript_pane.dart` | Modify | Pass `TranscriptSpeakerDisplayOptions.viewer` |

---

### Task 1: `TranscriptSpeakerDisplayOptions`

**Files:**
- Create: `lecture_common/lib/transcript/domain/transcript_speaker_display_options.dart`
- Create: `lecture_common/test/transcript/transcript_speaker_display_options_test.dart`

- [ ] **Step 1: Write the failing test**

Create `lecture_common/test/transcript/transcript_speaker_display_options_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lecture_common/lecture_common.dart';

void main() {
  test('displaySpeakerName strips all hash characters', () {
    const options = TranscriptSpeakerDisplayOptions(
      stripHashFromSpeakerName: true,
    );

    expect(
      options.displaySpeakerName('Speaker #1'),
      'Speaker 1',
    );
    expect(
      options.displaySpeakerName('Speaker#2'),
      'Speaker2',
    );
    expect(
      options.displaySpeakerName('no-hash'),
      'no-hash',
    );
  });

  test('displaySpeakerName leaves name unchanged when strip disabled', () {
    const options = TranscriptSpeakerDisplayOptions.defaults;

    expect(
      options.displaySpeakerName('Speaker #1'),
      'Speaker #1',
    );
  });

  test('viewer preset enables strip and blank line', () {
    expect(
      TranscriptSpeakerDisplayOptions.viewer.stripHashFromSpeakerName,
      isTrue,
    );
    expect(
      TranscriptSpeakerDisplayOptions.viewer.blankLineBeforeSpeaker,
      isTrue,
    );
    expect(TranscriptSpeakerDisplayOptions.viewer.boldSpeaker, isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run from `lecture_common/`:

```bash
flutter test test/transcript/transcript_speaker_display_options_test.dart
```

Expected: FAIL — `TranscriptSpeakerDisplayOptions` not defined.

- [ ] **Step 3: Write minimal implementation**

Create `lecture_common/lib/transcript/domain/transcript_speaker_display_options.dart`:

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

  String displaySpeakerName(String raw) {
    if (!stripHashFromSpeakerName) return raw;
    return raw.replaceAll('#', '');
  }
}
```

Add export to `lecture_common/lib/lecture_common.dart` (after speaker_label_state export):

```dart
export 'transcript/domain/transcript_speaker_display_options.dart';
```

- [ ] **Step 4: Run test to verify it passes**

```bash
flutter test test/transcript/transcript_speaker_display_options_test.dart
```

Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
cd lecture_common
git add lib/transcript/domain/transcript_speaker_display_options.dart \
  lib/lecture_common.dart \
  test/transcript/transcript_speaker_display_options_test.dart
git commit -m "$(cat <<'EOF'
Add TranscriptSpeakerDisplayOptions for viewer speaker formatting.

EOF
)"
```

---

### Task 2: `TranscriptInlineFormat` blank line + hash strip

**Files:**
- Modify: `lecture_common/lib/transcript/presentation/transcript_inline_format.dart`
- Create: `lecture_common/test/transcript/transcript_inline_format_test.dart`

- [ ] **Step 1: Write the failing tests**

Create `lecture_common/test/transcript/transcript_inline_format_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lecture_common/lecture_common.dart';

String _plainText(List<InlineSpan> spans) {
  return TextSpan(children: spans).toPlainText();
}

TranscriptBucket _bucketWithSpeakers({
  required List<({String cid, String text, bool show, String name})> rows,
}) {
  final segments = <TranscriptSegment>[];
  final labels = <String, SpeakerLabelState>{};

  for (final row in rows) {
    segments.add(TranscriptSegment(text: row.text, textCompoundId: row.cid));
    labels[row.cid] = SpeakerLabelState(show: row.show, speakerName: row.name);
  }

  return TranscriptBucket(
    paragraphs: [TranscriptParagraph(segments: segments)],
    speakerLabelByCompoundId: labels,
  );
}

void main() {
  const bodyStyle = TextStyle(fontSize: 16);
  const labelStyle = TextStyle(fontSize: 14);

  test('defaults: single newline before mid-paragraph speaker', () {
    final bucket = _bucketWithSpeakers(
      rows: [
        (cid: 'a', text: 'Hello', show: true, name: 'Speaker 1'),
        (cid: 'b', text: 'World', show: true, name: 'Speaker 2'),
      ],
    );

    final text = _plainText(
      TranscriptInlineFormat.paragraphInlineSpans(
        activeBucket: bucket,
        paragraph: bucket.paragraphs.first,
        labelStyle: labelStyle,
        bodyStyle: bodyStyle,
        paragraphIndex: 0,
      ),
    );

    expect(text, 'Speaker 1\nHello\nSpeaker 2\nWorld');
  });

  test('viewer: blank line before mid-paragraph speaker and strips hash', () {
    final bucket = _bucketWithSpeakers(
      rows: [
        (cid: 'a', text: 'Hello', show: true, name: 'Speaker #1'),
        (cid: 'b', text: 'World', show: true, name: 'Speaker #2'),
      ],
    );

    final text = _plainText(
      TranscriptInlineFormat.paragraphInlineSpans(
        activeBucket: bucket,
        paragraph: bucket.paragraphs.first,
        labelStyle: labelStyle,
        bodyStyle: bodyStyle,
        paragraphIndex: 0,
        speakerDisplay: TranscriptSpeakerDisplayOptions.viewer,
      ),
    );

    expect(text, 'Speaker 1\nHello\n\nSpeaker 2\nWorld');
  });

  test('viewer: leading blank when paragraph starts with speaker and index > 0', () {
    final bucket = TranscriptBucket(
      paragraphs: [
        TranscriptParagraph(
          segments: [
            TranscriptSegment(text: 'Only', textCompoundId: 'a'),
          ],
        ),
        TranscriptParagraph(
          segments: [
            TranscriptSegment(text: 'Next', textCompoundId: 'b'),
          ],
        ),
      ],
      speakerLabelByCompoundId: {
        'b': const SpeakerLabelState(show: true, speakerName: 'Speaker #2'),
      },
    );

    final text = _plainText(
      TranscriptInlineFormat.paragraphInlineSpans(
        activeBucket: bucket,
        paragraph: bucket.paragraphs[1],
        labelStyle: labelStyle,
        bodyStyle: bodyStyle,
        paragraphIndex: 1,
        speakerDisplay: TranscriptSpeakerDisplayOptions.viewer,
      ),
    );

    expect(text, '\nSpeaker 2\nNext');
  });

  test('viewer: no leading blank on first paragraph index 0', () {
    final bucket = _bucketWithSpeakers(
      rows: [
        (cid: 'a', text: 'Hi', show: true, name: 'Speaker #1'),
      ],
    );

    final text = _plainText(
      TranscriptInlineFormat.paragraphInlineSpans(
        activeBucket: bucket,
        paragraph: bucket.paragraphs.first,
        labelStyle: labelStyle,
        bodyStyle: bodyStyle,
        paragraphIndex: 0,
        speakerDisplay: TranscriptSpeakerDisplayOptions.viewer,
      ),
    );

    expect(text, 'Speaker 1\nHi');
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd lecture_common
flutter test test/transcript/transcript_inline_format_test.dart
```

Expected: FAIL — unknown named params `paragraphIndex` / `speakerDisplay`, or wrong plain text.

- [ ] **Step 3: Implement `paragraphInlineSpans` changes**

Replace speaker-label block in `lecture_common/lib/transcript/presentation/transcript_inline_format.dart`.

Add import:

```dart
import '../domain/transcript_speaker_display_options.dart';
```

Update method signature:

```dart
  static List<InlineSpan> paragraphInlineSpans({
    required TranscriptBucket activeBucket,
    required TranscriptParagraph paragraph,
    required TextStyle? labelStyle,
    required TextStyle? bodyStyle,
    String? partialText,
    TextStyle? partialStyle,
    int paragraphIndex = 0,
    TranscriptSpeakerDisplayOptions speakerDisplay =
        TranscriptSpeakerDisplayOptions.defaults,
  }) {
```

Replace the `if (labelState?.show == true)` block with:

```dart
      if (labelState?.show == true) {
        if (speakerDisplay.blankLineBeforeSpeaker) {
          if (spans.isNotEmpty) {
            spans.add(TextSpan(text: '\n\n', style: bodyStyle));
          } else if (paragraphIndex > 0) {
            spans.add(TextSpan(text: '\n', style: bodyStyle));
          }
        } else if (spans.isNotEmpty) {
          spans.add(TextSpan(text: '\n', style: bodyStyle));
        }

        final speakerStyle = speakerDisplay.boldSpeaker
            ? labelStyle?.copyWith(fontWeight: FontWeight.bold) ??
                const TextStyle(fontWeight: FontWeight.bold)
            : labelStyle;

        spans.add(
          TextSpan(
            text: speakerDisplay.displaySpeakerName(labelState!.speakerName),
            style: speakerStyle,
          ),
        );
        spans.add(TextSpan(text: '\n', style: bodyStyle));
        lastSegmentTextForGap = '';
      }
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
flutter test test/transcript/transcript_inline_format_test.dart
```

Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/transcript/presentation/transcript_inline_format.dart \
  test/transcript/transcript_inline_format_test.dart
git commit -m "$(cat <<'EOF'
Apply viewer speaker display options in transcript inline format.

EOF
)"
```

---

### Task 3: Thread `speakerDisplay` through transcript views

**Files:**
- Modify: `lecture_common/lib/transcript/presentation/translation_result_transcript_view.dart`
- Modify: `lecture_common/lib/transcript/presentation/translation_result_transcript_follow_view.dart`
- Modify: `lecture_common/test/transcript/translation_result_transcript_view_test.dart`

- [ ] **Step 1: Write failing widget test**

Append to `lecture_common/test/transcript/translation_result_transcript_view_test.dart`:

```dart
  testWidgets('viewer speaker display adds blank line between speakers', (
    WidgetTester tester,
  ) async {
    const bucket = TranscriptBucket(
      paragraphs: [
        TranscriptParagraph(
          segments: [
            TranscriptSegment(text: 'Hello', textCompoundId: 'a'),
            TranscriptSegment(text: 'World', textCompoundId: 'b'),
          ],
        ),
      ],
      speakerLabelByCompoundId: {
        'a': SpeakerLabelState(show: true, speakerName: 'Speaker #1'),
        'b': SpeakerLabelState(show: true, speakerName: 'Speaker #2'),
      },
    );

    await tester.pumpWidget(
      _wrap(
        const TranslationResultTranscriptView(
          textScaler: TextScaler.noScaling,
          activeBucket: bucket,
          speakerDisplay: TranscriptSpeakerDisplayOptions.viewer,
        ),
      ),
    );

    final rich = tester.widget<RichText>(find.byType(RichText));
    expect(
      rich.text.toPlainText(),
      'Speaker 1\nHello\n\nSpeaker 2\nWorld',
    );
  });
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd lecture_common
flutter test test/transcript/translation_result_transcript_view_test.dart --name "viewer speaker"
```

Expected: FAIL — `speakerDisplay` parameter missing.

- [ ] **Step 3: Wire `speakerDisplay` in views**

In `translation_result_transcript_view.dart`, add import:

```dart
import '../domain/transcript_speaker_display_options.dart';
```

Add field to constructor:

```dart
    this.speakerDisplay = TranscriptSpeakerDisplayOptions.defaults,
```

```dart
  final TranscriptSpeakerDisplayOptions speakerDisplay;
```

Pass into `paragraphInlineSpans`:

```dart
        final spans = TranscriptInlineFormat.paragraphInlineSpans(
          activeBucket: activeBucket,
          paragraph: paragraph,
          labelStyle: labelStyle,
          bodyStyle: bodyStyle,
          partialText: isLastItem && hasPartial ? partial : null,
          partialStyle: partialStyle,
          paragraphIndex: index,
          speakerDisplay: speakerDisplay,
        );
```

In `translation_result_transcript_follow_view.dart`, add import and forward param:

```dart
import '../domain/transcript_speaker_display_options.dart';
```

```dart
    this.speakerDisplay = TranscriptSpeakerDisplayOptions.defaults,
```

```dart
  final TranscriptSpeakerDisplayOptions speakerDisplay;
```

In `build`, pass to child:

```dart
        TranslationResultTranscriptView(
          textScaler: widget.textScaler,
          activeBucket: widget.activeBucket,
          scrollController: _scrollController,
          speakerDisplay: widget.speakerDisplay,
        ),
```

- [ ] **Step 4: Run tests**

```bash
flutter test test/transcript/translation_result_transcript_view_test.dart
flutter test
```

Expected: all `lecture_common` tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/transcript/presentation/translation_result_transcript_view.dart \
  lib/transcript/presentation/translation_result_transcript_follow_view.dart \
  test/transcript/translation_result_transcript_view_test.dart
git commit -m "$(cat <<'EOF'
Thread speaker display options through transcript views.

EOF
)"
```

---

### Task 4: Wire viewer transcript pane

**Files:**
- Modify: `lecture_viewer_v3/lib/features/lecture_session/presentation/lecture_transcript_pane.dart`

- [ ] **Step 1: Pass viewer options in `LectureTranscriptPane`**

In `lecture_transcript_pane.dart`, update `TranslationResultTranscriptFollowView`:

```dart
      child: TranslationResultTranscriptFollowView(
        textScaler: textScaler,
        activeBucket: activeBucket,
        followScopeKey: followScopeKey,
        speakerDisplay: TranscriptSpeakerDisplayOptions.viewer,
      ),
```

(`lecture_common` is already imported.)

- [ ] **Step 2: Run viewer tests**

```bash
cd ../lecture_viewer_v3
flutter test
```

Expected: PASS — no behavior change in existing unit tests (pane tests do not assert speaker layout).

- [ ] **Step 3: Manual smoke check**

1. Open live lecture session with speaker diarization enabled.
2. Confirm speaker blocks show: bold name, no `#`, blank line before each new speaker.
3. Open saved snapshot with multiple speakers — same formatting.

- [ ] **Step 4: Commit**

```bash
git add lib/features/lecture_session/presentation/lecture_transcript_pane.dart
git commit -m "$(cat <<'EOF'
Use viewer speaker display options in lecture transcript pane.

EOF
)"
```

---

## Spec coverage checklist

| Spec requirement | Task |
|------------------|------|
| Bold speaker names | Task 2 (`boldSpeaker`) |
| Strip all `#` | Task 1 + Task 2 |
| Blank line between speaker blocks | Task 2 |
| No leading blank on first item | Task 2 test + logic |
| Viewer only scope | Task 4 |
| 2way/share unchanged defaults | Task 2 default branch + Task 3 default param |
| No bucket mutation | Task 2 render-time only |
| Tests in `lecture_common` | Tasks 1–3 |
| `flutter test` both packages | Tasks 3–4 |

## Manual verification

- Live session: two+ speakers → blank line between blocks, bold, no `#`.
- Snapshot screen: same as live.
- Share export from viewer: unchanged (still raw `speakerName` with `#` if present).
- 2way app (if available): single `\n` before mid-paragraph speaker, no extra blank line at paragraph boundaries.
