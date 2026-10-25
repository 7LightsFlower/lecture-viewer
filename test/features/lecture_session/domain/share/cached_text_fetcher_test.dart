import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lecture_viewer_v3/features/lecture_session/domain/share/cached_text_fetcher.dart';

void main() {
  test('returns body on 200', () async {
    final client = MockClient((request) async {
      expect(
        request.url.toString(),
        'https://lecture-translator.kit.edu/get_cached_text/abc123?window=German',
      );
      return http.Response('<h2>Title</h2>', 200);
    });

    final result = await fetchCachedText(
      sessionId: 'abc123',
      language: 'German',
      client: client,
    );

    expect(result, '<h2>Title</h2>');
  });

  test('uses custom httpsOrigin', () async {
    final client = MockClient((request) async {
      expect(
        request.url.toString(),
        'https://lt2srv.iar.kit.edu/get_cached_text/abc123?window=German',
      );
      return http.Response('<p>ok</p>', 200);
    });

    await fetchCachedText(
      sessionId: 'abc123',
      language: 'German',
      httpsOrigin: 'https://lt2srv.iar.kit.edu',
      client: client,
    );
  });

  test('encodes window query parameter', () async {
    final client = MockClient((request) async {
      expect(request.url.queryParameters['window'], 'Español');
      return http.Response('<p>ok</p>', 200);
    });

    await fetchCachedText(
      sessionId: 's1',
      language: 'Español',
      client: client,
    );
  });

  test('throws on non-200', () async {
    final client = MockClient((_) async => http.Response('error', 404));

    expect(
      () => fetchCachedText(
        sessionId: 'abc123',
        language: 'German',
        client: client,
      ),
      throwsA(isA<CachedTextFetchException>()),
    );
  });

  test('throws on empty body', () async {
    final client = MockClient((_) async => http.Response('  ', 200));

    expect(
      () => fetchCachedText(
        sessionId: 'abc123',
        language: 'German',
        client: client,
      ),
      throwsA(isA<CachedTextFetchException>()),
    );
  });
}
