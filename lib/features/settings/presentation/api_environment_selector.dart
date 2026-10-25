import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lecture_viewer_v3/core/constants/api_environment.dart';
import 'package:lecture_viewer_v3/core/providers/api_environment_notifier.dart';
import 'package:lecture_viewer_v3/features/settings/presentation/settings_info_icon_button.dart';

const String _kApiEnvironmentInfo =
    'Choose which backend the app uses for future API requests. '
    'No network calls use this setting in the current release.';

class ApiEnvironmentSelector extends ConsumerWidget {
  const ApiEnvironmentSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final environment = ref.watch(apiEnvironmentProvider);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('API environment', style: theme.textTheme.titleSmall),
            ),
            const SettingsInfoIconButton(
              tooltip: 'About API environment',
              dialogTitle: 'API environment',
              message: _kApiEnvironmentInfo,
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Applies to new requests after you change this setting.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        RadioGroup<ApiEnvironment>(
          groupValue: environment,
          onChanged: (value) {
            if (value == null) return;
            ref.read(apiEnvironmentProvider.notifier).setEnvironment(value);
          },
          child: Column(
            children: [
              for (final option in ApiEnvironment.values)
                RadioListTile<ApiEnvironment>(
                  contentPadding: EdgeInsets.zero,
                  title: Text(option.settingsLabel),
                  subtitle: Text(
                    option.settingsSubtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  value: option,
                ),
            ],
          ),
        ),
      ],
    );
  }
}
