import 'package:flutter/foundation.dart';

@immutable
class TtsPcmEvent {
  const TtsPcmEvent({
    required this.url,
    required this.rawSender,
    this.index,
    this.languageFromPayload,
    this.lt2srvSessionId,
  });

  final String url;
  final String rawSender;
  final int? index;
  final String? languageFromPayload;
  final String? lt2srvSessionId;
}
