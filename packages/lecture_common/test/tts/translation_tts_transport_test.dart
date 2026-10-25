import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lecture_common/lecture_common.dart';

Widget _transportHarness({
  required double width,
  required TtsPaneSnapshot snapshot,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: width,
          child: TranslationTtsTransport(
            snapshot: snapshot,
            onPlayPause: () {},
            onSeekEnd: (_) {},
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('transport builds with zero buffer without throwing', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_transportHarness(
      width: 200,
      snapshot: const TtsPaneSnapshot(),
    ));
    expect(tester.takeException(), isNull);
  });

  testWidgets('zero pending hides download icon and pending text', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_transportHarness(
      width: 200,
      snapshot: const TtsPaneSnapshot(
        bufferedDurationSec: 10,
        pendingDownloadCount: 0,
      ),
    ));

    expect(find.byIcon(Icons.downloading), findsNothing);
    expect(find.textContaining('pending'), findsNothing);
  });

  testWidgets('pending narrow shows count only on slider', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_transportHarness(
      width: 120,
      snapshot: const TtsPaneSnapshot(
        bufferedDurationSec: 10,
        pendingDownloadCount: 3,
      ),
    ));

    expect(find.text('3'), findsOneWidget);
    expect(find.text('3 pending'), findsNothing);
    expect(find.byIcon(Icons.downloading), findsNothing);
  });

  testWidgets('pending wide shows full pending label', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_transportHarness(
      width: 200,
      snapshot: const TtsPaneSnapshot(
        bufferedDurationSec: 10,
        pendingDownloadCount: 3,
      ),
    ));

    expect(find.text('3 pending'), findsOneWidget);
    expect(find.byIcon(Icons.downloading), findsNothing);
  });

  testWidgets('pending wide still shows buffered duration', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_transportHarness(
      width: 200,
      snapshot: const TtsPaneSnapshot(
        bufferedDurationSec: 65,
        pendingDownloadCount: 2,
      ),
    ));

    expect(find.text('01:05'), findsOneWidget);
    expect(find.text('2 pending'), findsOneWidget);
  });

  testWidgets('showPlayButton false hides play icon but keeps slider', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 200,
              child: TranslationTtsTransport(
                showPlayButton: false,
                snapshot: const TtsPaneSnapshot(
                  bufferedDurationSec: 10,
                  pendingDownloadCount: 0,
                ),
                onPlayPause: () {},
                onSeekEnd: (_) {},
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.play_arrow), findsNothing);
    expect(find.byIcon(Icons.pause), findsNothing);
    expect(find.byType(Slider), findsOneWidget);
    expect(find.text('00:10'), findsOneWidget);
  });
}
