import 'package:flutter/material.dart';

import 'phrase_library_filter.dart';
import 'phrase_library_item.dart';
import 'phrase_library_item_row.dart';

/// Body only: language dropdown + filtered list. No AppBar / Scaffold.
class PhraseLibraryListView extends StatelessWidget {
  const PhraseLibraryListView({
    super.key,
    required this.items,
    required this.selectedLanguage,
    required this.onLanguageChanged,
    required this.onDelete,
    required this.onEditNote,
  });

  final List<PhraseLibraryItem> items;
  final String? selectedLanguage;
  final ValueChanged<String?> onLanguageChanged;
  final void Function(PhraseLibraryItem item) onDelete;
  final void Function(PhraseLibraryItem item) onEditNote;

  @override
  Widget build(BuildContext context) {
    final options = languageOptionsFromItems(items);
    final filtered = itemsForLanguage(items, selectedLanguage);
    final hasOptions = options.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: DropdownButtonFormField<String>(
            value: hasOptions ? selectedLanguage : null,
            decoration: const InputDecoration(
              labelText: 'Language',
              border: OutlineInputBorder(),
            ),
            items: options
                .map(
                  (lang) => DropdownMenuItem<String>(
                    value: lang,
                    child: Text(lang.isEmpty ? '(none)' : lang),
                  ),
                )
                .toList(),
            onChanged: hasOptions ? onLanguageChanged : null,
          ),
        ),
        Expanded(
          child: !hasOptions
              ? Center(
                  child: Text(
                    'No phrases yet',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                )
              : ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    return PhraseLibraryItemRow(
                      item: item,
                      onDeleted: () => onDelete(item),
                      onEditNote: () => onEditNote(item),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
