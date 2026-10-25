import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lecture_common/lecture_common.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        height: 200,
        width: 400,
        child: child,
      ),
    ),
  );
}

TranscriptBucket _tallBucket({required int paragraphCount}) {
  return TranscriptBucket(
    paragraphs: List<TranscriptParagraph>.generate(
      paragraphCount,
      (int i) => TranscriptParagraph(
        segments: [
          TranscriptSegment(
            text: 'Paragraph ${i + 1}. ' * 8,
            textCompoundId: 'mt:1|t$i',
          ),
        ],
      ),
    ),
    speakerLabelByCompoundId: const {},
  );
}

void main() {
  testWidgets('shows FAB when user scrolls away from bottom', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        TranslationResultTranscriptFollowView(
          textScaler: TextScaler.noScaling,
          activeBucket: _tallBucket(paragraphCount: 12),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(FloatingActionButton), findsNothing);

    await tester.drag(find.byType(ListView), const Offset(0, 120));
    await tester.pumpAndSettle();

    expect(find.byType(FloatingActionButton), findsOneWidget);
  });

  testWidgets('FAB tap re-enables follow and hides FAB', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        TranslationResultTranscriptFollowView(
          textScaler: TextScaler.noScaling,
          activeBucket: _tallBucket(paragraphCount: 12),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, 120));
    await tester.pumpAndSettle();
    expect(find.byType(FloatingActionButton), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.byType(FloatingActionButton), findsNothing);

    final scrollable =
        tester.widget<Scrollable>(find.byType(Scrollable).first);
    final position = scrollable.controller!.position;
    expect(
      position.maxScrollExtent - position.pixels,
      lessThanOrEqualTo(kTranscriptFollowBottomThreshold + 1),
    );
  });

  testWidgets('stays unfollowed when bucket grows after user scrolls up', (
    WidgetTester tester,
  ) async {
    const scopeKey = 'English|mt:1';
    var bucket = _tallBucket(paragraphCount: 8);

    await tester.pumpWidget(
      _wrap(
        TranslationResultTranscriptFollowView(
          textScaler: TextScaler.noScaling,
          activeBucket: bucket,
          followScopeKey: scopeKey,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, 120));
    await tester.pumpAndSettle();
    expect(find.byType(FloatingActionButton), findsOneWidget);

    bucket = _tallBucket(paragraphCount: 14);
    await tester.pumpWidget(
      _wrap(
        TranslationResultTranscriptFollowView(
          textScaler: TextScaler.noScaling,
          activeBucket: bucket,
          followScopeKey: scopeKey,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(FloatingActionButton), findsOneWidget);
  });

  testWidgets('follows bucket updates when at bottom', (
    WidgetTester tester,
  ) async {
    var bucket = _tallBucket(paragraphCount: 8);

    await tester.pumpWidget(
      _wrap(
        TranslationResultTranscriptFollowView(
          textScaler: TextScaler.noScaling,
          activeBucket: bucket,
        ),
      ),
    );
    await tester.pumpAndSettle();

    bucket = _tallBucket(paragraphCount: 14);
    await tester.pumpWidget(
      _wrap(
        TranslationResultTranscriptFollowView(
          textScaler: TextScaler.noScaling,
          activeBucket: bucket,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final scrollable =
        tester.widget<Scrollable>(find.byType(Scrollable).first);
    final position = scrollable.controller!.position;
    expect(
      position.maxScrollExtent - position.pixels,
      lessThanOrEqualTo(kTranscriptFollowBottomThreshold + 1),
    );
    expect(find.byType(FloatingActionButton), findsNothing);
  });
}
