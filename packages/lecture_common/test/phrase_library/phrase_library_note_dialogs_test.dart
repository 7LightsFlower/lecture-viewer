import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lecture_common/lecture_common.dart';

void main() {
  testWidgets('add dialog Cancel returns null', (tester) async {
    String? result = 'sentinel';

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showPhraseLibraryAddDialog(
                  context,
                  content: 'hello',
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(result, isNull);
  });

  testWidgets('add dialog Add returns trimmed note', (tester) async {
    String? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showPhraseLibraryAddDialog(
                  context,
                  content: 'hello',
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '  my note  ');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(result, 'my note');
  });

  testWidgets('edit note dialog Save returns trimmed note', (tester) async {
    String? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showPhraseLibraryEditNoteDialog(
                  context,
                  content: 'hello',
                  initialNote: 'old',
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('old'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '  updated  ');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(result, 'updated');
  });
}
