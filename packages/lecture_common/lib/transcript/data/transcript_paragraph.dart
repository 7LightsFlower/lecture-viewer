import 'package:flutter/foundation.dart';

import 'transcript_segment.dart';

@immutable
class TranscriptParagraph {
  const TranscriptParagraph({required this.segments});

  final List<TranscriptSegment> segments;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'segments': segments.map((s) => s.toJson()).toList(),
      };

  factory TranscriptParagraph.fromJson(Map<String, dynamic> json) {
    final raw = json['segments'];
    final list = raw is List
        ? raw
            .whereType<Map>()
            .map(
              (e) => TranscriptSegment.fromJson(Map<String, dynamic>.from(e)),
            )
            .toList()
        : <TranscriptSegment>[];
    return TranscriptParagraph(segments: list);
  }
}
