import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lecture_viewer_v3/core/constants/api_environment.dart';
import 'package:lecture_viewer_v3/core/constants/app_variant.dart';
import 'package:lecture_viewer_v3/core/providers/api_environment_notifier.dart';
import 'package:lecture_viewer_v3/core/providers/app_settings_notifier.dart';
import 'package:lecture_viewer_v3/core/providers/app_variant_provider.dart';
import 'package:lecture_viewer_v3/features/settings/presentation/api_environment_selector.dart';
import 'package:lecture_viewer_v3/features/settings/presentation/settings_section_card.dart';
import 'package:lecture_viewer_v3/features/settings/presentation/settings_version_footer.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final apiEnvironment = ref.watch(apiEnvironmentProvider);
    final appVariant = ref.watch(appVariantProvider).valueOrNull;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          SettingsSectionCard(
            title: 'Display',
            children: [
              Text('Theme', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              RadioGroup<ThemeMode>(
                groupValue: settings.themeMode,
                onChanged: (value) {
                  if (value == null) return;
                  ref.read(appSettingsProvider.notifier).setThemeMode(value);
                },
                child: Column(
                  children: [
                    RadioListTile<ThemeMode>(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Light'),
                      value: ThemeMode.light,
                    ),
                    RadioListTile<ThemeMode>(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Dark'),
                      value: ThemeMode.dark,
                    ),
                    RadioListTile<ThemeMode>(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('System'),
                      value: ThemeMode.system,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SettingsSectionCard(
            title: 'Device',
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Keep screen on'),
                subtitle: Text(
                  'Keeps the screen awake while this app is open',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                value: settings.keepScreenOn,
                onChanged: ref.read(appSettingsProvider.notifier).setKeepScreenOn,
              ),
            ],
          ),
          if (kDebugMode || appVariant == AppVariant.alpha) ...[
            const SizedBox(height: 12),
            CollapsibleSettingsSectionCard(
              title: 'Advanced',
              subtitle: apiEnvironment.settingsLabel,
              children: const [ApiEnvironmentSelector()],
            ),
          ],
          const SettingsVersionFooter(),
        ],
      ),
    );
  }
}
