import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:lecture_viewer_v3/core/api/lecture_shorten_client.dart';
import 'package:lecture_viewer_v3/core/util/lecture_ws_url.dart';

void main() {
  test('checkShorten returns 500 when server returns 500', () async {
    final client = HttpLectureShortenClient(
      httpClient: MockClient((request) async {
        expect(
          request.url.toString(),
          'https://lecture-translator.kit.edu/webapi/shorten/foo-lecture',
        );
        expect(request.method, 'GET');
        return http.Response('', 500);
      }),
    );

    expect(await client.checkShorten('foo-lecture'), 500);
  });

  test('checkShorten returns 200 when server returns 200', () async {
    final client = HttpLectureShortenClient(
      httpClient: MockClient((_) async => http.Response('ok', 200)),
    );

    expect(await client.checkShorten('foo-lecture'), 200);
  });

  test('checkShorten encodes meeting name in path', () async {
    final client = HttpLectureShortenClient(
      httpClient: MockClient((request) async {
        expect(request.url.path, '/webapi/shorten/foo%2Fbar');
        return http.Response('', 200);
      }),
    );

    await client.checkShorten('foo/bar');
  });

  test('checkShorten uses custom httpsOrigin', () async {
    final client = HttpLectureShortenClient(
      httpClient: MockClient((request) async {
        expect(
          request.url.toString(),
          'https://lt2srv.iar.kit.edu/webapi/shorten/huy2026a',
        );
        return http.Response('', 200);
      }),
    );

    expect(
      await client.checkShorten(
        'huy2026a',
        httpsOrigin: 'https://lt2srv.iar.kit.edu',
      ),
      200,
    );
  });

  test('checkShorten returns null on network failure', () async {
    final client = HttpLectureShortenClient(
      httpClient: MockClient((_) async {
        throw Exception('connection failed');
      }),
    );

    expect(await client.checkShorten('foo'), isNull);
  });

  test('default httpsOrigin is kit translator', () {
    expect(
      kLectureTranslatorHttpOrigin,
      'https://lecture-translator.kit.edu',
    );
  });
}
