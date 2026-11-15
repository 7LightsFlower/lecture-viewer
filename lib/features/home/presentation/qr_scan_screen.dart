import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:lecture_viewer_v3/core/util/lecture_app_link.dart';
import 'package:lecture_viewer_v3/core/util/open_lecture_session.dart';
import 'package:lecture_viewer_v3/features/home/presentation/open_link_dialog.dart';

/// Whether `mobile_scanner` supports this platform at all (it has no
/// Windows/Linux implementation). Elsewhere a camera may still be missing;
/// the scanner screen then offers the link entry instead.
bool get isQrScannerSupported =>
    kIsWeb ||
    switch (defaultTargetPlatform) {
      TargetPlatform.android ||
      TargetPlatform.iOS ||
      TargetPlatform.macOS => true,
      _ => false,
    };

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
      _reject(
        raw,
        'This lecture link is invalid. Please check the link and try again.',
      );
      return;
    }
    _handling = true;
    final ok = await openLectureSessionFromAppLink(context, raw);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
    } else {
      _reject(
        raw,
        'This session link is invalid. Please check the link and try again.',
      );
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

  /// Link entry from the scanner: pause scanning meanwhile, and close the
  /// scanner after a session was opened (same as after a scanned code).
  Future<void> _enterLink() async {
    if (_handling) return;
    _handling = true;
    try {
      await _controller.stop();
    } on Object {
      // No camera running (e.g. permission denied): nothing to pause.
    }
    if (!mounted) return;
    final ok = await showOpenLectureLinkDialog(context);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
      return;
    }
    _handling = false;
    try {
      await _controller.start();
    } on Object {
      // Camera unavailable; the error view keeps offering the link entry.
    }
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
        actions: [
          TextButton.icon(
            onPressed: _enterLink,
            icon: const Icon(Icons.link),
            label: const Text('Enter link'),
          ),
        ],
      ),
      body: MobileScanner(
        controller: _controller,
        onDetect: _onDetect,
        errorBuilder: (context, error) => _CameraUnavailable(
          error: error,
          onEnterLink: _enterLink,
        ),
      ),
    );
  }
}

/// Shown instead of the camera preview when the camera can't be used.
class _CameraUnavailable extends StatelessWidget {
  const _CameraUnavailable({required this.error, required this.onEnterLink});

  final MobileScannerException error;
  final VoidCallback onEnterLink;

  String get _reason => switch (error.errorCode) {
        MobileScannerErrorCode.permissionDenied =>
          'Camera access was denied.',
        MobileScannerErrorCode.unsupported =>
          'This device has no camera that can scan QR codes.',
        _ => 'The camera could not be started.',
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ColoredBox(
      color: theme.colorScheme.surface,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.no_photography_outlined,
                size: 64,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                _reason,
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'You can paste the session link instead.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onEnterLink,
                icon: const Icon(Icons.link),
                label: const Text('Enter link'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
