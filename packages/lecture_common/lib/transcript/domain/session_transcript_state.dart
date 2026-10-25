import 'package:flutter/foundation.dart';

import '../data/transcript_bucket.dart';

@immutable
class SessionTranscriptState {
  const SessionTranscriptState({required this.buckets});

  const factory SessionTranscriptState.empty() = SessionTranscriptState._empty;

  const SessionTranscriptState._empty() : buckets = const {};

  final Map<String, TranscriptBucket> buckets;

  SessionTranscriptState applyToBucket({
    required String bucketKey,
    required TranscriptBucket Function(TranscriptBucket bucket) apply,
  }) {
    final previous = buckets[bucketKey] ?? TranscriptBucket.initial();
    final next = apply(previous);
    return SessionTranscriptState(
      buckets: {...buckets, bucketKey: next},
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'buckets': buckets.map((k, v) => MapEntry(k, v.toJson())),
      };

  factory SessionTranscriptState.fromJson(Map<String, dynamic> json) {
    final bucketsRaw = json['buckets'];
    final buckets = <String, TranscriptBucket>{};
    if (bucketsRaw is Map) {
      for (final entry in bucketsRaw.entries) {
        final v = entry.value;
        if (v is Map) {
          buckets[entry.key.toString()] = TranscriptBucket.fromJson(
            Map<String, dynamic>.from(v),
          );
        }
      }
    }
    return SessionTranscriptState(buckets: buckets);
  }
}
