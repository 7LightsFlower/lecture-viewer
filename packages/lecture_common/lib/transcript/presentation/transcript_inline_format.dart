import 'package:flutter/material.dart';

import '../data/transcript_bucket.dart';
import '../data/transcript_paragraph.dart';
import '../data/transcript_segment.dart';
import '../domain/transcript_display_format.dart';

class TranscriptInlineFormat {
  TranscriptInlineFormat._();

  static double oneLineHeight(TextStyle? style) {
    final fs = style?.fontSize ?? 16;
    final h = style?.height;
    if (h == null || h == 0) return fs * 1.2;
    return fs * h;
  }

  static List<InlineSpan> paragraphInlineSpans({
    required TranscriptBucket activeBucket,
    required TranscriptParagraph paragraph,
    required TextStyle? labelStyle,
    required TextStyle? bodyStyle,
    String? partialText,
    TextStyle? partialStyle,
    int paragraphIndex = 0,
    bool viewerSpeakerLayout = false,
  }) {
    final spans = <InlineSpan>[];
    var lastSegmentTextForGap = '';

    for (final TranscriptSegment segment in paragraph.segments) {
      final labelState =
          activeBucket.speakerLabelByCompoundId[segment.textCompoundId];
      if (labelState?.show == true) {
        if (spans.isNotEmpty) {
          spans.add(
            TextSpan(
              text: viewerSpeakerLayout ? '\n\n' : '\n',
              style: bodyStyle,
            ),
          );
        } else if (viewerSpeakerLayout && paragraphIndex > 0) {
          spans.add(TextSpan(text: '\n', style: bodyStyle));
        }

        spans.add(
          TextSpan(
            text: '${speakerNameForDisplay(
                    labelState!.speakerName,
                    stripHash: viewerSpeakerLayout,
                  )}:',
            style: labelStyle?.copyWith(fontWeight: FontWeight.bold) ??
                const TextStyle(fontWeight: FontWeight.bold),
          ),
        );
        spans.add(TextSpan(text: '\n', style: bodyStyle));
        lastSegmentTextForGap = '';
      }

      final t = stripLeadingSpaceBeforePunctuation(segment.text);
      if (t.isEmpty) continue;

      if (lastSegmentTextForGap.isNotEmpty &&
          needsInsertedSpaceBetween(lastSegmentTextForGap, t)) {
        spans.add(TextSpan(text: ' ', style: bodyStyle));
      }
      spans.add(TextSpan(text: t, style: bodyStyle));
      lastSegmentTextForGap = t;
    }

    final partial = partialText;
    if (partial != null && partial.isNotEmpty) {
      final gapPartial = partialWithGap(
        previousText:
            lastSegmentTextForGap.isEmpty ? null : lastSegmentTextForGap,
        partial: partial,
      );
      spans.add(
        TextSpan(
          text: gapPartial,
          style: partialStyle ?? bodyStyle,
        ),
      );
    }

    return spans;
  }
}
