import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SelectedContent;

import 'phrase_library_context_menu.dart';

class PhraseLibrarySelectionArea extends StatefulWidget {
  const PhraseLibrarySelectionArea({
    super.key,
    required this.child,
    this.onAddToLibrary,
  });

  final Widget child;
  final Future<void> Function(String content)? onAddToLibrary;

  @override
  State<PhraseLibrarySelectionArea> createState() =>
      _PhraseLibrarySelectionAreaState();
}

class _PhraseLibrarySelectionAreaState extends State<PhraseLibrarySelectionArea> {
  String? _selectedPlainText;

  @override
  Widget build(BuildContext context) {
    return SelectionArea(
      onSelectionChanged: (SelectedContent? content) {
        setState(() => _selectedPlainText = content?.plainText);
      },
      contextMenuBuilder: (context, selectableRegionState) {
        final baseItems = selectableRegionState.contextMenuButtonItems;
        if (baseItems.isEmpty) return const SizedBox.shrink();
        final onAdd = widget.onAddToLibrary;
        final buttonItems = onAdd == null
            ? baseItems
            : withPhraseLibraryMenuItem(
                baseItems: baseItems,
                selectedPlainText: _selectedPlainText,
                onAddToLibrary: (trimmed) {
                  onAdd(trimmed);
                },
              );
        return AdaptiveTextSelectionToolbar.buttonItems(
          anchors: selectableRegionState.contextMenuAnchors,
          buttonItems: buttonItems,
        );
      },
      child: widget.child,
    );
  }
}
