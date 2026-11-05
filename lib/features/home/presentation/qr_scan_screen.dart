import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:lecture_viewer_v3/core/util/lecture_app_link.dart';
import 'package:lecture_viewer_v3/core/util/open_lecture_session.dart';

class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _handling = false;
  String? _rejectedValue;
  DateTime? _rejectedLastSeenAt;

  /// How long a rejected code must stay out of frame before it is handled again.
  static const Duration _rejectedCooldown = Duration(seconds: 3);

  static const Duration _rejectedToastDuration = Duration(seconds: 2);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handling) return;
    final raw = capture.barcodes.firstOrNull?.rawValue?.trim();
    if (raw == null) return;
    if (_isStillRejected(raw)) return;
    final uri = Uri.tryParse(raw);
    if (uri == null || !isLectureViewerAppLink(uri)) {
      _reject(raw, 'Invalid lecture link');
      return;
    }
    _handling = true;
    final ok = await openLectureSessionFromAppLink(context, raw);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
    } else {
      _reject(raw, 'Invalid session link');
      _handling = false;
      await _controller.start();
    }
  }

  /// The scanner fires on every frame, so a rejected code that stays in view
  /// keeps refreshing its cooldown instead of notifying again.
  bool _isStillRejected(String value) {
    if (value != _rejectedValue) return false;
    final now = DateTime.now();
    final stillRejected =
        now.difference(_rejectedLastSeenAt!) < _rejectedCooldown;
    _rejectedLastSeenAt = now;
    return stillRejected;
  }

  void _reject(String value, String message) {
    _rejectedValue = value;
    _rejectedLastSeenAt = DateTime.now();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), duration: _rejectedToastDuration),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: MobileScanner(controller: _controller, onDetect: _onDetect),
    );
  }
}
