import 'package:flutter/material.dart';

class HomeEmptyBody extends StatelessWidget {
  const HomeEmptyBody({
    required this.onScanPressed,
    required this.onEnterLinkPressed,
    super.key,
  });

  /// Null hides the scan button (no QR scanner on this platform).
  final VoidCallback? onScanPressed;
  final VoidCallback onEnterLinkPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.qr_code_2, size: 72, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              onScanPressed != null
                  ? 'Scan a lecture QR code'
                  : 'Open a lecture',
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              onScanPressed != null
                  ? 'Scan the QR code shown in the lecture, or paste its '
                      'link if your camera is not available.'
                  : 'Paste the link from the lecture QR code. '
                      'The session opens in the app.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (onScanPressed != null) ...[
              FilledButton.icon(
                onPressed: onScanPressed,
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Scan QR'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onEnterLinkPressed,
                icon: const Icon(Icons.link),
                label: const Text('Enter link'),
              ),
            ] else
              FilledButton.icon(
                onPressed: onEnterLinkPressed,
                icon: const Icon(Icons.link),
                label: const Text('Enter link'),
              ),
          ],
        ),
      ),
    );
  }
}
