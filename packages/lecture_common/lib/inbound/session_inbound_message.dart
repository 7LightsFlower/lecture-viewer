import 'computed_sender_info.dart';
import 'tts_pcm_event.dart';
import '../transcript/domain/transcript_text_event.dart';

sealed class SessionInboundMessage {
  const SessionInboundMessage();
}

final class SessionInboundInfo extends SessionInboundMessage {
  const SessionInboundInfo({
    required this.activeLanguages,
    required this.computedSenders,
    this.sessionId,
  });

  final List<String> activeLanguages;
  final Map<String, ComputedSenderInfo> computedSenders;
  final String? sessionId;
}

final class SessionInboundTexts extends SessionInboundMessage {
  const SessionInboundTexts(this.events);

  final List<TranscriptTextEvent> events;
}

/// Session finished (`data.status == 'END'`).
final class SessionInboundSessionEnd extends SessionInboundMessage {
  const SessionInboundSessionEnd({this.audioUrl});

  final String? audioUrl;
}

/// WebSocket reports the session is closed (`data.status == 'session_end'`).
final class SessionInboundWsSessionEnd extends SessionInboundMessage {
  const SessionInboundWsSessionEnd({this.reason});

  final String? reason;
}

/// Top-level envelope with `status` present and not equal to `200`.
final class SessionInboundServerError extends SessionInboundMessage {
  const SessionInboundServerError();
}

final class SessionInboundTtsPcm extends SessionInboundMessage {
  const SessionInboundTtsPcm(this.event);

  final TtsPcmEvent event;
}

final class SessionInboundIgnored extends SessionInboundMessage {
  const SessionInboundIgnored();
}
