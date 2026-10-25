import 'lt2srv_pcm_url.dart';
import 'tts_pcm_event.dart';

TtsPcmEvent? parseInboundRawPcmPayload(Map<String, dynamic> decoded) {
  final data = decoded['data'];
  if (data is! Map<String, dynamic>) return null;
  final url = data['url'];
  final rawSender = data['rawSender'];
  if (url is! String || url.isEmpty) return null;
  if (rawSender is! String || !rawSender.startsWith('tts:')) return null;

  String? lang;
  final sd = data['senderDetail'];
  if (sd is Map<String, dynamic>) {
    final l = sd['language'];
    if (l is String && l.isNotEmpty) lang = l;
  }
  lang ??= switch (data['language']) {
    final String s when s.isNotEmpty => s,
    _ => null,
  };

  return TtsPcmEvent(
    url: url,
    rawSender: rawSender,
    index: data['index'] is int ? data['index'] as int : null,
    languageFromPayload: lang,
    lt2srvSessionId: parseLt2srvSessionIdFromPcmUrl(url),
  );
}
