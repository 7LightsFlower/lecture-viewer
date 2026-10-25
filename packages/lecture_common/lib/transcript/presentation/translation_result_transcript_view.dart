import 'package:flutter/material.dart';

import '../data/transcript_bucket.dart';
import '../data/transcript_paragraph.dart';
import 'transcript_inline_format.dart';

/// Scrollable transcript with partial text inlined on the last paragraph.
class TranslationResultTranscriptView extends StatelessWidget {
  const TranslationResultTranscriptView({
    super.key,
    required this.textScaler,
    required this.activeBucket,
    this.scrollController,
    this.viewerSpeakerLayout = false,
  });

  final TextScaler textScaler;
  final TranscriptBucket activeBucket;
  final ScrollController? scrollController;
  final bool viewerSpeakerLayout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bodyStyle = theme.textTheme.bodyLarge;
    final labelStyle = bodyStyle?.copyWith(
            fontSize: 17,
          );
    final partialColor = theme.brightness == Brightness.dark
        ? Colors.grey.shade700
        : Colors.grey.shade500;
    final partialStyle = theme.textTheme.bodyLarge?.copyWith(
      color: partialColor,
    );
    final lineHeight = TranscriptInlineFormat.oneLineHeight(bodyStyle);
    final bottomBlankHeight = lineHeight * 2;

    final displayedParagraphs = activeBucket.paragraphs
        .where((TranscriptParagraph p) => p.segments.isNotEmpty)
        .toList();
    final partial = activeBucket.partialText;
    final hasPartial = partial != null && partial.isNotEmpty;
    final itemCount = displayedParagraphs.isEmpty
        ? (hasPartial ? 1 : 0)
        : displayedParagraphs.length;

    return ListView.builder(
      controller: scrollController,
      padding: EdgeInsets.only(bottom: bottomBlankHeight),
      itemCount: itemCount,
      itemBuilder: (BuildContext context, int index) {
        final isLastItem = index == itemCount - 1;
        final paragraph = displayedParagraphs.isEmpty
            ? const TranscriptParagraph(segments: [])
            : displayedParagraphs[index];
        final spans = TranscriptInlineFormat.paragraphInlineSpans(
          activeBucket: activeBucket,
          paragraph: paragraph,
          labelStyle: labelStyle,
          bodyStyle: bodyStyle,
          partialText: isLastItem && hasPartial ? partial : null,
          partialStyle: partialStyle,
          paragraphIndex: index,
          viewerSpeakerLayout: viewerSpeakerLayout,
        );
        return Padding(
          key: ValueKey<String>('p-$index'),
          padding: const EdgeInsets.only(bottom: 8),
          child: Text.rich(
            TextSpan(children: spans),
            textScaler: textScaler,
          ),
        );
      },
    );
  }
}
