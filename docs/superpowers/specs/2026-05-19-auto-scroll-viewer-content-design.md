# Auto-scroll transcript (viewer) — Design Spec

**Date:** 2026-05-19  
**Project:** `lecture_viewer_v3` (+ shared widget in `lecture_common`)  
**Status:** Approved in brainstorming  
**Source note:** `docs/4-auto-scroll-viewer-content.md`

## Goal

When viewing a transcript in the lecture viewer, **follow the latest text** by default (scroll to bottom as content grows). If the user scrolls up to read earlier text, **stop following** and show a **small FAB** to jump back to the latest text and re-enable follow mode.

Same behavior on **live session** and **offline snapshot** screens. Implement in viewer first; expose a stable wrapper in `lecture_common` so `app_2way_v3` can adopt later without changing `TranslationResultTranscriptView` rendering API.

## References

- **Transcript list (render only):** `lecture_common/lib/transcript/presentation/translation_result_transcript_view.dart`
- **Viewer live:** `lecture_viewer_v3/lib/features/lecture_session/presentation/lecture_session_screen.dart` → `LectureTranscriptPane`
- **Viewer snapshot:** `lecture_viewer_v3/lib/features/lecture_session/presentation/lecture_snapshot_screen.dart` → `LectureTranscriptPane` (`liveSession: false`)
- **2way auto-scroll (toggle + listen, no scroll-position UX):** `app_2way_v3/lib/features/translation_session/ui/translation_screen.dart`

## Brainstorming decisions

| Topic | Decision |
|-------|----------|
| Scope (apps) | **Viewer first**; shared API in `lecture_common` for 2-way later (**C**) |
| Screens | **Live + snapshot**; snapshot also follows on bucket/content change (**C**) |
| Jump button | **Small FAB**, bottom-right of transcript area, `Icons.keyboard_arrow_down` (**A**) |
| Bottom spacing | **~2 lines** of empty space after last text (shared list padding) |
| Implementation shape | **Wrapper widget** in `lecture_common` (not logic inside render-only view) |
| Scroll animation | **`jumpTo`** on follow (match 2-way live session; avoids jank during streaming partials) |
| User feedback on toggle | **No SnackBar** — FAB visibility is the affordance |

### Approaches considered

| Approach | Verdict |
|----------|---------|
| **1. `TranslationResultTranscriptFollowView` wrapper in `lecture_common`** | **Chosen** |
| 2. Logic only in `lecture_viewer_v3` (`LectureTranscriptPane`) | Rejected — duplicates logic; blocks 2-way reuse |
| 3. Extend `TranslationResultTranscriptView` with follow/FAB | Rejected — mixes render and interaction |

## Goals and non-goals

**Goals**

- Default: user sees the **latest** transcript text (bottom of list).
- While following: on transcript updates (new paragraphs, partial text growth, bucket switch), scroll to bottom after layout.
- User scrolls up: disable follow, show FAB.
- User scrolls to near bottom or taps FAB: enable follow, scroll to bottom, hide FAB.
- Bucket change (language/module switch, snapshot load): reset to **follow latest** and scroll to bottom.
- Widget tests in `lecture_common` for core follow/FAB behavior.
- **~2 lines** of trailing space below the last paragraph so the final text is not flush against the FAB / viewport edge.

**Non-goals**

- Changing `app_2way_v3` middle-strip auto-scroll toggle in v1.
- Animated scroll (`animateTo`) for follow updates.
- Persisting follow preference across sessions.
- Auto-scroll on empty-state placeholders (`_EmptyTranscriptMessage`).

## Behavior specification

### State: `followLatest`

- Internal boolean on the follow wrapper’s `State`.
- **`true`:** transcript updates trigger scroll-to-bottom after frame; FAB hidden.
- **`false`:** updates do not scroll; FAB shown when list is scrollable and user is not at bottom.

### Events

| Event | Action |
|-------|--------|
| First build with displayable content | `followLatest = true`, post-frame scroll to bottom |
| `activeBucket` identity/content update while `followLatest` | Post-frame `jumpTo(maxScrollExtent)` |
| `activeBucket` replaced (e.g. language/module switch) | `followLatest = true`, post-frame scroll to bottom |
| Scroll position **near bottom** (within threshold) | `followLatest = true`, hide FAB |
| Scroll position **away from bottom** (user scrolled up) | `followLatest = false`, show FAB (if scrollable) |
| FAB pressed | `followLatest = true`, `jumpTo` bottom, hide FAB |

### “Near bottom” threshold

- Constant: **`kTranscriptFollowBottomThreshold = 48.0`** (logical pixels).
- Condition: `position.maxScrollExtent - position.pixels <= kTranscriptFollowBottomThreshold`.
- Only evaluate when `position.hasContentDimensions` and `maxScrollExtent > 0`.

### Scrollable check for FAB

- Show FAB only when `!followLatest` **and** `maxScrollExtent > threshold` (content taller than viewport).

### Snapshot vs live

| Mode | Content updates | Follow behavior |
|------|-----------------|-----------------|
| Live | Streaming partials + new segments | Follow while `followLatest`; same jump rules |
| Snapshot | Static text unless language/module changes | Follow on bucket change; no stream ticks between changes |

## Architecture

```text
lecture_common/
  lib/transcript/presentation/
    translation_result_transcript_view.dart      # unchanged render API
    translation_result_transcript_follow_view.dart  # NEW

lecture_viewer_v3/
  lib/features/lecture_session/presentation/
    lecture_transcript_pane.dart                 # use FollowView when content present
```

### `TranslationResultTranscriptFollowView` (new, `lecture_common`)

```dart
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
}
```

**Responsibilities**

- Own `ScrollController` (dispose in `State.dispose`).
- `Stack`:
  - Child: `TranslationResultTranscriptView(scrollController: _controller, ...)`.
  - Overlay: `Positioned(right: 12, bottom: 12)` → `FloatingActionButton.small` when FAB visible.
- `ScrollController` listener (or `NotificationListener<ScrollNotification>`) to update `followLatest` from scroll position.
- `didUpdateWidget`: detect `activeBucket` changes; on bucket change reset `followLatest = true`; if `followLatest`, schedule scroll after frame.
- Private `_scrollToBottom()`: if `hasClients`, `jumpTo(position.maxScrollExtent)`.

**Export:** add to `lecture_common.dart` barrel export.

### `TranslationResultTranscriptView` (small padding change)

- Stays a `StatelessWidget` for list rendering.
- Optional external `scrollController` remains for tests and future 2-way panels.
- **Bottom padding:** increase `ListView` `padding.bottom` from **1×** to **2×** `TranscriptInlineFormat.oneLineHeight(bodyStyle)` so the last line sits ~two body lines above the scroll end (applies to viewer, 2-way, and follow wrapper alike).

### `LectureTranscriptPane` (viewer)

- When `transcriptBucketHasDisplayableContent(activeBucket)`:
  - Replace `TranslationResultTranscriptView` with `TranslationResultTranscriptFollowView` (same `textScaler`, `activeBucket`).
- Empty states unchanged.

### Future: `app_2way_v3`

- Wrap existing `TranslationResultTranscriptView` call sites with `TranslationResultTranscriptFollowView`.
- Optionally remove middle-strip manual toggle once parity is validated (out of v1 scope).

## UI

### Trailing blank space

- **`TranslationResultTranscriptView`:** `padding: EdgeInsets.only(bottom: 2 * oneLineHeight(bodyStyle))` (today: `1 *`; use `bodyLarge` from theme, same as list body).
- Scroll-to-bottom (`maxScrollExtent`) includes this padding so “latest” still shows the last line with breathing room above the FAB.
- No extra spacer `item` in the list — padding only, to avoid duplicate gaps on rebuild.

### FAB

- **FAB:** `FloatingActionButton.small`, icon `keyboard_arrow_down` (overridable via `scrollToBottomIcon`).
- **Position:** `right: 12`, `bottom: 12` inside transcript `Stack` (above list, inside pane padding from parent).
- **Theme:** inherit `Theme.of(context)` / `colorScheme` from parent `MaterialApp` (no custom colors in v1).
- **Accessibility:** `tooltip: 'Scroll to latest'` (English; matches existing viewer string style).

## Data flow (live session)

```text
lectureSessionProvider → activeBucket
  → LectureTranscriptPane
  → TranslationResultTranscriptFollowView
       ├─ followLatest + scroll listener
       └─ TranslationResultTranscriptView ← activeBucket updates
```

On each bucket update from WebSocket reducer, follow wrapper schedules bottom scroll if `followLatest`.

## Testing (`lecture_common`)

| Test | Assertion |
|------|-----------|
| Growing bucket with follow on | After pump + post-frame, scroll offset near `maxScrollExtent` |
| Programmatic scroll up | FAB visible |
| Tap FAB | FAB hidden; offset near bottom |
| Bucket swap | Follow re-enabled; scroll near bottom |

Use fixed-height `SizedBox` host (same pattern as `translation_result_transcript_view_test.dart`).

## Risks and mitigations

| Risk | Mitigation |
|------|------------|
| Partial text updates every frame cause scroll jank | `jumpTo` only when `followLatest`; no animation |
| FAB overlaps last line | **2× line-height** bottom padding + FAB inset (`right/bottom: 12`) |
| False “at bottom” during layout | Scroll only in post-frame callback; guard `hasClients` |
| Bucket equality | Compare `activeBucket` in `didUpdateWidget` (reference or shallow content fingerprint if needed) |

## Implementation checklist (for plan)

1. Bump `TranslationResultTranscriptView` bottom padding to **2×** line height.
2. Add `translation_result_transcript_follow_view.dart` + export in `lecture_common`.
3. Widget tests in `lecture_common/test/transcript/`.
4. Wire `LectureTranscriptPane` to follow view.
5. Manual QA: live stream, scroll up/down, FAB, language/module switch; snapshot load and picker change; confirm ~2 lines visible below last line at bottom.
