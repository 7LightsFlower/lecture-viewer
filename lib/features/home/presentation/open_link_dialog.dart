import 'package:flutter/material.dart';

import 'package:lecture_viewer_v3/core/util/open_lecture_session.dart';

/// Asks for a session link (app link, link record, shorten link or meeting
/// name) and opens it. Used in the browser, where QR scanning is awkward.
Future<void> showOpenLectureLinkDialog(BuildContext context) async {
  final input = await showDialog<String>(
    context: context,
    builder: (_) => const _OpenLinkDialog(),
  );
  if (input == null || !context.mounted) return;
  final ok = await openLectureSessionFromUserInput(context, input);
  if (!ok && context.mounted) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(content: Text('Invalid session link')),
    );
  }
}

class _OpenLinkDialog extends StatefulWidget {
  const _OpenLinkDialog();

  @override
  State<_OpenLinkDialog> createState() => _OpenLinkDialogState();
}

class _OpenLinkDialogState extends State<_OpenLinkDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _valid => linkRecordFromUserInput(_controller.text) != null;

  void _submit() {
    if (_valid) Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Open session'),
      content: SizedBox(
        width: 480,
        child: TextField(
          controller: _controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Session link or name',
            helperText:
                'lectureviewer.app.link/…, …/mobile/session/<name>, '
                '…/webapi/shorten/<name> or just <name>',
            helperMaxLines: 2,
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _submit(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _valid ? _submit : null,
          child: const Text('Open'),
        ),
      ],
    );
  }
}
