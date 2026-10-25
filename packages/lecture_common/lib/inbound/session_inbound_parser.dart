import 'inbound_info_parser.dart';
import 'inbound_json.dart';
import 'inbound_raw_pcm_parser.dart';
import 'inbound_texts_parser.dart';
import 'session_inbound_message.dart';
import 'session_inbound_parse_options.dart';

SessionInboundMessage parseSessionInbound(
  String raw, {
  SessionInboundParseOptions options = SessionInboundParseOptions.twoWay,
}) {
  final decoded = decodeInboundJsonMap(raw);
  if (decoded == null) return const SessionInboundIgnored();

  // Success envelopes use top-level `"status": 200` (int). Anything else is an error.
  if (decoded['status'] != 200) {
    return const SessionInboundServerError();
  }

  try {
    return switch (decoded['objectType']) {
      'info' => parseInboundInfoPayload(decoded, options: options),
      'texts' => () {
        final parsed = parseInboundTextsPayload(decoded);
        if (parsed == null) return const SessionInboundIgnored();
        final events = options.filterTexts?.call(parsed) ?? parsed;
        if (events.isEmpty) return const SessionInboundIgnored();
        return SessionInboundTexts(events);
      }(),
      'raw_pcm' => () {
        final event = parseInboundRawPcmPayload(decoded);
        if (event == null) return const SessionInboundIgnored();
        return SessionInboundTtsPcm(event);
      }(),
      _ => const SessionInboundIgnored(),
    };
  } catch (_) {
    return const SessionInboundIgnored();
  }
}
