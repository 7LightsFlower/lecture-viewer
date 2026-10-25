import 'computed_sender_info.dart';
import 'session_inbound_message.dart';
import 'session_inbound_parse_options.dart';

SessionInboundMessage parseInboundInfoPayload(
  Map<String, dynamic> decoded, {
  SessionInboundParseOptions options = SessionInboundParseOptions.twoWay,
}) {
  final data = decoded['data'];
  if (data is! Map<String, dynamic>) return const SessionInboundIgnored();

  if (data['status'] == 'session_end') {
    return SessionInboundWsSessionEnd(
      reason: data['reason']?.toString(),
    );
  }

  if (data['status'] == 'END') {
    return SessionInboundSessionEnd(
      audioUrl: data['audioUrl']?.toString(),
    );
  }

  final langsRaw = data['activeLanguages'];
  final activeLanguages = langsRaw is List
      ? langsRaw.map((e) => e.toString()).where((s) => s.isNotEmpty).toList()
      : <String>[];

  final sendersRaw = data['computedSenders'];
  final computedSenders = <String, ComputedSenderInfo>{};
  final shouldStore = options.shouldStoreSenderType ?? (_) => true;

  if (sendersRaw is Map) {
    for (final entry in sendersRaw.entries) {
      final v = entry.value;
      if (v is! Map) continue;
      final language = v['language']?.toString() ?? '';
      final type = v['type']?.toString() ?? '';
      if (language.isEmpty || type.isEmpty || !shouldStore(type)) {
        continue;
      }
      final percentRaw = v['percent'];
      final percent = percentRaw is int
          ? percentRaw
          : int.tryParse('$percentRaw') ?? 0;
      computedSenders[entry.key.toString()] = ComputedSenderInfo(
        language: language,
        type: type,
        percent: percent,
        langCode: v['langCode']?.toString(),
      );
    }
  }

  return SessionInboundInfo(
    activeLanguages: activeLanguages,
    computedSenders: computedSenders,
    sessionId: data['sessionID']?.toString(),
  );
}
