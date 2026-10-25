import '../data/transcript_bucket.dart';

/// Leading spaces/tabs immediately before closing/sentence punctuation.
final _leadingSpaceBeforePunct = RegExp(r'^[ \t]*([.,?!:;)\]])');

final _startsWithPunct = RegExp(r'^[.,?!:;)\]]');

String speakerNameForDisplay(String raw, {required bool stripHash}) {
  return stripHash ? raw.replaceAll('#', '') : raw;
}

/// `" , which"` / `"\t)"` → `", which"` / `")"`.
String stripLeadingSpaceBeforePunctuation(String text) {
  return text.replaceFirstMapped(
    _leadingSpaceBeforePunct,
    (m) => m[1]!,
  );
}

bool needsInsertedSpaceBetween(String a, String b) {
  if (a.isEmpty || b.isEmpty) return false;
  final normalizedB = stripLeadingSpaceBeforePunctuation(b);
  if (_startsWithPunct.hasMatch(normalizedB)) return false;
  final aEndsWithWs = RegExp(r'\s$').hasMatch(a);
  final bStartsWithWs = RegExp(r'^\s').hasMatch(normalizedB);
  return !aEndsWithWs && !bStartsWithWs;
}

String partialWithGap({required String? previousText, required String partial}) {
  final normalized = stripLeadingSpaceBeforePunctuation(partial);
  if (previousText != null &&
      needsInsertedSpaceBetween(previousText, normalized)) {
    return ' $normalized';
  }
  return normalized;
}

String? lastFinalizedSegmentTextFromBucket(TranscriptBucket bucket) {
  for (var pi = bucket.paragraphs.length - 1; pi >= 0; pi--) {
    final segs = bucket.paragraphs[pi].segments;
    if (segs.isEmpty) continue;
    return segs.last.text;
  }
  return null;
}
