import 'package:flutter/material.dart';
import 'package:lecture_common/lecture_common.dart';

import 'package:lecture_viewer_v3/features/lecture_session/domain/transcript/lecture_transcript_router.dart';

/// Transcript list with a centered message when the active bucket is empty.
class LectureTranscriptPane extends StatelessWidget {
  const LectureTranscriptPane({
    super.key,
    required this.activeBucket,
    required this.textScaler,
    required this.hasModuleSelection,
    this.followScopeKey,
    this.moduleLabel,
    this.liveSession = true,
    this.highlightedSegmentIds,
  });

  final TranscriptBucket activeBucket;
  final TextScaler textScaler;
  final bool hasModuleSelection;

  /// Stable key for the active transcript bucket (language|module). Used to
  /// reset auto-follow only when the user changes bucket, not on live updates.
  final String? followScopeKey;
  final String? moduleLabel;
  final bool liveSession;

  /// Segments to mark (the text TTS is speaking right now).
  final Set<String>? highlightedSegmentIds;

  @override
  Widget build(BuildContext context) {
    if (!hasModuleSelection) {
      return _EmptyTranscriptMessage(
        message: lectureTranscriptEmptyMessage(
          reason: LectureTranscriptEmptyReason.noModuleSelected,
        ),
      );
    }

    if (!transcriptBucketHasDisplayableContent(activeBucket)) {
      return _EmptyTranscriptMessage(
        message: lectureTranscriptEmptyMessage(
          reason: liveSession
              ? LectureTranscriptEmptyReason.waitingForLiveText
              : LectureTranscriptEmptyReason.noSnapshotText,
          moduleLabel: moduleLabel,
        ),
      );
    }

    return SelectionArea(
      contextMenuBuilder:
        (BuildContext context, SelectableRegionState selectableRegionState) {
          final buttonItems = selectableRegionState.contextMenuButtonItems;
          if (buttonItems.isEmpty) {
            return const SizedBox.shrink();
          }
          return AdaptiveTextSelectionToolbar.buttonItems(
            anchors: selectableRegionState.contextMenuAnchors,
            buttonItems: buttonItems,
          );
        },
      child: TranslationResultTranscriptFollowView(
        textScaler: textScaler,
        activeBucket: activeBucket,
        followScopeKey: followScopeKey,
        viewerSpeakerLayout: true,
        highlightedSegmentIds: highlightedSegmentIds,
      ),
    );
  }
}

enum LectureTranscriptEmptyReason {
  noModuleSelected,
  waitingForLiveText,
  noSnapshotText,
}

String lectureTranscriptEmptyMessage({
  required LectureTranscriptEmptyReason reason,
  String? moduleLabel,
}) {
  final mode = moduleLabel != null && moduleLabel.isNotEmpty
      ? moduleLabel
      : 'this mode';

  return switch (reason) {
    LectureTranscriptEmptyReason.noModuleSelected =>
      'Select a shortening mode above.',
    LectureTranscriptEmptyReason.waitingForLiveText =>
      'Waiting for speech',
    LectureTranscriptEmptyReason.noSnapshotText =>
      'No transcript was saved for $mode.',
  };
}

class _EmptyTranscriptMessage extends StatelessWidget {
  const _EmptyTranscriptMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
