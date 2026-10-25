import 'package:flutter/material.dart';

import 'phrase_library_item.dart';

class PhraseLibraryItemRow extends StatelessWidget {
  const PhraseLibraryItemRow({
    super.key,
    required this.item,
    required this.onDeleted,
    required this.onEditNote,
  });

  final PhraseLibraryItem item;
  final VoidCallback onDeleted;
  final VoidCallback onEditNote;

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete phrase?'),
        content: const Text('Remove this phrase from the library?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    onDeleted();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final note = item.note.trim();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: SelectionArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.content,
                    style: theme.textTheme.bodyLarge,
                  ),
                  if (note.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      note,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: 'Edit note',
            icon: const Icon(Icons.edit_outlined, size: 18),
            iconSize: 18,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
            onPressed: onEditNote,
          ),
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline, size: 18),
            iconSize: 18,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
            onPressed: () => _confirmDelete(context),
          ),
        ],
      ),
    );
  }
}
