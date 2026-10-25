import 'package:flutter/material.dart';

class SettingsInfoIconButton extends StatelessWidget {
  const SettingsInfoIconButton({
    super.key,
    required this.tooltip,
    required this.dialogTitle,
    required this.message,
  });

  final String tooltip;
  final String dialogTitle;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        icon: const Icon(Icons.info_outline, size: 20),
        onPressed: () {
          showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(dialogTitle),
              content: Text(message),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
