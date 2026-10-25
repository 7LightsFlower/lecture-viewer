import 'package:flutter/foundation.dart';

import 'transcript_sender_detail.dart';

@immutable
class TranscriptTextEvent {
  const TranscriptTextEvent({
    required this.text,
    required this.isFinal,
    required this.textId,
    required this.sender,
    required this.rawSender,
    required this.isEndParagraph,
    required this.senderDetail,
  });

  final String text;
  final bool isFinal;
  final String textId;
  final String sender;
  final String rawSender;
  final bool isEndParagraph;
  final TranscriptSenderDetail senderDetail;
}
