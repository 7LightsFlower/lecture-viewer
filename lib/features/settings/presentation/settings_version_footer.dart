import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

class SettingsVersionFooter extends StatefulWidget {
  const SettingsVersionFooter({super.key});

  @override
  State<SettingsVersionFooter> createState() => _SettingsVersionFooterState();
}

class _SettingsVersionFooterState extends State<SettingsVersionFooter> {
  String? _label;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() {
        _label = 'Version: ${info.version} (${info.buildNumber})';
      });
    } catch (_) {
      // Hide footer on failure — no user-facing error.
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = _label;
    if (label == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
