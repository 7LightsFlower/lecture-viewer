import 'package:flutter/material.dart';

import 'package:lecture_viewer_v3/core/util/open_lecture_session.dart';

/// Asks for a session link (app link, link record, shorten link or meeting
/// name) and opens it. The alternative to scanning a QR code, for devices
/// without a (working) camera.
///
/// Returns true once a session was opened (and has been closed again).
Future<bool> showOpenLectureLinkDialog(BuildContext context) async {
  final input = await showDialog<String>(
    context: context,
    builder: (_) => const _OpenLinkDialog(),
  );
  if (input == null || !context.mounted) return false;
  final ok = await openLectureSessionFromUserInput(context, input);
  if (!ok && context.mounted) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(
        content: Text(
          'This session link is invalid. Please check the link and try again.',
        ),
      ),
    );
  }
  return ok;
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
      title: const Text('Enter session link'),
      content: SizedBox(
        width: 480,
        child: TextField(
          controller: _controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Paste the link from the QR code',
            helperText:
                'https://<server>/webapi/shorten/<name>, '
                'a lectureviewer.app.link link, or just <name>',
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
