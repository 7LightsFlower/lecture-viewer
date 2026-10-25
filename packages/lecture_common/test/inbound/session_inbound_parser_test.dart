import 'package:flutter_test/flutter_test.dart';
import 'package:lecture_common/inbound/session_inbound_message.dart';
import 'package:lecture_common/inbound/session_inbound_parse_options.dart';
import 'package:lecture_common/inbound/session_inbound_parser.dart';

void main() {
  test('non-200 int status is server error (twoWay)', () {
    expect(
      parseSessionInbound('{"status":500,"objectType":"texts"}'),
      isA<SessionInboundServerError>(),
    );
  });

  test('non-200 string status is server error (viewer)', () {
    const json = r'''
{"status": "500 - \"<!doctype html>\""}
''';
    expect(
      parseSessionInbound(json, options: SessionInboundParseOptions.viewer),
      isA<SessionInboundServerError>(),
    );
  });

  test('non-200 string status is server error (twoWay)', () {
    expect(
      parseSessionInbound(r'''{"status": "500 - error"}'''),
      isA<SessionInboundServerError>(),
    );
  });

  test('403 is server error when status is not 200', () {
    expect(
      parseSessionInbound(
        '{"status": "403 Forbidden"}',
        options: SessionInboundParseOptions.viewer,
      ),
      isA<SessionInboundServerError>(),
    );
  });

  test('missing status is server error', () {
    expect(
      parseSessionInbound('{"objectType":"texts","data":{"texts":[]}}'),
      isA<SessionInboundServerError>(),
    );
  });

  test('status 200 allows parsing (viewer filters summarizer)', () {
    const json = '''
{"status":200,"objectType":"texts","data":{"texts":[{"text":"x","textId":"1","sender":"S","rawSender":"summarizer:0","senderDetail":{"speakerName":"","isShowSpeakerName":false}}]}}
''';
    expect(
      parseSessionInbound(json, options: SessionInboundParseOptions.viewer),
      isA<SessionInboundIgnored>(),
    );
  });

  test('status 200 allows parsing (twoWay accepts summarizer)', () {
    const json = '''
{"status":200,"objectType":"texts","data":{"texts":[{"text":"x","textId":"1","sender":"S","rawSender":"summarizer:0","senderDetail":{"speakerName":"","isShowSpeakerName":false}}]}}
''';
    final msg = parseSessionInbound(
      json,
      options: SessionInboundParseOptions.twoWay,
    );
    expect(msg, isA<SessionInboundTexts>());
    expect((msg as SessionInboundTexts).events, hasLength(1));
  });

  test('viewer keeps empty isEndParagraph break markers', () {
    const json = '''
{"status":200,"objectType":"texts","data":{"texts":[{"text":"","textId":"0005_mb","sender":"English","rawSender":"mt:1","isFinal":true,"isEndParagraph":true,"senderDetail":{"speakerName":"","isShowSpeakerName":false}}]}}
''';
    final msg = parseSessionInbound(
      json,
      options: SessionInboundParseOptions.viewer,
    );
    expect(msg, isA<SessionInboundTexts>());
    final events = (msg as SessionInboundTexts).events;
    expect(events, hasLength(1));
    expect(events.single.isEndParagraph, isTrue);
    expect(events.single.textId, '0005_mb');
  });
}
