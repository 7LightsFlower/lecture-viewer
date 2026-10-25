import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lecture_viewer_v3/core/saved_lectures/format/default_saved_lecture_display_name.dart';
import 'package:lecture_viewer_v3/core/saved_lectures/saved_lectures_provider.dart';

enum _SavePromptResult { dontSave, save, cancel }

/// Returns true if the session route should pop.
Future<bool> handleLectureSessionExit(
  BuildContext context,
  WidgetRef ref, {
  required String linkRecord,
  required String sessionId,
  String? joinUrl,
  bool skipSavePrompt = false,
}) async {
  if (skipSavePrompt) return true;
  if (ref.read(savedLecturesProvider.notifier).containsLinkRecord(linkRecord)) {
    return true;
  }

  final prompt = await showDialog<_SavePromptResult>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Save lecture?'),
      content: const Text('Save this lecture to your home screen?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(_SavePromptResult.dontSave),
          child: const Text("Don't save"),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(_SavePromptResult.cancel),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(_SavePromptResult.save),
          child: const Text('Save'),
        ),
      ],
    ),
  );

  if (prompt == null || prompt == _SavePromptResult.cancel) {
    return false;
  }
  if (prompt == _SavePromptResult.dontSave) {
    return true;
  }

  final locale = Localizations.localeOf(context);
  final existingNames =
      ref.read(savedLecturesProvider).map((e) => e.displayName);
  final generated = defaultSavedLectureDisplayName(
    locale: locale,
    existingDisplayNames: existingNames,
  );

  final ok = await ref.read(savedLecturesProvider.notifier).add(
        displayName: generated,
        linkRecord: linkRecord,
        sessionId: sessionId,
        locale: locale,
        joinUrl: joinUrl,
      );
  if (!context.mounted) return false;
  if (!ok) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not save lecture')),
    );
    return false;
  }
  return true;
}
