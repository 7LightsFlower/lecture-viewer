import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lecture_common/inbound/inbound_json.dart';
import 'package:lecture_common/inbound/inbound_texts_parser.dart';

void main() {
  test('parseInboundTextsPayload returns events for valid texts envelope', () {
    const json = '''
{"message":"","status":200,"data":{"texts":[{"text":" Hello","isFinal":false,"textId":"0010","sender":"English","rawSender":"mt:1","senderDetail":{"speakerName":"Unknown 0","isShowSpeakerName":false},"isEndParagraph":false}]},"objectType":"texts"}
''';
    final decoded = decodeInboundJsonMap(json)!;
    final events = parseInboundTextsPayload(decoded);
    expect(events, isNotNull);
    expect(events!, hasLength(1));
    expect(events.single.text, ' Hello');
    expect(events.single.textId, '0010');
    expect(events.single.rawSender, 'mt:1');
  });

  test('returns null when texts array empty', () {
    final decoded = jsonDecode('{"objectType":"texts","data":{"texts":[]}}')
        as Map<String, dynamic>;
    expect(parseInboundTextsPayload(decoded), isNull);
  });

  test('permissive: includes unsupported module types', () {
    final decoded = jsonDecode(
      '{"objectType":"texts","data":{"texts":[{"text":"x","textId":"1","sender":"S","rawSender":"summarizer:0","senderDetail":{}}]}}',
    ) as Map<String, dynamic>;
    final events = parseInboundTextsPayload(decoded);
    expect(events, hasLength(1));
    expect(events!.single.rawSender, 'summarizer:0');
  });

  test('permissive: includes empty trimmed text', () {
    final decoded = jsonDecode(
      '{"objectType":"texts","data":{"texts":[{"text":"   ","textId":"1","sender":"S","rawSender":"mt:0","senderDetail":{}}]}}',
    ) as Map<String, dynamic>;
    final events = parseInboundTextsPayload(decoded);
    expect(events, hasLength(1));
  });

  test('coerces numeric textId', () {
    final decoded = jsonDecode(
      '{"objectType":"texts","data":{"texts":[{"text":"hi","textId":42,"sender":"S","rawSender":"mt:0","senderDetail":{}}]}}',
    ) as Map<String, dynamic>;
    expect(parseInboundTextsPayload(decoded)!.single.textId, '42');
  });
}
