import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lecture_common/inbound/inbound_info_parser.dart';
import 'package:lecture_common/inbound/session_inbound_message.dart';
import 'package:lecture_common/inbound/session_inbound_parse_options.dart';

void main() {
  test('parses language metadata info', () {
    const json = '''
{
  "status": 200,
  "objectType": "info",
  "data": {
    "sessionID": "317374",
    "activeLanguages": ["English", "German"],
    "computedSenders": {
      "asr:0": {"language": "Transcript", "type": "asr", "percent": 0},
      "mt:0": {"language": "English", "type": "mt", "percent": 0}
    }
  }
}
''';
    final decoded = jsonDecode(json) as Map<String, dynamic>;
    final message = parseInboundInfoPayload(
      decoded,
      options: SessionInboundParseOptions.viewer,
    );
    expect(message, isA<SessionInboundInfo>());
    final info = message as SessionInboundInfo;
    expect(info.activeLanguages, ['English', 'German']);
    expect(info.computedSenders.length, 2);
    expect(info.sessionId, '317374');
  });

  test('viewer options keep tts senders for PCM routing', () {
    final decoded = jsonDecode('''
{
  "objectType": "info",
  "data": {
    "activeLanguages": ["English", "German"],
    "computedSenders": {
      "tts:0": {"language": "English", "type": "tts", "percent": 0},
      "mt:0": {"language": "English", "type": "mt", "percent": 0}
    }
  }
}
''') as Map<String, dynamic>;
    final info = parseInboundInfoPayload(
      decoded,
      options: SessionInboundParseOptions.viewer,
    ) as SessionInboundInfo;
    expect(info.computedSenders.keys, containsAll(['tts:0', 'mt:0']));
  });

  test('viewer options omit unsupported module types from computedSenders', () {
    final decoded = jsonDecode('''
{
  "objectType": "info",
  "data": {
    "activeLanguages": ["English"],
    "computedSenders": {
      "mt:0": {"language": "English", "type": "mt", "percent": 0},
      "textstructurer:0_en": {"language": "English", "type": "textstructurer", "percent": 0},
      "summarizer:0_en": {"language": "English", "type": "summarizer", "percent": 0}
    }
  }
}
''') as Map<String, dynamic>;
    final info = parseInboundInfoPayload(
      decoded,
      options: SessionInboundParseOptions.viewer,
    ) as SessionInboundInfo;
    expect(info.computedSenders.keys, ['mt:0']);
  });

  test('twoWay options store all sender types', () {
    final decoded = jsonDecode('''
{
  "objectType": "info",
  "data": {
    "computedSenders": {
      "summarizer:0": {"language": "English", "type": "summarizer", "percent": 0}
    }
  }
}
''') as Map<String, dynamic>;
    final info = parseInboundInfoPayload(decoded) as SessionInboundInfo;
    expect(info.computedSenders.keys, ['summarizer:0']);
  });

  test('parses session_end', () {
    final decoded = jsonDecode('''
{
  "objectType": "info",
  "data": {"status": "session_end", "reason": "session_already_over"}
}
''') as Map<String, dynamic>;
    final message = parseInboundInfoPayload(decoded);
    expect(message, isA<SessionInboundWsSessionEnd>());
    expect((message as SessionInboundWsSessionEnd).reason, 'session_already_over');
  });

  test('parses END with audioUrl', () {
    final decoded = jsonDecode('''
{
  "objectType": "info",
  "data": {"status": "END", "audioUrl": "https://example.com/recording.wav"}
}
''') as Map<String, dynamic>;
    final message = parseInboundInfoPayload(decoded);
    expect(message, isA<SessionInboundSessionEnd>());
    expect(
      (message as SessionInboundSessionEnd).audioUrl,
      'https://example.com/recording.wav',
    );
  });
}
