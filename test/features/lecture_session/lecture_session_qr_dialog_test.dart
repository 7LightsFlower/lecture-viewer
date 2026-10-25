import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:lecture_viewer_v3/features/lecture_session/presentation/lecture_session_qr_dialog.dart';

void main() {
  const joinUrl =
      'https://lectureviewer.app.link/x?link_record=lt2srv.iar.kit.edu/mobile/session/foo-lecture';

  testWidgets('shows title, QR, and Close only', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () => showLectureSessionQrDialog(
                  context: context,
                  joinUrl: joinUrl,
                ),
                child: const Text('Open'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Join to view transcription by QR'), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
    expect(find.text('Share QR'), findsNothing);
    expect(find.text('Join to view transcription by Link'), findsNothing);
    expect(find.text(joinUrl), findsNothing);

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Join to view transcription by QR'), findsNothing);
    expect(find.byType(Dialog), findsNothing);
  });
}
