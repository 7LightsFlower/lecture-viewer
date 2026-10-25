# Lecture Share Normal-Only Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove the module picker from the viewer share sheet and always export the Normal transcript (ASR first, then MT) per selected language.

**Architecture:** Add `normalRawSenderForShare` in `lecture_transcript_router.dart` (reuses `moduleOptionsForLanguage` sort order, filters to `asr`/`mt`, checks bucket content). `LectureShareInput` and `lecture_share_sheet.dart` delegate to it; callers drop `defaultRawSenderByLanguage`.

**Tech stack:** Flutter 3.10+, `lecture_common`, `share_plus`, existing share export isolate.

**Spec:** `docs/superpowers/specs/2026-05-20-lecture-share-normal-only-design.md`

---

## File map

| Path | Change |
|------|--------|
| `lib/features/lecture_session/domain/transcript/lecture_transcript_router.dart` | Add `normalRawSenderForShare` |
| `lib/features/lecture_session/domain/share/lecture_share_input.dart` | Use helper; remove `defaultRawSenderByLanguage` |
| `lib/features/lecture_session/presentation/lecture_share_sheet.dart` | Remove module UI/state; wire helper |
| `lib/features/lecture_session/presentation/lecture_session_screen.dart` | Simpler `LectureShareInput` |
| `lib/features/lecture_session/presentation/lecture_snapshot_screen.dart` | Same |
| `test/features/lecture_session/lecture_transcript_router_test.dart` | Unit tests for helper |
| `test/features/lecture_session/lecture_share_sheet_test.dart` | Widget tests (no dropdown) |

---

### Task 1: `normalRawSenderForShare` helper

**Files:**
- Modify: `lib/features/lecture_session/domain/transcript/lecture_transcript_router.dart`
- Modify: `test/features/lecture_session/lecture_transcript_router_test.dart`

- [ ] **Step 1: Write failing tests** — append to `lecture_transcript_router_test.dart`:

```dart
import 'package:lecture_viewer_v3/features/lecture_session/domain/transcript/lecture_bucket_key.dart';

TranscriptBucket _bucketWithText(String text) {
  return TranscriptBucket(
    paragraphs: [
      TranscriptParagraph(
        segments: [TranscriptSegment(text: text, textCompoundId: 'a')],
      ),
    ],
    speakerLabelByCompoundId: const {},
  );
}

SessionTranscriptState _transcriptFor({
  required String language,
  required String rawSender,
  required String text,
}) {
  return SessionTranscriptState(
    buckets: {
      lectureBucketKey(
        languageDisplayName: language,
        rawSender: rawSender,
      ): _bucketWithText(text),
    },
  );
}

// inside main(), after existing tests:

  test('normalRawSenderForShare prefers asr over mt when both have content', () {
    const language = 'English';
    final senders = {
      'asr:0': const ComputedSenderInfo(
        language: language,
        type: 'asr',
        percent: 0,
      ),
      'mt:1_en': const ComputedSenderInfo(
        language: language,
        type: 'mt',
        percent: 0,
        langCode: 'en',
      ),
    };
    final transcript = SessionTranscriptState(
      buckets: {
        lectureBucketKey(
          languageDisplayName: language,
          rawSender: 'asr:0',
        ): _bucketWithText('source'),
        lectureBucketKey(
          languageDisplayName: language,
          rawSender: 'mt:1_en',
        ): _bucketWithText('translated'),
      },
    );

    expect(
      normalRawSenderForShare(
        language: language,
        computedSenders: senders,
        transcript: transcript,
      ),
      'asr:0',
    );
  });

  test('normalRawSenderForShare uses mt when asr has no content', () {
    const language = 'English';
    final senders = {
      'asr:0': const ComputedSenderInfo(
        language: language,
        type: 'asr',
        percent: 0,
      ),
      'mt:1_en': const ComputedSenderInfo(
        language: language,
        type: 'mt',
        percent: 0,
        langCode: 'en',
      ),
    };
    final transcript = _transcriptFor(
      language: language,
      rawSender: 'mt:1_en',
      text: 'translated only',
    );

    expect(
      normalRawSenderForShare(
        language: language,
        computedSenders: senders,
        transcript: transcript,
      ),
      'mt:1_en',
    );
  });

  test('normalRawSenderForShare ignores postproduction-only content', () {
    const language = 'English';
    final senders = {
      'postproduction:70_en': const ComputedSenderInfo(
        language: language,
        type: 'postproduction',
        percent: 70,
        langCode: 'en',
      ),
    };
    final transcript = _transcriptFor(
      language: language,
      rawSender: 'postproduction:70_en',
      text: 'shortened',
    );

    expect(
      normalRawSenderForShare(
        language: language,
        computedSenders: senders,
        transcript: transcript,
      ),
      isNull,
    );
  });

  test('normalRawSenderForShare returns null when no normal content', () {
    const language = 'English';
    final senders = {
      'mt:1_en': const ComputedSenderInfo(
        language: language,
        type: 'mt',
        percent: 0,
      ),
    };

    expect(
      normalRawSenderForShare(
        language: language,
        computedSenders: senders,
        transcript: const SessionTranscriptState(buckets: {}),
      ),
      isNull,
    );
  });
```

- [ ] **Step 2: Run tests** — expect FAIL (undefined `normalRawSenderForShare`):

```bash
cd /Users/truong-d/Documents/code/lecture_viewer_v3 && flutter test test/features/lecture_session/lecture_transcript_router_test.dart
```

- [ ] **Step 3: Implement** — add after `defaultRawSenderForLanguage` in `lecture_transcript_router.dart`:

```dart
/// First Normal (`asr`, then `mt`) [rawSender] for [language] with shareable
/// bucket content, or null if none.
String? normalRawSenderForShare({
  required String language,
  required Map<String, ComputedSenderInfo> computedSenders,
  required SessionTranscriptState transcript,
}) {
  final options = moduleOptionsForLanguage(
    selectedLanguage: language,
    computedSenders: computedSenders,
  );
  for (final option in options) {
    final type = computedSenders[option.rawSender]?.type;
    if (type != 'asr' && type != 'mt') continue;
    final bucket = transcript.buckets[option.bucketKey];
    if (bucket != null && transcriptBucketHasDisplayableContent(bucket)) {
      return option.rawSender;
    }
  }
  return null;
}
```

- [ ] **Step 4: Run tests** — PASS:

```bash
cd /Users/truong-d/Documents/code/lecture_viewer_v3 && flutter test test/features/lecture_session/lecture_transcript_router_test.dart
```

- [ ] **Step 5: Commit**

```bash
git add lib/features/lecture_session/domain/transcript/lecture_transcript_router.dart \
  test/features/lecture_session/lecture_transcript_router_test.dart
git commit -m "feat: resolve Normal rawSender for share (asr then mt)"
```

---

### Task 2: `LectureShareInput` uses helper

**Files:**
- Modify: `lib/features/lecture_session/domain/share/lecture_share_input.dart`

- [ ] **Step 1: Replace class body**

```dart
import 'package:lecture_common/lecture_common.dart';
import 'package:lecture_viewer_v3/features/lecture_session/domain/transcript/lecture_bucket_key.dart';
import 'package:lecture_viewer_v3/features/lecture_session/domain/transcript/lecture_transcript_router.dart';

class LectureShareInput {
  const LectureShareInput({
    required this.subject,
    required this.activeLanguages,
    required this.computedSenders,
    required this.transcript,
  });

  final String subject;
  final List<String> activeLanguages;
  final Map<String, ComputedSenderInfo> computedSenders;
  final SessionTranscriptState transcript;

  List<String> languagesWithShareableContent() {
    return activeLanguages
        .where(
          (lang) =>
              normalRawSenderForShare(
                language: lang,
                computedSenders: computedSenders,
                transcript: transcript,
              ) !=
              null,
        )
        .toList();
  }

  TranscriptBucket? bucketFor({
    required String language,
    required String rawSender,
  }) {
    final key = lectureBucketKey(
      languageDisplayName: language,
      rawSender: rawSender,
    );
    return transcript.buckets[key];
  }
}
```

Remove unused imports: `lecture_supported_modules.dart` if no longer referenced.

- [ ] **Step 2: Analyze** — fix any compile errors in callers (next task); for this file alone:

```bash
cd /Users/truong-d/Documents/code/lecture_viewer_v3 && dart analyze lib/features/lecture_session/domain/share/lecture_share_input.dart
```

- [ ] **Step 3: Commit**

```bash
git add lib/features/lecture_session/domain/share/lecture_share_input.dart
git commit -m "refactor: share input uses normalRawSenderForShare only"
```

---

### Task 3: Simplify share sheet UI

**Files:**
- Modify: `lib/features/lecture_session/presentation/lecture_share_sheet.dart`

- [ ] **Step 1: Replace state class** — key edits:

1. Remove `_rawSenderByLanguage` field and entire `initState` body (empty or delete `initState`).
2. Remove `_moduleOptions` method.
3. Replace `_languageSelectable`:

```dart
  bool _languageSelectable(String language) {
    return normalRawSenderForShare(
          language: language,
          computedSenders: widget.input.computedSenders,
          transcript: widget.input.transcript,
        ) !=
        null;
  }
```

4. In `_shareSelected`, replace rawSender lookup:

```dart
        final rawSender = normalRawSenderForShare(
          language: language,
          computedSenders: widget.input.computedSenders,
          transcript: widget.input.transcript,
        );
        if (rawSender == null) continue;
```

5. In `build`, replace disabled subtitle:

```dart
                                    : const Text('No transcript is available'),
```

6. Remove the `if (selected && options.isNotEmpty)` `DropdownButtonFormField` block and simplify the list tile to a single `CheckboxListTile` per language (no wrapping `Column` with dropdown).

Example simplified list child:

```dart
                    for (final language in widget.input.activeLanguages)
                      Builder(
                        builder: (context) {
                          final selectable = _languageSelectable(language);
                          final selected = _selectedLanguages.contains(language);
                          return CheckboxListTile(
                            title: Text(language),
                            value: selectable ? selected : false,
                            enabled: selectable && !_sharing,
                            subtitle: selectable
                                ? null
                                : const Text('No transcript is available'),
                            onChanged: selectable && !_sharing
                                ? (v) {
                                    setState(() {
                                      if (v == true) {
                                        _selectedLanguages.add(language);
                                      } else {
                                        _selectedLanguages.remove(language);
                                      }
                                    });
                                  }
                                : null,
                          );
                        },
                      ),
```

- [ ] **Step 2: Analyze**

```bash
cd /Users/truong-d/Documents/code/lecture_viewer_v3 && dart analyze lib/features/lecture_session/presentation/lecture_share_sheet.dart
```

- [ ] **Step 3: Commit**

```bash
git add lib/features/lecture_session/presentation/lecture_share_sheet.dart
git commit -m "feat: share sheet exports Normal only, no module picker"
```

---

### Task 4: Update callers

**Files:**
- Modify: `lib/features/lecture_session/presentation/lecture_session_screen.dart`
- Modify: `lib/features/lecture_session/presentation/lecture_snapshot_screen.dart`

- [ ] **Step 1: `lecture_session_screen.dart`** — replace share `LectureShareInput` (lines ~140–150):

```dart
                  input: LectureShareInput(
                    subject: s.sessionId,
                    activeLanguages: s.activeLanguages,
                    computedSenders: s.computedSenders,
                    transcript: s.transcript,
                  ),
```

- [ ] **Step 2: `lecture_snapshot_screen.dart`** — replace share `LectureShareInput` (lines ~90–99):

```dart
      input: LectureShareInput(
        subject: widget.displayName,
        activeLanguages: record.activeLanguages,
        computedSenders: record.computedSenders,
        transcript: record.transcript,
      ),
```

- [ ] **Step 3: Project analyze**

```bash
cd /Users/truong-d/Documents/code/lecture_viewer_v3 && dart analyze lib/features/lecture_session/
```

Expected: no errors referencing `defaultRawSenderByLanguage`.

- [ ] **Step 4: Commit**

```bash
git add lib/features/lecture_session/presentation/lecture_session_screen.dart \
  lib/features/lecture_session/presentation/lecture_snapshot_screen.dart
git commit -m "chore: drop share defaultRawSenderByLanguage from callers"
```

---

### Task 5: Widget tests

**Files:**
- Modify: `test/features/lecture_session/lecture_share_sheet_test.dart`

- [ ] **Step 1: Replace test file**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lecture_common/lecture_common.dart';
import 'package:lecture_viewer_v3/features/lecture_session/domain/share/lecture_share_input.dart';
import 'package:lecture_viewer_v3/features/lecture_session/domain/transcript/lecture_bucket_key.dart';
import 'package:lecture_viewer_v3/features/lecture_session/presentation/lecture_share_sheet.dart';

void main() {
  testWidgets('share sheet has no module dropdown', (tester) async {
    final asrKey = lectureBucketKey(
      languageDisplayName: 'English',
      rawSender: 'asr:0',
    );
    final input = LectureShareInput(
      subject: 'Test lecture',
      activeLanguages: const ['English'],
      computedSenders: const {
        'mt:1_en': ComputedSenderInfo(
          language: 'English',
          type: 'mt',
          percent: 0,
        ),
        'asr:0': ComputedSenderInfo(
          language: 'English',
          type: 'asr',
          percent: 0,
        ),
      },
      transcript: SessionTranscriptState(
        buckets: {
          asrKey: TranscriptBucket(
            paragraphs: [
              TranscriptParagraph(
                segments: [
                  TranscriptSegment(text: 'Hi', textCompoundId: 'a'),
                ],
              ),
            ],
            speakerLabelByCompoundId: const {},
          ),
        },
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () => showLectureShareSheet(
                    context: context,
                    input: input,
                  ),
                  child: const Text('Open share'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open share'));
    await tester.pumpAndSettle();

    expect(find.text('Include recording'), findsNothing);
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);
    expect(find.text('Module'), findsNothing);
  });

  testWidgets('language without normal content shows unavailable subtitle',
      (tester) async {
    final input = LectureShareInput(
      subject: 'Test lecture',
      activeLanguages: const ['English', 'Japanese'],
      computedSenders: const {
        'postproduction:70_en': ComputedSenderInfo(
          language: 'English',
          type: 'postproduction',
          percent: 70,
        ),
      },
      transcript: SessionTranscriptState(
        buckets: {
          lectureBucketKey(
            languageDisplayName: 'English',
            rawSender: 'postproduction:70_en',
          ): TranscriptBucket(
            paragraphs: [
              TranscriptParagraph(
                segments: [
                  TranscriptSegment(text: 'Hi', textCompoundId: 'a'),
                ],
              ),
            ],
            speakerLabelByCompoundId: const {},
          ),
        },
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: FilledButton(
                onPressed: () => showLectureShareSheet(
                  context: context,
                  input: input,
                ),
                child: const Text('Open share'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open share'));
    await tester.pumpAndSettle();

    expect(find.text('No transcript is available'), findsWidgets);
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);
  });
}
```

- [ ] **Step 2: Run tests**

```bash
cd /Users/truong-d/Documents/code/lecture_viewer_v3 && flutter test test/features/lecture_session/lecture_transcript_router_test.dart test/features/lecture_session/lecture_share_sheet_test.dart
```

Expected: all PASS.

- [ ] **Step 3: Commit**

```bash
git add test/features/lecture_session/lecture_share_sheet_test.dart
git commit -m "test: share sheet Normal-only UI expectations"
```

---

### Task 6: Final verification

- [ ] **Step 1: Run session feature tests**

```bash
cd /Users/truong-d/Documents/code/lecture_viewer_v3 && flutter test test/features/lecture_session/
```

Expected: all PASS.

- [ ] **Step 2: Manual smoke (optional)**

1. Open a live lecture with English ASR + MT content → Share → only language checkboxes; export uses ASR text.
2. Open snapshot with postproduction-only language row → grayed with **No transcript is available**.

---

## Spec coverage checklist

| Spec requirement | Task |
|------------------|------|
| `normalRawSenderForShare` asr → mt | Task 1 |
| Remove module dropdown | Task 3 |
| Subtitle "No transcript is available" | Task 3, 5 |
| `LectureShareInput` without defaults | Task 2 |
| Callers updated | Task 4 |
| Unit + widget tests | Tasks 1, 5 |
| Out of scope (session controls) | — no tasks |
