import 'package:lecture_viewer_v3/core/constants/api_environment.dart';
import 'package:lecture_viewer_v3/core/util/lecture_app_link.dart';

/// Temporary: include `noHistory=1` on the **initial** WebSocket connect.
/// Set to `false` to restore reconnect-only behavior.
const kLectureWsNoHistoryOnInitialConnect = true;

/// Default HTTPS origin for shorten / cached-text HTTP APIs.
const kLectureTranslatorHttpOrigin = 'https://lecture-translator.kit.edu';

/// HTTPS origin for shorten and cached-text requests.
///
/// On [ApiEnvironment.customOnDeeplink], prefers the host from [linkRecord].
/// Otherwise (and on fallback) uses [kLectureTranslatorHttpOrigin].
String httpsOriginForLectureHttp({
  required ApiEnvironment environment,
  required String linkRecord,
}) {
  if (environment == ApiEnvironment.customOnDeeplink) {
    final uri = Uri.parse(resolveSessionUrl(linkRecord));
    if (uri.host.isNotEmpty) {
      return uri.origin;
    }
  }
  return kLectureTranslatorHttpOrigin;
}

/// HTTPS origin used when building the lecture-session WebSocket URL.
///
/// On [ApiEnvironment.customOnDeeplink], prefers the host from [linkRecord].
/// Otherwise (and on fallback) uses [ApiEnvironment.origin].
String httpsOriginForLectureWs({
  required ApiEnvironment environment,
  required String linkRecord,
}) {
  if (environment == ApiEnvironment.customOnDeeplink) {
    final uri = Uri.parse(resolveSessionUrl(linkRecord));
    if (uri.host.isNotEmpty) {
      return uri.origin;
    }
  }
  return environment.origin;
}

/// Builds WebSocket URI for lecture session viewer.
Uri lectureSessionWsUri({
  required String httpsOrigin,
  required String sessionId,
  bool noHistory = kLectureWsNoHistoryOnInitialConnect,
}) {
  final https = Uri.parse(httpsOrigin);
  return Uri(
    scheme: 'wss',
    host: https.host,
    port: https.hasPort ? https.port : null,
    path: '/mobile/ws/lecture-session',
    queryParameters: {
      'sessionID': sessionId,
      if (noHistory) 'noHistory': '1',
    },
  );
}

/// Same as [lectureSessionWsUri] but adds `noHistory=1` for reconnect.
Uri lectureSessionWsReconnectUri(Uri wsUri) {
  return wsUri.replace(
    queryParameters: {...wsUri.queryParameters, 'noHistory': '1'},
  );
}
