import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:lecture_viewer_v3/features/lecture_session/presentation/lecture_session_qr_dialog.dart';

void main() {
  const joinUrl =
      'https://lectureviewer.app.link/x?link_record=lt2srv.iar.kit.edu/mobile/session/foo-lecture';

  Future<void> openDialog(WidgetTester tester) async {
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
  }

  testWidgets('shows title, QR, Share, and Close', (tester) async {
    await openDialog(tester);

    expect(find.text('Join to view transcription by QR'), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
    expect(find.text('Join to view transcription by Link'), findsNothing);
    expect(find.text(joinUrl), findsNothing);

    // Close and Share share one row, equal width, Close on the left.
    final closeRect = tester.getRect(find.bySubtype<OutlinedButton>());
    final shareRect = tester.getRect(find.bySubtype<FilledButton>());
    expect(closeRect.top, shareRect.top);
    expect(closeRect.width, shareRect.width);
    expect(closeRect.right, lessThan(shareRect.left));

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Join to view transcription by QR'), findsNothing);
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('Share shows full-screen loading, sends QR PNG, stays open', (
    tester,
  ) async {
    final messenger = tester.binding.defaultBinaryMessenger;
    const shareChannel = MethodChannel('dev.fluttercommunity.plus/share');
    const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
    final tempDir = await tester.runAsync(
      () => Directory.systemTemp.createTemp('qr_dialog_test'),
    );
    addTearDown(() => tempDir!.deleteSync(recursive: true));

    messenger.setMockMethodCallHandler(pathChannel, (_) async => tempDir!.path);
    addTearDown(() => messenger.setMockMethodCallHandler(pathChannel, null));

    var shareCalls = 0;
    Map<dynamic, dynamic>? shareArgs;
    Uint8List? sharedBytes;
    final shareSheetClosed = Completer<void>();
    messenger.setMockMethodCallHandler(shareChannel, (call) async {
      shareCalls++;
      shareArgs = call.arguments as Map<dynamic, dynamic>;
      // The dialog deletes the temp file once sharing returns.
      sharedBytes = File(
        (shareArgs!['paths'] as List<dynamic>).single as String,
      ).readAsBytesSync();
      await shareSheetClosed.future;
      return 'dev.fluttercommunity.plus/share/success';
    });
    addTearDown(() => messenger.setMockMethodCallHandler(shareChannel, null));

    await openDialog(tester);
    await tester.tap(find.text('Share'));
    await tester.pump();

    // Spinner sits on its own route, outside the QR dialog.
    final spinner = find.byType(CircularProgressIndicator);
    expect(spinner, findsOneWidget);
    expect(
      find.descendant(of: find.byType(Dialog), matching: spinner),
      findsNothing,
    );

    // Image encoding and file IO need real async time.
    Future<void> waitUntil(bool Function() condition) async {
      for (var i = 0; i < 200 && !condition(); i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    await waitUntil(() => shareArgs != null && spinner.evaluate().isEmpty);
    expect(shareArgs, isNotNull);
    expect(spinner, findsNothing);

    // A tap while the system sheet is still open must not share again.
    await tester.tap(find.text('Share'));
    await tester.pump();
    expect(spinner, findsNothing);
    expect(shareCalls, 1);

    shareSheetClosed.complete();
    await waitUntil(() => tempDir!.listSync().isEmpty);

    expect(shareArgs!['mimeTypes'], ['image/png']);
    expect(shareArgs!['originWidth'], greaterThan(0));
    expect(shareArgs!.containsKey('text'), isFalse);
    expect(tempDir!.listSync(), isEmpty);
    expect(find.byType(Dialog), findsOneWidget);

    final pixels = await tester.runAsync(() async {
      final codec = await ui.instantiateImageCodec(sharedBytes!);
      final frame = await codec.getNextFrame();
      final data = await frame.image.toByteData();
      return (width: frame.image.width, bytes: data!);
    });
    expect(pixels!.width, 1152);
    // Top-left pixel sits in the quiet zone: opaque white RGBA.
    expect(pixels.bytes.getUint32(0), 0xFFFFFFFF);
    // Just inside the quiet zone is the QR finder pattern: opaque black.
    expect(pixels.bytes.getUint32((70 * 1152 + 70) * 4), 0x000000FF);
  });
}
