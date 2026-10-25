import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lecture_viewer_v3/core/saved_lectures/saved_lectures_provider.dart';
import 'package:lecture_viewer_v3/features/home/presentation/home_empty_body.dart';
import 'package:lecture_viewer_v3/features/home/presentation/qr_scan_screen.dart';
import 'package:lecture_viewer_v3/features/home/presentation/saved_lectures_list.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  void _openScanner(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const QrScanScreen()),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(savedLecturesProvider);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.qr_code_scanner),
          tooltip: 'Scan QR',
          onPressed: () => _openScanner(context),
        ),
        title: const Text('Lectures'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.of(context).pushNamed('/settings'),
          ),
        ],
      ),
      body: saved.isEmpty
          ? HomeEmptyBody(onScanPressed: () => _openScanner(context))
          : const SavedLecturesList(),
    );
  }
}
