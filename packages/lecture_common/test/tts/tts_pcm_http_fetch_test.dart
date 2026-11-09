import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lecture_common/tts/domain/tts_pcm_http_fetch.dart';

void main() {
  final uri = Uri.parse(
    'https://user:secret@lt2srv.example/ltapi/stream/data?name=Data/1/2',
  );

  test('ttsPcmRequestParts moves credentials into a Basic header', () {
    final parts = ttsPcmRequestParts(uri);
    expect(parts.uri.toString(),
        'https://lt2srv.example/ltapi/stream/data?name=Data/1/2');
    expect(parts.headers['authorization'], 'Basic dXNlcjpzZWNyZXQ=');

    final plain = Uri.parse('https://lt2srv.example/webapi/stream/data?name=x');
    final noCreds = ttsPcmRequestParts(plain);
    expect(noCreds.uri, plain);
    expect(noCreds.headers, isEmpty);
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
