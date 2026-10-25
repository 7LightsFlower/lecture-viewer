import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lecture_common/lecture_common.dart';

void main() {
  test('does not append item when selection empty or whitespace', () {
    final base = <ContextMenuButtonItem>[
      ContextMenuButtonItem(label: 'Copy', onPressed: () {}),
    ];
    expect(
      withPhraseLibraryMenuItem(
        baseItems: base,
        selectedPlainText: '   ',
        onAddToLibrary: (_) {},
      ),
      same(base),
    );
    expect(
      withPhraseLibraryMenuItem(
        baseItems: base,
        selectedPlainText: null,
        onAddToLibrary: (_) {},
      ),
      same(base),
    );
  });

  test('appends Add to Collection and invokes callback with trimmed text', () {
    final base = <ContextMenuButtonItem>[
      ContextMenuButtonItem(label: 'Copy', onPressed: () {}),
    ];
    String? captured;
    final items = withPhraseLibraryMenuItem(
      baseItems: base,
      selectedPlainText: '  hello  ',
      onAddToLibrary: (c) => captured = c,
    );

    expect(items.length, 2);
    expect(items.first.label, 'Add to Collection');
    items.first.onPressed!();
    expect(captured, 'hello');
  });
}
