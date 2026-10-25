import 'package:flutter/material.dart';

class HomeEmptyBody extends StatelessWidget {
  const HomeEmptyBody({required this.onScanPressed, super.key});

  final VoidCallback onScanPressed;

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
              'Scan a lecture QR code',
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Use a Branch link for lectureviewer.app.link. '
              'The session opens in the app.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onScanPressed,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan QR'),
            ),
          ],
        ),
      ),
    );
  }
}
