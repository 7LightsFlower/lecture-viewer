import 'package:flutter/material.dart';

/// Session cannot be joined (shorten 500 or WebSocket session_end).
Future<void> showSessionUnavailableDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: const Text('Session ended'),
      content: const Text('This session is no longer available.'),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}
