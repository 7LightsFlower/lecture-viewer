import 'package:lecture_common/lecture_common.dart';

bool bucketHasShareableContent(TranscriptBucket bucket) {
  final partial = bucket.partialText;
  if (partial != null && partial.trim().isNotEmpty) return true;
  for (final p in bucket.paragraphs) {
    if (p.segments.any((s) => s.text.isNotEmpty)) return true;
  }
  return false;
}

String formatTranscriptBucketForShare(TranscriptBucket bucket) {
  final buf = StringBuffer();
  final displayed = bucket.paragraphs
      .where((TranscriptParagraph p) => p.segments.isNotEmpty)
      .toList();

  for (var pi = 0; pi < displayed.length; pi++) {
    if (pi > 0) buf.write('\n\n');
    buf.write(_formatParagraph(bucket, displayed[pi]));
  }

  final partial = bucket.partialText;
  if (partial != null && partial.isNotEmpty) {
    if (buf.isNotEmpty) buf.write('\n');
    buf.write(
      partialWithGap(
        previousText: lastFinalizedSegmentTextFromBucket(bucket),
        partial: partial,
      ),
    );
  }

  return buf.toString();
}

String _formatParagraph(TranscriptBucket bucket, TranscriptParagraph paragraph) {
  final buf = StringBuffer();
  var lastSegmentText = '';

  for (final TranscriptSegment segment in paragraph.segments) {
    final label = bucket.speakerLabelByCompoundId[segment.textCompoundId];
    if (label?.show == true) {
      if (buf.isNotEmpty) buf.write('\n');
      buf.write(label!.speakerName);
      buf.write('\n');
      lastSegmentText = '';
    }

    final t = segment.text;
    if (t.isEmpty) continue;

    if (lastSegmentText.isNotEmpty &&
        needsInsertedSpaceBetween(lastSegmentText, t)) {
      buf.write(' ');
    }
    buf.write(t);
    lastSegmentText = t;
  }
  return buf.toString();
}
