import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lecture_viewer_v3/core/api/lecture_shorten_client.dart';
import 'package:lecture_viewer_v3/core/constants/api_environment.dart';
import 'package:lecture_viewer_v3/core/lecture_snapshot/lecture_snapshot_provider.dart';
import 'package:lecture_viewer_v3/core/providers/api_environment_notifier.dart';
import 'package:lecture_viewer_v3/core/saved_lectures/saved_lectures_provider.dart';
import 'package:lecture_viewer_v3/core/util/lecture_app_link.dart';
import 'package:lecture_viewer_v3/core/util/lecture_ws_url.dart';
import 'package:lecture_viewer_v3/features/lecture_session/presentation/lecture_session_pop_result.dart';
import 'package:lecture_viewer_v3/features/lecture_session/presentation/lecture_session_scope.dart';
import 'package:lecture_viewer_v3/features/lecture_session/presentation/lecture_session_screen.dart';
import 'package:lecture_viewer_v3/features/lecture_session/presentation/session_unavailable_dialog.dart';

void _showJoinLoadingDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: false,
    builder: (ctx) => const AlertDialog(
      content: Row(
        children: [
          CircularProgressIndicator(),
          SizedBox(width: 24),
          Expanded(child: Text('Checking session…')),
        ],
      ),
    ),
  );
}

Future<int?> _runShortenCheck(
  BuildContext context,
  String meetingName, {
  required LectureShortenClient shortenClient,
  required String httpsOrigin,
}) async {
  _showJoinLoadingDialog(context);
  await Future<void>.delayed(Duration.zero);
  if (!context.mounted) return null;
  try {
    return await shortenClient.checkShorten(
      meetingName,
      httpsOrigin: httpsOrigin,
    );
  } finally {
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }
}

/// Opens a session from a join link after the shorten check: KIT's own
/// `https://<server>/webapi/shorten/<name>` or a lectureviewer.app.link URL.
Future<bool> openLectureSessionFromAppLink(
  BuildContext context,
  String appLink,
) async {
  final uri = Uri.tryParse(appLink.trim());
  if (uri == null || !isLectureJoinLink(uri)) {
    return false;
  }
  final linkRecord = linkRecordFromJoinLink(uri);
  if (linkRecord == null) {
    return false;
  }
  return openLectureSessionFromLinkRecord(
    context,
    linkRecord,
    sessionName:
        isLectureViewerAppLink(uri) ? sessionNameFromAppLinkUri(uri) : null,
    joinUrl: appLink.trim(),
  );
}

/// Validates [linkRecord], runs shorten check, then opens in-app meeting view.
///
/// The join QR always shows KIT's public link for the session
/// (`https://<host>/webapi/shorten/<name>`, no app backend needed);
/// [joinUrl] is only used if that can't be built.
Future<bool> openLectureSessionFromLinkRecord(
  BuildContext context,
  String linkRecord, {
  String? sessionName,
  LectureShortenClient? shortenClient,
  String? joinUrl,
}) async {
  assert(sessionName == null || sessionName.isNotEmpty);
  final meetingName = meetingNameFromLinkRecord(linkRecord);
  if (meetingName == null || meetingName.isEmpty) {
    return false;
  }

  var resolvedJoinUrl = kitShortenJoinUrlForLinkRecord(linkRecord);
  if (resolvedJoinUrl == null && joinUrl != null) {
    final trimmed = joinUrl.trim();
    final uri = Uri.tryParse(trimmed);
    if (uri != null && isLectureJoinLink(uri)) {
      resolvedJoinUrl = trimmed;
    }
  }

  final client = shortenClient ?? defaultLectureShortenClient;
  final env = ProviderScope.containerOf(context).read(apiEnvironmentProvider);
  final httpsOrigin = httpsOriginForLectureHttp(
    environment: env,
    linkRecord: linkRecord,
  );

  while (context.mounted) {
    final status = await _runShortenCheck(
      context,
      meetingName,
      shortenClient: client,
      httpsOrigin: httpsOrigin,
    );
    if (!context.mounted) return false;

    if (kDebugMode) {
      debugPrint(
        '[LectureShorten] decision meeting=$meetingName '
        'origin=$httpsOrigin status=$status',
      );
    }

    if (status == 500) {
      if (kDebugMode) {
        debugPrint(
          '[LectureShorten] showing Session ended because status=500',
        );
      }
      await showSessionUnavailableDialog(context);
      return false;
    }

    await deleteLectureSnapshotForLinkRecord(linkRecord);
    if (!context.mounted) return false;

    if (resolvedJoinUrl != null) {
      await ProviderScope.containerOf(context)
          .read(savedLecturesProvider.notifier)
          .setJoinUrlIfMissing(linkRecord, resolvedJoinUrl);
      if (!context.mounted) return false;
    }

    final popResult = await Navigator.of(context).push<LectureSessionPopResult>(
      MaterialPageRoute<LectureSessionPopResult>(
        builder: (_) => LectureSessionScreen(
          scope: lectureSessionScope(
            sessionId: meetingName,
            linkRecord: linkRecord,
            joinUrl: resolvedJoinUrl,
          ),
        ),
      ),
    );
    if (!context.mounted) return false;

    if (popResult == LectureSessionPopResult.retryJoin) {
      continue;
    }
    return true;
  }
  return false;
}

/// Turns user-supplied text into a `link_record`:
/// - KIT join link `https://<server>/webapi/shorten/<name>` (kept as is)
/// - app link `https://lectureviewer.app.link/...?link_record=...`
/// - link record with or without scheme (`lt2srv.iar.kit.edu/mobile/session/x`)
/// - a bare meeting name `x` → KIT's public server
///   (`lecture-translator.kit.edu/webapi/shorten/x`).
///
/// Returns null when nothing usable is found.
String? linkRecordFromUserInput(String input) {
  final text = input.trim();
  if (text.isEmpty) return null;

  final uri = Uri.tryParse(text);
  if (uri != null && isLectureJoinLink(uri)) {
    return linkRecordFromJoinLink(uri);
  }

  if (!text.contains('/')) {
    if (!RegExp(r'^[\w.\-]+$').hasMatch(text)) return null;
    return '${Uri.parse(ApiEnvironmentOrigins.kitPublicDirect).host}'
        '/webapi/shorten/${Uri.encodeComponent(text)}';
  }

  final withoutScheme = text.replaceFirst(RegExp(r'^https?://'), '');
  final asKitLink = Uri.tryParse('https://$withoutScheme');
  if (asKitLink != null && isKitShortenLink(asKitLink)) {
    return linkRecordFromKitShortenUri(asKitLink);
  }
  final record = withoutScheme.split(RegExp('[?#]')).first;
  return meetingNameFromLinkRecord(record) == null ? null : record;
}

/// Opens a session from pasted text (see [linkRecordFromUserInput]).
Future<bool> openLectureSessionFromUserInput(
  BuildContext context,
  String input,
) async {
  final trimmed = input.trim();
  final uri = Uri.tryParse(trimmed);
  if (uri != null && isLectureJoinLink(uri)) {
    return openLectureSessionFromAppLink(context, trimmed);
  }
  final linkRecord = linkRecordFromUserInput(trimmed);
  if (linkRecord == null) return false;
  return openLectureSessionFromLinkRecord(context, linkRecord);
}
