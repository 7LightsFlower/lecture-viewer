import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lecture_viewer_v3/features/lecture_session/domain/share/lecture_share_input.dart';
import 'package:lecture_viewer_v3/features/lecture_session/presentation/lecture_share_sheet.dart';

void main() {
  testWidgets('share sheet has no module dropdown', (tester) async {
    const input = LectureShareInput(
      subject: 'Test lecture',
      activeLanguages: ['English'],
      sessionId: '317374',
      httpsOrigin: 'https://lecture-translator.kit.edu',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () => showLectureShareSheet(
                    context: context,
                    input: input,
                  ),
                  child: const Text('Open share'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open share'));
    await tester.pumpAndSettle();

    expect(find.text('Include recording'), findsNothing);
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);
    expect(find.text('Module'), findsNothing);
  });

  testWidgets('all active languages are selectable', (tester) async {
    const input = LectureShareInput(
      subject: 'Test lecture',
      activeLanguages: ['English', 'Transcript'],
      sessionId: '317374',
      httpsOrigin: 'https://lecture-translator.kit.edu',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: FilledButton(
                onPressed: () => showLectureShareSheet(
                  context: context,
                  input: input,
                ),
                child: const Text('Open share'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open share'));
    await tester.pumpAndSettle();

    expect(find.text('No transcript is available'), findsNothing);
    expect(find.byType(CheckboxListTile), findsNWidgets(2));
  });
}
