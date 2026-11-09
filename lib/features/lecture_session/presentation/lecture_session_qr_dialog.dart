import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

const double _qrSize = 220;
const double _qrFramePadding = 12;
const double _sharedQrSize = 1024;
const double _sharedQrQuietZone = 64;

/// White background and quiet zone keep the QR scannable on dark viewers.
Future<Uint8List> _renderQrPng(String joinUrl) async {
  const imageSize = _sharedQrSize + _sharedQrQuietZone * 2;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, imageSize, imageSize),
    Paint()..color = Colors.white,
  );
  canvas.translate(_sharedQrQuietZone, _sharedQrQuietZone);
  QrPainter(
    data: joinUrl,
    version: QrVersions.auto,
  ).paint(canvas, const Size.square(_sharedQrSize));

  final picture = recorder.endRecording();
  final image = await picture.toImage(imageSize.toInt(), imageSize.toInt());
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  } finally {
    image.dispose();
    picture.dispose();
  }
}

class _ShareQrButton extends StatefulWidget {
  const _ShareQrButton({required this.joinUrl});

  final String joinUrl;

  @override
  State<_ShareQrButton> createState() => _ShareQrButtonState();
}

class _ShareQrButtonState extends State<_ShareQrButton> {
  bool _sharing = false;

  Future<void> _shareQrImage() async {
    if (_sharing) return;
    _sharing = true;

    // iPad presents the share sheet as a popover anchored to the button.
    final box = context.findRenderObject() as RenderBox?;
    final origin =
        box == null ? null : box.localToGlobal(Offset.zero) & box.size;
    final navigator = Navigator.of(context, rootNavigator: true);

    showDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: Center(child: CircularProgressIndicator()),
      ),
    );
    var loadingVisible = true;
    void hideLoading() {
      if (!loadingVisible) return;
      loadingVisible = false;
      navigator.pop();
    }

    File? file;
    try {
      final bytes = await _renderQrPng(widget.joinUrl);
      final XFile shareFile;
      if (kIsWeb) {
        // Web has no file system: share the PNG bytes directly.
        shareFile = XFile.fromData(
          bytes,
          name: 'lecture-join-qr.png',
          mimeType: 'image/png',
        );
      } else {
        final dir = await getTemporaryDirectory();
        file = File('${dir.path}/lecture-join-qr.png');
        await file.writeAsBytes(bytes, flush: true);
        shareFile = XFile(file.path, mimeType: 'image/png');
      }
      // share() only returns once the system sheet closes; don't leave the
      // spinner running behind it.
      hideLoading();
      await SharePlus.instance.share(
        ShareParams(
          files: [shareFile],
          sharePositionOrigin: origin,
        ),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('share join QR failed: $e');
    } finally {
      hideLoading();
      try {
        if (file != null && file.existsSync()) await file.delete();
      } catch (_) {}
      _sharing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: _shareQrImage,
      icon: const Icon(Icons.share),
      label: const Text('Share'),
    );
  }
}

Future<void> showLectureSessionQrDialog({
  required BuildContext context,
  required String joinUrl,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      return Dialog(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Join to view transcription by QR',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 20),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(_qrFramePadding),
                  child: SizedBox.square(
                    dimension: _qrSize,
                    child: QrImageView(
                      data: joinUrl,
                      size: _qrSize,
                      backgroundColor: Colors.white,
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: _qrSize + _qrFramePadding * 2,
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Close'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: _ShareQrButton(joinUrl: joinUrl)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
