import 'package:flutter_test/flutter_test.dart';
import 'package:lecture_viewer_v3/core/constants/api_environment.dart';
import 'package:lecture_viewer_v3/core/util/lecture_ws_url.dart';

void main() {
  group('apiEnvironmentFromPrefs', () {
    test('defaults to customOnDeeplink', () {
      expect(apiEnvironmentFromPrefs(null), ApiEnvironment.customOnDeeplink);
      expect(apiEnvironmentFromPrefs('invalid'), ApiEnvironment.customOnDeeplink);
    });

    test('reads known prefs values', () {
      expect(apiEnvironmentFromPrefs('production'), ApiEnvironment.production);
      expect(apiEnvironmentFromPrefs('testing'), ApiEnvironment.testing);
      expect(
        apiEnvironmentFromPrefs('customOnDeeplink'),
        ApiEnvironment.customOnDeeplink,
      );
    });
  });

  group('httpsOriginForLectureHttp', () {
    test('customOnDeeplink uses host from link_record', () {
      expect(
        httpsOriginForLectureHttp(
          environment: ApiEnvironment.customOnDeeplink,
          linkRecord: 'lt2srv.iar.kit.edu/mobile/session/huy2026a',
        ),
        'https://lt2srv.iar.kit.edu',
      );
    });

    test('customOnDeeplink falls back to kit translator', () {
      expect(
        httpsOriginForLectureHttp(
          environment: ApiEnvironment.customOnDeeplink,
          linkRecord: '',
        ),
        kLectureTranslatorHttpOrigin,
      );
    });

    test('production ignores link_record host', () {
      expect(
        httpsOriginForLectureHttp(
          environment: ApiEnvironment.production,
          linkRecord: 'lt2srv.iar.kit.edu/mobile/session/huy2026a',
        ),
        kLectureTranslatorHttpOrigin,
      );
    });

    test('testing ignores link_record host', () {
      expect(
        httpsOriginForLectureHttp(
          environment: ApiEnvironment.testing,
          linkRecord: 'lt2srv.iar.kit.edu/mobile/session/huy2026a',
        ),
        kLectureTranslatorHttpOrigin,
      );
    });
  });

  group('httpsOriginForLectureWs', () {
    test('customOnDeeplink uses host from link_record', () {
      expect(
        httpsOriginForLectureWs(
          environment: ApiEnvironment.customOnDeeplink,
          linkRecord: 'lt2srv.iar.kit.edu/mobile/session/huy2026a',
        ),
        'https://lt2srv.iar.kit.edu',
      );
    });

    test('customOnDeeplink uses origin from full https link_record', () {
      expect(
        httpsOriginForLectureWs(
          environment: ApiEnvironment.customOnDeeplink,
          linkRecord:
              'https://lt2srv.iar.kit.edu/mobile/session/huy2026a',
        ),
        'https://lt2srv.iar.kit.edu',
      );
    });

    test('customOnDeeplink falls back when link_record has no host', () {
      expect(
        httpsOriginForLectureWs(
          environment: ApiEnvironment.customOnDeeplink,
          linkRecord: '',
        ),
        ApiEnvironmentOrigins.production,
      );
    });

    test('production ignores link_record host', () {
      expect(
        httpsOriginForLectureWs(
          environment: ApiEnvironment.production,
          linkRecord: 'ltg-api.vais.vn/mobile/session/huy2026a',
        ),
        ApiEnvironmentOrigins.production,
      );
    });

    test('testing ignores link_record host', () {
      expect(
        httpsOriginForLectureWs(
          environment: ApiEnvironment.testing,
          linkRecord: 'lt2srv.iar.kit.edu/mobile/session/huy2026a',
        ),
        ApiEnvironmentOrigins.testing,
      );
    });
  });

  test('builds wss lecture-session URL', () {
    final uri = lectureSessionWsUri(
      httpsOrigin: 'https://lt2srv.iar.kit.edu',
      sessionId: 'tkq1221114001-lecture',
    );
    expect(uri.scheme, 'wss');
    expect(uri.host, 'lt2srv.iar.kit.edu');
    expect(uri.path, '/mobile/ws/lecture-session');
    expect(uri.queryParameters['sessionID'], 'tkq1221114001-lecture');
    expect(uri.queryParameters['noHistory'], '1');
  });

  test('noHistory false omits query param', () {
    final uri = lectureSessionWsUri(
      httpsOrigin: 'https://lt2srv.iar.kit.edu',
      sessionId: 'abc',
      noHistory: false,
    );
    expect(uri.queryParameters.containsKey('noHistory'), isFalse);
  });

  test('noHistory true adds query param', () {
    final uri = lectureSessionWsUri(
      httpsOrigin: 'https://lt2srv.iar.kit.edu',
      sessionId: 'abc',
      noHistory: true,
    );
    expect(uri.queryParameters['noHistory'], '1');
  });

  test('reconnect URI adds noHistory to existing ws URI', () {
    final base = lectureSessionWsUri(
      httpsOrigin: 'https://lt2srv.iar.kit.edu',
      sessionId: 'abc',
      noHistory: false,
    );
    final reconnect = lectureSessionWsReconnectUri(base);
    expect(reconnect.queryParameters['sessionID'], 'abc');
    expect(reconnect.queryParameters['noHistory'], '1');
  });
}
