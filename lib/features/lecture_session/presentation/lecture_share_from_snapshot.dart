import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lecture_viewer_v3/core/lecture_snapshot/lecture_snapshot_provider.dart';
import 'package:lecture_viewer_v3/core/providers/api_environment_notifier.dart';
import 'package:lecture_viewer_v3/core/util/lecture_ws_url.dart';
import 'package:lecture_viewer_v3/features/lecture_session/presentation/lecture_share_input_factory.dart';
import 'package:lecture_viewer_v3/features/lecture_session/presentation/lecture_share_sheet.dart';

Future<void> showLectureShareFromLinkRecord(
  BuildContext context,
  WidgetRef ref, {
  required String linkRecord,
  required String displayName,
}) async {
  try {
    final repo = await ref.read(lectureSnapshotRepositoryProvider.future);
    final record = await repo.get(linkRecord);
    if (!context.mounted) return;
    if (record == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No saved result')),
      );
      return;
    }
    final httpsOrigin = httpsOriginForLectureHttp(
      environment: ref.read(apiEnvironmentProvider),
      linkRecord: linkRecord,
    );
    await showLectureShareSheet(
      context: context,
      input: lectureShareInputFromSnapshot(
        subject: displayName,
        record: record,
        httpsOrigin: httpsOrigin,
      ),
    );
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not load saved result')),
    );
  }
}
