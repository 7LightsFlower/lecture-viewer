import 'package:flutter/foundation.dart';

@immutable
class TranscriptSenderDetail {
  const TranscriptSenderDetail({
    required this.speakerName,
    required this.isShowSpeakerName,
  });

  final String speakerName;
  final bool isShowSpeakerName;
}
