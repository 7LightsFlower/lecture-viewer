import 'package:flutter/foundation.dart';

@immutable
class TranscriptSegment {
  const TranscriptSegment({
    required this.text,
    required this.textCompoundId,
  });

  final String text;
  final String textCompoundId;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'text': text,
        'textCompoundId': textCompoundId,
      };

  factory TranscriptSegment.fromJson(Map<String, dynamic> json) {
    return TranscriptSegment(
      text: json['text']?.toString() ?? '',
      textCompoundId: json['textCompoundId']?.toString() ?? '',
    );
  }
}
