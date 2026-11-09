import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lecture_common/lecture_common.dart';
import 'package:lecture_viewer_v3/features/lecture_session/data/inbound/lecture_inbound_parser.dart';
import 'package:lecture_viewer_v3/features/lecture_session/data/public_lt/public_lt_api.dart';
import 'package:lecture_viewer_v3/features/lecture_session/data/public_lt/public_lt_message_adapter.dart';
import 'package:lecture_viewer_v3/features/lecture_session/data/public_lt/public_lt_session_client.dart';
import 'package:lecture_viewer_v3/features/lecture_session/data/public_lt/sse_event_parser.dart';
import 'package:lecture_viewer_v3/features/lecture_session/data/websocket/lecture_ws_phase.dart';

const _origin = 'https://lt2srv.iar.kit.edu';

PublicLtMessageAdapter _adapter() => PublicLtMessageAdapter(
      apiOrigin: _origin,
      sessionId: '277216',
      senders: {
        'asr:0': PublicLtSender.fromWorker('asr:0', 'English'),
        'mt:1_de': PublicLtSender.fromWorker('mt:1_de', 'German'),
        'tts:2_de': PublicLtSender.fromWorker('tts:2_de', 'German Audio'),
      },
    );

Map<String, dynamic> _seq(
  String sender,
  Object id,
  String seq, {
  bool unstable = false,
  String? speaker,
}) =>
    {
      'session': '277216',
      'sender': sender,
      'start': 1.0,
      'end': 2.5,
      'seq': seq,
      'unstable': unstable,
      'message_id': id,
      if (speaker != null) 'speakerName': speaker,
    };

void main() {
  group('SseEventTransformer', () {
    test('joins data lines, honours event names, skips comments', () async {
      final events = await Stream.fromIterable([
        ': keep-alive',
        'data: {"a":',
        'data: 1}',
        '',
        'event: ping',
        'data:x',
        '',
        'data: tail',
      ]).transform(const SseEventTransformer()).toList();

      expect(events.map((e) => e.event), ['message', 'ping', 'message']);
      expect(events.map((e) => e.data), ['{"a":\n1}', 'x', 'tail']);
    });
  });

  group('PublicLtApi parsing', () {
    test('shorten URL → numeric id and host of the session URL', () {
      final r = PublicLtApi.parseShortenResponse(
        statusCode: 200,
        body: 'https://lt2srv.iar.kit.edu/session/277216/\n',
        fallbackOrigin: 'https://lecture-translator.kit.edu/',
      );
      expect(r?.sessionId, '277216');
      expect(r?.apiOrigin, 'https://lt2srv.iar.kit.edu');
    });

    test('shorten failures → null', () {
      for (final (code, body) in [
        (500, 'https://x/session/1/'),
        (200, 'ERROR: not found'),
        (200, 'https://x/session/abc/'),
        (200, ''),
      ]) {
        expect(
          PublicLtApi.parseShortenResponse(
            statusCode: code,
            body: body,
            fallbackOrigin: _origin,
          ),
          isNull,
          reason: '$code $body',
        );
      }
    });

    test('graph → only components that publish to api', () {
      expect(
        PublicLtApi.outputComponentsFromGraph({
          'asr:0': ['api', 'mt:1_de'],
          'mt:1_de': ['api'],
          'seg:0': ['asr:0'],
        }),
        ['asr:0', 'mt:1_de'],
      );
    });

    test('sender metadata mirrors backend resolveComponentLanguage', () {
      final pp = PublicLtSender.fromWorker('postproduction:50_en', '"English"');
      expect(pp.type, 'postproduction');
      expect(pp.percent, 50);
      expect(pp.langCode, 'en');
      expect(pp.language, 'English');

      final tts = PublicLtSender.fromWorker('tts:2_de', 'German Audio');
      expect(tts.type, 'tts');
      expect(tts.language, 'German');
    });

    test('previous messages: array of JSON strings, bad entries skipped', () {
      final body = jsonEncode([
        jsonEncode({'sender': 'asr:0', 'seq': 'Hi.'}),
        'not json',
        {'sender': 'asr:0', 'seq': 'raw map'},
      ]);
      expect(PublicLtApi.decodePreviousMessages(body).map((m) => m['seq']),
          ['Hi.', 'raw map']);
    });

    test('double encoding matches the backend', () {
      expect(PublicLtApi.doubleEncoded({'component': 'asr:0'}),
          r'"{\"component\":\"asr:0\"}"');
    });
  });

  group('PublicLtMessageAdapter → parseLectureInbound', () {
    test('info envelope parses into languages and senders', () {
      final msg = parseLectureInbound(_adapter().infoEnvelope());
      expect(msg, isA<LectureInboundInfo>());
      final info = msg as LectureInboundInfo;
      expect(info.sessionId, '277216');
      expect(info.activeLanguages, ['English', 'German']);
      expect(info.computedSenders['mt:1_de'],
          const ComputedSenderInfo(
              language: 'German', type: 'mt', percent: 0, langCode: 'de'));
      expect(info.computedSenders['tts:2_de']?.type, 'tts');
    });

    test('stable and unstable text', () {
      final a = _adapter();
      final partial = parseLectureInbound(
        a.adapt(_seq('asr:0', 7, 'hello wor', unstable: true)).single,
      ) as LectureInboundTexts;
      expect(partial.events.single.isFinal, isFalse);
      expect(partial.events.single.text, ' hello wor');
      expect(partial.events.single.textId, '0007');
      expect(partial.events.single.sender, 'English');

      final stable = parseLectureInbound(
        a.adapt(_seq('mt:1_de', 8, 'Hallo Welt.')).single,
      ) as LectureInboundTexts;
      expect(stable.events.single.isFinal, isTrue);
      expect(stable.events.single.rawSender, 'mt:1_de');
      expect(stable.events.single.sender, 'German');
    });

    test('splits a paragraph after ~120 stable chars at a sentence end', () {
      final a = _adapter();
      a.adapt(_seq('asr:0', 1, 'x' * 110));
      final env = a.adapt(_seq('asr:0', 2, 'end here. next one'));
      final events =
          (parseLectureInbound(env.single) as LectureInboundTexts).events;
      expect(events.map((e) => e.textId), ['0002_0', '0002_1']);
      expect(events.map((e) => e.text), [' end here.', 'next one']);
      expect(events.map((e) => e.isEndParagraph), [true, false]);
    });

    test('shows the speaker name when it changes', () {
      final a = _adapter();
      TranscriptTextEvent ev(Map<String, dynamic> raw) =>
          (parseLectureInbound(a.adapt(raw).single) as LectureInboundTexts)
              .events
              .single;
      final first = ev(_seq('asr:0', 1, 'One.', speaker: 's:unk-1'));
      final same = ev(_seq('asr:0', 2, 'Two.', speaker: 's:unk-1'));
      final changed = ev(_seq('asr:0', 3, 'Three.', speaker: 's:Anna'));
      expect(first.senderDetail.isShowSpeakerName, isFalse);
      expect(first.senderDetail.speakerName, 'Unknown 1');
      expect(same.senderDetail.isShowSpeakerName, isFalse);
      expect(changed.senderDetail.isShowSpeakerName, isTrue);
      expect(changed.senderDetail.speakerName, 'Anna');
    });

    test('TTS chunk → raw_pcm with a public /webapi URL', () {
      final a = _adapter();
      final msg = parseLectureInbound(a.adapt({
        'sender': 'tts:2_de',
        'message_id': '12',
        'seq': '',
        'b64_enc_pcm_s16le': 'Data/277216/12',
      }).single);
      expect(msg, isA<LectureInboundTtsPcm>());
      final event = (msg as LectureInboundTtsPcm).event;
      expect(event.url,
          '$_origin/webapi/stream/data?name=Data/277216/12');
      expect(event.index, 12);
      expect(event.languageFromPayload, 'German');
      expect(event.lt2srvSessionId, '277216');

      expect(a.publicTtsUrl('https://u:p@lt2srv.iar.kit.edu/ltapi/stream/data?name=Data/1/2'),
          'https://lt2srv.iar.kit.edu/webapi/stream/data?name=Data/1/2');
      expect(a.adapt({'sender': 'tts:2_de', 'seq': 'TTS-finish'}), isEmpty);
    });

    test('controll END → session end; other control messages ignored', () {
      final a = _adapter();
      expect(a.adapt({'controll': 'INFORMATION', 'sender': 'asr:0'}), isEmpty);
      expect(parseLectureInbound(a.adapt({'controll': 'END'}).single),
          isA<LectureInboundWsSessionEnd>());
      expect(
        parseLectureInbound(
            PublicLtMessageAdapter.serverErrorEnvelope('x')),
        isA<LectureInboundServerError>(),
      );
    });

    test('history is sorted, batched, and skips TTS', () {
      final env = _adapter().adaptHistory([
        {..._seq('asr:0', 2, 'Second.'), 'start': 5.0},
        {..._seq('asr:0', 1, 'First.'), 'start': 1.0},
        {'sender': 'tts:2_de', 'b64_enc_pcm_s16le': 'Data/1/1'},
      ]);
      final events =
          (parseLectureInbound(env.single) as LectureInboundTexts).events;
      expect(events.map((e) => e.text), [' First.', ' Second.']);
    });

    test('adapted texts build a transcript via the real reducer', () {
      final a = _adapter();
      var bucket = TranscriptBucket.initial();
      for (final raw in [
        _seq('asr:0', 1, 'Hello', unstable: true),
        _seq('asr:0', 2, 'Hello world.'),
      ]) {
        for (final env in a.adapt(raw)) {
          final texts = parseLectureInbound(env) as LectureInboundTexts;
          for (final e in texts.events) {
            bucket = applyTranscriptTextEvent(bucket, e);
          }
        }
      }
      expect(bucket.partialText, isNull);
      expect(bucket.paragraphs.single.segments.single.text, ' Hello world.');
    });
  });

  group('PublicLtSessionClient', () {
    test('resolve → info → history → live stream → END', () async {
      final requests = <String>[];
      final mock = MockClient((req) async {
        requests.add('${req.method} ${req.url.path}');
        final p = req.url.path;
        if (p == '/webapi/shorten/foo-lecture') {
          expect(req.url.queryParameters['returnurl'], '1');
          return http.Response('https://lt2srv.iar.kit.edu/session/277216/', 200);
        }
        if (p == '/webapi/277216/getgraph') {
          return http.Response(
            jsonEncode({
              'asr:0': ['api', 'mt:1_de'],
              'mt:1_de': ['api'],
              'seg:0': ['asr:0'],
            }),
            200,
          );
        }
        if (p == '/webapi/277216/0/get_output_language_component') {
          expect(jsonDecode(jsonDecode(req.body) as String),
              {'component': 'asr:0'});
          return http.Response('English', 200);
        }
        if (p == '/webapi/277216/1_de/get_output_language_component') {
          return http.Response('German', 200);
        }
        if (p == '/webapi/277216/get_previous_messages') {
          final component =
              (jsonDecode(jsonDecode(req.body) as String) as Map)['component'];
          if (component != 'asr:0') return http.Response('[]', 200);
          return http.Response(
            jsonEncode([jsonEncode(_seq('asr:0', 1, 'Earlier.'))]),
            200,
          );
        }
        if (p == '/webapi/stream') {
          expect(req.url.queryParameters['channel'], '277216');
          final sse = [
            'data: ${jsonEncode(_seq('asr:0', 2, 'Now.'))}',
            '',
            'data: ${jsonEncode({'controll': 'END', 'session': '277216'})}',
            '',
          ].join('\n');
          return http.Response(sse, 200,
              headers: {'content-type': 'text/event-stream'});
        }
        return http.Response('unexpected $p', 404);
      });

      final received = <LectureInboundMessage>[];
      final client = PublicLtSessionClient(
        meetingName: 'foo-lecture',
        shortenOrigin: 'https://lecture-translator.kit.edu',
        loadHistory: true,
        api: PublicLtApi(httpClient: mock),
        streamClientFactory: () => mock,
        onText: (raw) => received.add(parseLectureInbound(raw)),
      );
      final phases = <LectureWsPhase>[];
      final stopped = Completer<void>();
      client.phase.listen((p) {
        phases.add(p);
        if (p == LectureWsPhase.stopped && !stopped.isCompleted) {
          stopped.complete();
        }
      });

      await client.start();
      await stopped.future.timeout(const Duration(seconds: 5));

      expect(phases, [
        LectureWsPhase.connecting,
        LectureWsPhase.connected,
        LectureWsPhase.stopped,
      ]);
      expect(received[0], isA<LectureInboundInfo>());
      final history = received[1] as LectureInboundTexts;
      expect(history.events.single.text, ' Earlier.');
      final live = received[2] as LectureInboundTexts;
      expect(live.events.single.text, ' Now.');
      expect(received[3], isA<LectureInboundWsSessionEnd>());
      expect(received, hasLength(4));
      expect(requests.where((r) => r.contains('shorten')), hasLength(1));
    });

    test('unknown meeting name → server error, no retries', () async {
      final mock = MockClient((_) async => http.Response('ERROR', 200));
      final received = <LectureInboundMessage>[];
      final client = PublicLtSessionClient(
        meetingName: 'nope',
        shortenOrigin: 'https://lecture-translator.kit.edu',
        api: PublicLtApi(httpClient: mock),
        streamClientFactory: () => mock,
        onText: (raw) => received.add(parseLectureInbound(raw)),
      );
      final stopped = client.phase.firstWhere((p) => p == LectureWsPhase.stopped);
      await client.start();
      await stopped.timeout(const Duration(seconds: 5));
      expect(received.single, isA<LectureInboundServerError>());
    });
  });
}
