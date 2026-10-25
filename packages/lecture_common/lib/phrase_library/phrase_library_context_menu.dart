import 'package:flutter/material.dart';

/// Appends an **Add to Collection** button when [selectedPlainText] is non-empty
/// after trim. Otherwise returns [baseItems] unchanged (same instance).
List<ContextMenuButtonItem> withPhraseLibraryMenuItem({
  required List<ContextMenuButtonItem> baseItems,
  required String? selectedPlainText,
  required void Function(String trimmedContent) onAddToLibrary,
}) {
  final trimmed = selectedPlainText?.trim() ?? '';
  if (trimmed.isEmpty) {
    return baseItems;
  }
  return <ContextMenuButtonItem>[
    ContextMenuButtonItem(
      label: 'Add to Collection',
      onPressed: () {
        ContextMenuController.removeAny();
        onAddToLibrary(trimmed);
      },
    ),
    ...baseItems,
  ];
}
