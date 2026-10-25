# Auto-scroll viewer transcript — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Follow latest transcript text in lecture viewer (live + snapshot) with scroll-position UX and a jump-to-latest FAB; share wrapper in `lecture_common`; ~2 lines bottom padding on the transcript list.

**Architecture:** Bump `TranslationResultTranscriptView` list bottom padding to 2× line height. Add `TranslationResultTranscriptFollowView` (owns `ScrollController`, `followLatest`, FAB overlay) wrapping the render view. Wire `LectureTranscriptPane` to the follow wrapper when content exists.

**Tech stack:** Flutter 3.10+, `lecture_common` (path dep), `flutter_test` widget tests.

**Spec:** `docs/superpowers/specs/2026-05-19-auto-scroll-viewer-content-design.md`

---

## File map

| Path | Responsibility |
|------|----------------|
| `lecture_common/lib/transcript/presentation/translation_result_transcript_view.dart` | `padding.bottom` → 2× `oneLineHeight` |
| `lecture_common/lib/transcript/presentation/translation_result_transcript_follow_view.dart` | **NEW** — follow + FAB |
| `lecture_common/lib/lecture_common.dart` | Export follow view |
| `lecture_common/test/transcript/translation_result_transcript_view_test.dart` | Optional padding regression (implicit via layout) |
| `lecture_common/test/transcript/translation_result_transcript_follow_view_test.dart` | **NEW** — follow/FAB tests |
| `lecture_viewer_v3/lib/features/lecture_session/presentation/lecture_transcript_pane.dart` | Use `TranslationResultTranscriptFollowView` |

**Repos:** Implement in `lecture_common` first, then `lecture_viewer_v3`. No `app_2way_v3` changes in v1.

---

### Task 1: Double bottom padding on transcript list

**Files:**
- Modify: `lecture_common/lib/transcript/presentation/translation_result_transcript_view.dart`

- [ ] **Step 1: Change padding calculation**

In `build`, replace:

```dart
    final bottomBlankHeight = TranscriptInlineFormat.oneLineHeight(bodyStyle);
```

with:

```dart
    final lineHeight = TranscriptInlineFormat.oneLineHeight(bodyStyle);
    final bottomBlankHeight = lineHeight * 2;
```

(`padding: EdgeInsets.only(bottom: bottomBlankHeight)` stays unchanged.)

- [ ] **Step 2: Run existing tests**

```bash
cd /Users/macbook/Works/Lecture_Translation_Alex/lecture_common && flutter test test/transcript/translation_result_transcript_view_test.dart
```

Expected: **All tests PASS** (padding change does not break text assertions).

- [ ] **Step 3: Commit** (when user requests commit)

```bash
cd /Users/macbook/Works/Lecture_Translation_Alex/lecture_common
git add lib/transcript/presentation/translation_result_transcript_view.dart
git commit -m "feat(common): add two-line bottom padding to transcript list"
```

---

### Task 2: `TranslationResultTranscriptFollowView` widget

**Files:**
- Create: `lecture_common/lib/transcript/presentation/translation_result_transcript_follow_view.dart`
- Modify: `lecture_common/lib/lecture_common.dart`

- [ ] **Step 1: Create follow view file**

```dart
import 'package:flutter/material.dart';

import '../data/transcript_bucket.dart';
import 'translation_result_transcript_view.dart';

/// Distance from [ScrollPosition.maxScrollExtent] treated as "at bottom".
const double kTranscriptFollowBottomThreshold = 48.0;

/// Scrollable transcript that follows the latest text unless the user scrolls up.
class TranslationResultTranscriptFollowView extends StatefulWidget {
  const TranslationResultTranscriptFollowView({
    super.key,
    required this.textScaler,
    required this.activeBucket,
    this.scrollToBottomIcon = Icons.keyboard_arrow_down,
  });

  final TextScaler textScaler;
  final TranscriptBucket activeBucket;
  final IconData scrollToBottomIcon;

  @override
  State<TranslationResultTranscriptFollowView> createState() =>
      _TranslationResultTranscriptFollowViewState();
}

class _TranslationResultTranscriptFollowViewState
    extends State<TranslationResultTranscriptFollowView> {
  final ScrollController _scrollController = ScrollController();
  bool _followLatest = true;
  bool _showFab = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scrollToBottomIfFollowing();
      _syncFabVisibility();
    });
  }

  @override
  void didUpdateWidget(TranslationResultTranscriptFollowView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeBucket != widget.activeBucket) {
      _followLatest = true;
      _showFab = false;
    }
    if (_followLatest) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _scrollToBottom();
        _syncFabVisibility();
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  bool _isNearBottom(ScrollPosition position) {
    if (!position.hasContentDimensions) return true;
    if (position.maxScrollExtent <= 0) return true;
    return position.maxScrollExtent - position.pixels <=
        kTranscriptFollowBottomThreshold;
  }

  bool _canScroll(ScrollPosition position) {
    if (!position.hasContentDimensions) return false;
    return position.maxScrollExtent > kTranscriptFollowBottomThreshold;
  }

  void _syncFabVisibility() {
    if (!_scrollController.hasClients) {
      if (_showFab) setState(() => _showFab = false);
      return;
    }
    final position = _scrollController.position;
    final nextShowFab = !_followLatest && _canScroll(position);
    if (nextShowFab != _showFab) {
      setState(() => _showFab = nextShowFab);
    }
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (!position.hasContentDimensions) return;
    _scrollController.jumpTo(position.maxScrollExtent);
  }

  void _scrollToBottomIfFollowing() {
    if (!_followLatest) return;
    _scrollToBottom();
  }

  void _onUserScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final nearBottom = _isNearBottom(position);

    if (nearBottom) {
      if (!_followLatest || _showFab) {
        setState(() {
          _followLatest = true;
          _showFab = false;
        });
      }
      return;
    }

    if (_followLatest) {
      setState(() {
        _followLatest = false;
        _showFab = _canScroll(position);
      });
      return;
    }

    _syncFabVisibility();
  }

  void _onFabPressed() {
    setState(() {
      _followLatest = true;
      _showFab = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scrollToBottom();
    });
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification is UserScrollNotification ||
        notification is ScrollEndNotification) {
      _onUserScroll();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: _handleScrollNotification,
          child: TranslationResultTranscriptView(
            textScaler: widget.textScaler,
            activeBucket: widget.activeBucket,
            scrollController: _scrollController,
          ),
        ),
        if (_showFab)
          Positioned(
            right: 12,
            bottom: 12,
            child: FloatingActionButton.small(
              onPressed: _onFabPressed,
              tooltip: 'Scroll to latest',
              child: Icon(widget.scrollToBottomIcon),
            ),
          ),
      ],
    );
  }
}
```

- [ ] **Step 2: Export from barrel**

Add after the transcript view export in `lecture_common/lib/lecture_common.dart`:

```dart
export 'transcript/presentation/translation_result_transcript_follow_view.dart';
```

- [ ] **Step 3: Analyze**

```bash
cd /Users/macbook/Works/Lecture_Translation_Alex/lecture_common && dart analyze lib/transcript/presentation/translation_result_transcript_follow_view.dart
```

Expected: **No issues**.

- [ ] **Step 4: Commit**

```bash
cd /Users/macbook/Works/Lecture_Translation_Alex/lecture_common
git add lib/transcript/presentation/translation_result_transcript_follow_view.dart lib/lecture_common.dart
git commit -m "feat(common): add transcript follow-latest scroll wrapper"
```

---

### Task 3: Widget tests for follow view

**Files:**
- Create: `lecture_common/test/transcript/translation_result_transcript_follow_view_test.dart`

- [ ] **Step 1: Add test helpers and tall bucket**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lecture_common/lecture_common.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        height: 200,
        width: 400,
        child: child,
      ),
    ),
  );
}

TranscriptBucket _tallBucket({required int paragraphCount}) {
  return TranscriptBucket(
    paragraphs: List<TranscriptParagraph>.generate(
      paragraphCount,
      (int i) => TranscriptParagraph(
        segments: [
          TranscriptSegment(
            text: 'Paragraph ${i + 1}. ' * 8,
            textCompoundId: 'mt:1|t$i',
          ),
        ],
      ),
    ),
    speakerLabelByCompoundId: const {},
  );
}
```

- [ ] **Step 2: Test — FAB after user scrolls up**

```dart
  testWidgets('shows FAB when user scrolls away from bottom', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        TranslationResultTranscriptFollowView(
          textScaler: TextScaler.noScaling,
          activeBucket: _tallBucket(paragraphCount: 12),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(FloatingActionButton), findsNothing);

    await tester.drag(find.byType(ListView), const Offset(0, 120));
    await tester.pumpAndSettle();

    expect(find.byType(FloatingActionButton), findsOneWidget);
  });
```

- [ ] **Step 3: Run test — expect FAIL** (widget exists but behavior may already pass; if PASS, skip to Step 5)

```bash
cd /Users/macbook/Works/Lecture_Translation_Alex/lecture_common && flutter test test/transcript/translation_result_transcript_follow_view_test.dart --plain-name "shows FAB"
```

- [ ] **Step 4: Test — FAB tap hides FAB and scrolls near bottom**

```dart
  testWidgets('FAB tap re-enables follow and hides FAB', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        TranslationResultTranscriptFollowView(
          textScaler: TextScaler.noScaling,
          activeBucket: _tallBucket(paragraphCount: 12),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, 120));
    await tester.pumpAndSettle();
    expect(find.byType(FloatingActionButton), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.byType(FloatingActionButton), findsNothing);

    final scrollable =
        tester.widget<Scrollable>(find.byType(Scrollable).first);
    final position = scrollable.controller!.position;
    expect(
      position.maxScrollExtent - position.pixels,
      lessThanOrEqualTo(kTranscriptFollowBottomThreshold + 1),
    );
  });
```

- [ ] **Step 5: Test — bucket growth scrolls to bottom while following**

```dart
  testWidgets('follows bucket updates when at bottom', (
    WidgetTester tester,
  ) async {
    var bucket = _tallBucket(paragraphCount: 8);

    await tester.pumpWidget(
      _wrap(
        TranslationResultTranscriptFollowView(
          textScaler: TextScaler.noScaling,
          activeBucket: bucket,
        ),
      ),
    );
    await tester.pumpAndSettle();

    bucket = _tallBucket(paragraphCount: 14);
    await tester.pumpWidget(
      _wrap(
        TranslationResultTranscriptFollowView(
          textScaler: TextScaler.noScaling,
          activeBucket: bucket,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final scrollable =
        tester.widget<Scrollable>(find.byType(Scrollable).first);
    final position = scrollable.controller!.position;
    expect(
      position.maxScrollExtent - position.pixels,
      lessThanOrEqualTo(kTranscriptFollowBottomThreshold + 1),
    );
    expect(find.byType(FloatingActionButton), findsNothing);
  });
```

- [ ] **Step 6: Run all follow tests**

```bash
cd /Users/macbook/Works/Lecture_Translation_Alex/lecture_common && flutter test test/transcript/translation_result_transcript_follow_view_test.dart
```

Expected: **All PASS**.

- [ ] **Step 7: Run full lecture_common transcript tests**

```bash
cd /Users/macbook/Works/Lecture_Translation_Alex/lecture_common && flutter test test/transcript/
```

Expected: **All PASS**.

- [ ] **Step 8: Commit**

```bash
cd /Users/macbook/Works/Lecture_Translation_Alex/lecture_common
git add test/transcript/translation_result_transcript_follow_view_test.dart
git commit -m "test(common): cover transcript follow-latest and FAB"
```

---

### Task 4: Wire viewer `LectureTranscriptPane`

**Files:**
- Modify: `lecture_viewer_v3/lib/features/lecture_session/presentation/lecture_transcript_pane.dart`

- [ ] **Step 1: Swap transcript widget**

Replace the return when content exists (lines ~44–47):

```dart
    return TranslationResultTranscriptView(
      textScaler: textScaler,
      activeBucket: activeBucket,
    );
```

with:

```dart
    return TranslationResultTranscriptFollowView(
      textScaler: textScaler,
      activeBucket: activeBucket,
    );
```

No import change needed if file already imports `package:lecture_common/lecture_common.dart` (follow view exported from barrel after Task 2).

- [ ] **Step 2: Analyze viewer**

```bash
cd /Users/macbook/Works/Lecture_Translation_Alex/lecture_viewer_v3 && dart analyze lib/features/lecture_session/presentation/lecture_transcript_pane.dart
```

Expected: **No issues**.

- [ ] **Step 3: Run viewer tests** (if any touch lecture session)

```bash
cd /Users/macbook/Works/Lecture_Translation_Alex/lecture_viewer_v3 && flutter test
```

Expected: **PASS** (or only unrelated failures documented).

- [ ] **Step 4: Commit**

```bash
cd /Users/macbook/Works/Lecture_Translation_Alex/lecture_viewer_v3
git add lib/features/lecture_session/presentation/lecture_transcript_pane.dart
git commit -m "feat(viewer): auto-follow latest transcript with jump FAB"
```

---

### Task 5: Manual QA checklist

**Files:** none (verification only)

- [ ] **Live session** (`LectureSessionScreen`): transcript streams; list stays at bottom by default; scroll up → FAB appears; tap FAB → bottom + FAB hidden; scroll to bottom manually → FAB hides and follow resumes; ~2 lines visible below last line.
- [ ] **Snapshot** (`LectureSnapshotScreen`): open saved transcript; same FAB behavior; change language/module → jumps to bottom with follow on.
- [ ] **Empty states**: no module / waiting / no snapshot text → still shows centered message, **no** FAB.
- [ ] **2-way regression (optional):** open `app_2way_v3` transcript panel — confirm extra bottom padding only (no follow wrapper yet).

---

## Spec coverage (self-review)

| Spec requirement | Task |
|------------------|------|
| 2× bottom padding | Task 1 |
| `TranslationResultTranscriptFollowView` in `lecture_common` | Task 2 |
| FAB small, bottom-right, `keyboard_arrow_down` | Task 2 |
| `followLatest` / scroll threshold 48px | Task 2 |
| `jumpTo` on follow | Task 2 |
| Bucket change resets follow | Task 2 (`didUpdateWidget`) |
| Viewer live + snapshot via `LectureTranscriptPane` | Task 4 |
| Widget tests (FAB, tap, bucket growth) | Task 3 |
| No 2-way toggle changes | Out of scope |
| No SnackBar | Task 2 (none added) |

**Placeholder scan:** none.

---

## Execution handoff

Plan saved to `docs/superpowers/plans/2026-05-19-auto-scroll-viewer-content-implementation-plan.md`.

**Two execution options:**

1. **Subagent-Driven (recommended)** — fresh subagent per task, review between tasks.
2. **Inline Execution** — implement in this session with executing-plans checkpoints.

Which approach do you want?
