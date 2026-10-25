import 'package:flutter/foundation.dart';

import 'speaker_label_state.dart';
import 'transcript_paragraph.dart';

@immutable
class TranscriptBucket {
  const TranscriptBucket({
    required this.paragraphs,
    this.partialText,
    required this.speakerLabelByCompoundId,
  });

  factory TranscriptBucket.initial() => const TranscriptBucket(
        paragraphs: <TranscriptParagraph>[],
        partialText: null,
        speakerLabelByCompoundId: <String, SpeakerLabelState>{},
      );

  final List<TranscriptParagraph> paragraphs;
  final String? partialText;
  final Map<String, SpeakerLabelState> speakerLabelByCompoundId;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'paragraphs': paragraphs.map((p) => p.toJson()).toList(),
        'partialText': partialText,
        'speakerLabelByCompoundId': speakerLabelByCompoundId.map(
          (k, v) => MapEntry(k, v.toJson()),
        ),
      };

  factory TranscriptBucket.fromJson(Map<String, dynamic> json) {
    final paraRaw = json['paragraphs'];
    final paragraphs = paraRaw is List
        ? paraRaw
            .whereType<Map>()
            .map(
              (e) => TranscriptParagraph.fromJson(Map<String, dynamic>.from(e)),
            )
            .toList()
        : <TranscriptParagraph>[];

    final labelsRaw = json['speakerLabelByCompoundId'];
    final labels = <String, SpeakerLabelState>{};
    if (labelsRaw is Map) {
      for (final entry in labelsRaw.entries) {
        final v = entry.value;
        if (v is Map) {
          labels[entry.key.toString()] = SpeakerLabelState.fromJson(
            Map<String, dynamic>.from(v),
          );
        }
      }
    }

    return TranscriptBucket(
      paragraphs: paragraphs,
      partialText: json['partialText']?.toString(),
      speakerLabelByCompoundId: labels,
    );
  }
}
