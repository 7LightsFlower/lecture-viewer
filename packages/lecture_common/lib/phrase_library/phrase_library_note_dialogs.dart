import 'package:flutter/material.dart';

/// Confirms adding [content] to the library and optionally collects a note.
/// Returns the trimmed note on Add, or null if cancelled.
Future<String?> showPhraseLibraryAddDialog(
  BuildContext context, {
  required String content,
}) {
  return _showNoteDialog(
    context,
    title: 'Add to Collection?',
    content: content,
    initialNote: '',
    confirmLabel: 'Add',
  );
}

/// Edits the note for an existing phrase. Returns the trimmed note on Save,
/// or null if cancelled.
Future<String?> showPhraseLibraryEditNoteDialog(
  BuildContext context, {
  required String content,
  required String initialNote,
}) {
  return _showNoteDialog(
    context,
    title: 'Edit note',
    content: content,
    initialNote: initialNote,
    confirmLabel: 'Save',
  );
}

Future<String?> _showNoteDialog(
  BuildContext context, {
  required String title,
  required String content,
  required String initialNote,
  required String confirmLabel,
}) {
  return showDialog<String>(
    context: context,
    builder: (ctx) => _PhraseLibraryNoteDialog(
      title: title,
      content: content,
      initialNote: initialNote,
      confirmLabel: confirmLabel,
    ),
  );
}

class _PhraseLibraryNoteDialog extends StatefulWidget {
  const _PhraseLibraryNoteDialog({
    required this.title,
    required this.content,
    required this.initialNote,
    required this.confirmLabel,
  });

  final String title;
  final String content;
  final String initialNote;
  final String confirmLabel;

  @override
  State<_PhraseLibraryNoteDialog> createState() =>
      _PhraseLibraryNoteDialogState();
}

class _PhraseLibraryNoteDialogState extends State<_PhraseLibraryNoteDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialNote);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Phrase:',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 160),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      widget.content,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  labelText: 'Note',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                minLines: 1,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
