import 'package:lecture_viewer_v3/core/constants/lecture_app_link_constants.dart';

bool isLectureViewerAppLink(Uri uri) {
  if (uri.scheme != 'https') return false;
  if (uri.host != kLectureViewerAppLinkHost) return false;
  if (uri.pathSegments.isEmpty || uri.pathSegments.every((s) => s.isEmpty)) {
    return false;
  }
  final linkRecord = uri.queryParameters['link_record'];
  return linkRecord != null && linkRecord.trim().isNotEmpty;
}

String? linkRecordFromAppLinkUri(Uri uri) {
  final value = uri.queryParameters['link_record']?.trim();
  if (value == null || value.isEmpty) return null;
  return value;
}

String? linkRecordFromBranchSession(Map<dynamic, dynamic> data) {
  final direct = data['link_record'];
  if (direct is String && direct.trim().isNotEmpty) return direct.trim();

  const urlKeys = [
    r'$canonical_url',
    '+url',
    r'$desktop_url',
    '~referring_link',
  ];
  for (final key in urlKeys) {
    final raw = data[key];
    if (raw is! String) continue;
    final uri = Uri.tryParse(raw);
    final fromQuery = uri?.queryParameters['link_record']?.trim();
    if (fromQuery != null && fromQuery.isNotEmpty) return fromQuery;
  }
  return null;
}

String? joinUrlFromBranchSession(Map<dynamic, dynamic> data) {
  const urlKeys = [
    r'$canonical_url',
    '+url',
    r'$desktop_url',
    '~referring_link',
  ];
  for (final key in urlKeys) {
    final raw = data[key];
    if (raw is! String) continue;
    final trimmed = raw.trim();
    final uri = Uri.tryParse(trimmed);
    if (uri != null && isLectureViewerAppLink(uri)) {
      return trimmed;
    }
  }
  return null;
}

String resolveSessionUrl(String linkRecord) {
  final trimmed = linkRecord.trim();
  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
    return trimmed;
  }
  return 'https://$trimmed';
}

/// Last non-empty path segment of [link_record] (meeting / session id).
String? meetingNameFromLinkRecord(String linkRecord) {
  final resolved = resolveSessionUrl(linkRecord);
  final uri = Uri.parse(resolved);
  final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  if (segments.isEmpty) return null;
  return segments.last;
}

String? sessionNameFromAppLinkUri(Uri uri) {
  final value = uri.queryParameters['session_name']?.trim();
  if (value == null || value.isEmpty) return null;
  return value;
}

String? sessionNameFromLinkRecord(String linkRecord) {
  final uri = Uri.parse(resolveSessionUrl(linkRecord));
  return sessionNameFromAppLinkUri(uri);
}

String? sessionNameFromBranchSession(Map<dynamic, dynamic> data) {
  final direct = data['session_name'];
  if (direct is String && direct.trim().isNotEmpty) return direct.trim();

  const urlKeys = [
    r'$canonical_url',
    '+url',
    r'$desktop_url',
    '~referring_link',
  ];
  for (final key in urlKeys) {
    final raw = data[key];
    if (raw is! String) continue;
    final uri = Uri.tryParse(raw);
    if (uri == null) continue;
    final fromQuery = sessionNameFromAppLinkUri(uri);
    if (fromQuery != null) return fromQuery;
  }
  return null;
}
