import 'package:flutter/foundation.dart';

@immutable
class TtsPcmEvent {
  const TtsPcmEvent({
    required this.url,
    required this.rawSender,
    this.index,
    this.languageFromPayload,
    this.lt2srvSessionId,
    this.text,
    this.minMessageId,
    this.maxMessageId,
  });

  final String url;
  final String rawSender;
  final int? index;
  final String? languageFromPayload;
  final String? lt2srvSessionId;

  /// What this chunk says (KIT's TTS message `text`), if sent.
  final String? text;

  /// Message ids of the text stream this chunk reads (KIT's
  /// `min_message_id` / `max_message_id`), if sent.
  final int? minMessageId;
  final int? maxMessageId;
}
