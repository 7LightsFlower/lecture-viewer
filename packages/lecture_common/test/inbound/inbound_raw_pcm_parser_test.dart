import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lecture_common/inbound/inbound_raw_pcm_parser.dart';

void main() {
  test('parses raw_pcm with language and index', () {
    final decoded = jsonDecode('''
{"objectType":"raw_pcm","data":{"index":4,"language":"German","rawSender":"tts:0","url":"https://example.com/pcm"}}
''') as Map<String, dynamic>;
    final event = parseInboundRawPcmPayload(decoded);
    expect(event, isNotNull);
    expect(event!.url, 'https://example.com/pcm');
    expect(event.rawSender, 'tts:0');
    expect(event.index, 4);
    expect(event.languageFromPayload, 'German');
  });

  test('parses lt2srv session id from stream url', () {
    final decoded = jsonDecode('''
{"objectType":"raw_pcm","data":{"url":"https://lt2srv.iar.kit.edu/ltapi/stream/data?name=Data/317221/1","rawSender":"tts:0","language":"German"}}
''') as Map<String, dynamic>;
    expect(parseInboundRawPcmPayload(decoded)!.lt2srvSessionId, '317221');
  });

  test('returns null for non-tts rawSender', () {
    final decoded = jsonDecode(
      '{"objectType":"raw_pcm","data":{"url":"https://x","rawSender":"mt:1"}}',
    ) as Map<String, dynamic>;
    expect(parseInboundRawPcmPayload(decoded), isNull);
  });
}
