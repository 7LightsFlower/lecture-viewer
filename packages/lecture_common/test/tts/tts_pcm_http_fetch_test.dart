import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lecture_common/tts/domain/tts_pcm_base64_payload.dart';
import 'package:lecture_common/tts/domain/tts_pcm_http_fetch.dart';

void main() {
  final uri = Uri.parse(
    'https://user:secret@lt2srv.example/ltapi/stream/data?name=Data/1/2',
  );

  test('publicTtsPcmUri drops the login and uses /webapi', () {
    expect(
      publicTtsPcmUri(uri).toString(),
      'https://lt2srv.example/webapi/stream/data?name=Data/1/2',
    );
    final already = Uri.parse('https://lt2srv.example/webapi/stream/data?name=x');
    expect(publicTtsPcmUri(already), already);
  });

  test('usePublicRoute requests the public URL', () async {
    Uri? requested;
    final client = MockClient((request) async {
      requested = request.url;
      return http.Response('"AQID"', 200);
    });
    await fetchTtsPcmChunk(
      uri,
      client: client,
      isCancelled: () => false,
      usePublicRoute: true,
      firstAttemptDelay: Duration.zero,
    );
    expect(requested.toString(),
        'https://lt2srv.example/webapi/stream/data?name=Data/1/2');
    expect(requested!.userInfo, isEmpty);
  });

  test('data: URI is answered without a request', () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      return http.Response('', 500);
    });
    final res = await fetchTtsPcmChunk(
      Uri.parse('data:audio/pcm;base64,AQID'),
      client: client,
      isCancelled: () => false,
      firstAttemptDelay: Duration.zero,
    );
    expect(calls, 0);
    expect(res?.bodyBytes, [1, 2, 3]);
  });

  group('decodeTtsPcmResponseBody', () {
    Uint8List bytes(String s) => Uint8List.fromList(utf8.encode(s));

    test('quoted base64 string', () {
      expect(
        decodeTtsPcmResponseBody(
            contentType: 'application/json', bodyBytes: bytes('"AQID"')),
        [1, 2, 3],
      );
    });

    test('JSON object with b64_enc_pcm_s16le', () {
      expect(
        decodeTtsPcmResponseBody(
          contentType: 'application/json',
          bodyBytes: bytes('{"b64_enc_pcm_s16le":"AQID","sample_rate":16000}'),
        ),
        [1, 2, 3],
      );
    });

    test('data: prefix and unpadded base64', () {
      expect(
        decodeTtsPcmResponseBody(
            contentType: null, bodyBytes: bytes('data:audio/pcm;base64,AQIDBA')),
        [1, 2, 3, 4],
      );
    });

    test('raw PCM bytes', () {
      final raw = Uint8List.fromList([0xff, 0xfe, 0x00, 0x80]);
      expect(decodeTtsPcmResponseBody(contentType: 'audio/L16', bodyBytes: raw),
          raw);
      expect(decodeTtsPcmResponseBody(contentType: null, bodyBytes: raw), raw);
    });
  });

  test('succeeds on first 200 response', () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      return http.Response('pcm-body', 200);
    });

    final res = await fetchTtsPcmChunk(
      uri,
      client: client,
      isCancelled: () => false,
      firstAttemptDelay: Duration.zero,
    );

    expect(res?.statusCode, 200);
    expect(res?.body, 'pcm-body');
    expect(calls, 1);
    client.close();
  });

  test('retries ClientException then succeeds on third attempt', () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      if (calls < 3) {
        throw http.ClientException(
          'Connection closed while receiving data',
        );
      }
      return http.Response('ok', 200);
    });

    final res = await fetchTtsPcmChunk(
      uri,
      client: client,
      isCancelled: () => false,
      firstAttemptDelay: Duration.zero,
      retryDelays: const [Duration.zero, Duration.zero],
    );

    expect(res?.statusCode, 200);
    expect(calls, 3);
    client.close();
  });

  test('returns null after exhausting retriable failures', () async {
    final client = MockClient((request) async {
      throw http.ClientException('Connection closed');
    });

    final res = await fetchTtsPcmChunk(
      uri,
      client: client,
      isCancelled: () => false,
      firstAttemptDelay: Duration.zero,
      retryDelays: const [Duration.zero, Duration.zero],
    );

    expect(res, isNull);
    client.close();
  });

  test('returns null immediately when cancelled before fetch', () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      return http.Response('x', 200);
    });

    final res = await fetchTtsPcmChunk(
      uri,
      client: client,
      isCancelled: () => true,
      firstAttemptDelay: Duration.zero,
    );

    expect(res, isNull);
    expect(calls, 0);
    client.close();
  });

  test('returns null when cancelled between attempts', () async {
    var calls = 0;
    var cancelled = false;
    final client = MockClient((request) async {
      calls++;
      cancelled = true;
      throw http.ClientException('closed');
    });

    final res = await fetchTtsPcmChunk(
      uri,
      client: client,
      isCancelled: () => cancelled,
      firstAttemptDelay: Duration.zero,
      retryDelays: const [Duration.zero, Duration.zero],
    );

    expect(res, isNull);
    expect(calls, 1);
    client.close();
  });

  test('retries SocketException', () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      if (calls == 1) throw const SocketException('reset');
      return http.Response('ok', 200);
    });

    final res = await fetchTtsPcmChunk(
      uri,
      client: client,
      isCancelled: () => false,
      firstAttemptDelay: Duration.zero,
      retryDelays: const [Duration.zero],
      maxAttempts: 2,
    );

    expect(res?.statusCode, 200);
    expect(calls, 2);
    client.close();
  });

  test('returns null on non-200 without retry', () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      return http.Response('missing', 404);
    });

    final res = await fetchTtsPcmChunk(
      uri,
      client: client,
      isCancelled: () => false,
      firstAttemptDelay: Duration.zero,
    );

    expect(res, isNull);
    expect(calls, 1);
    client.close();
  });

  test('ttsPcmUriForLog strips userinfo', () {
    final logged = ttsPcmUriForLog(uri);
    expect(logged, contains('lt2srv.example'));
    expect(logged, isNot(contains('secret')));
    expect(logged, isNot(contains('user:')));
  });
}
