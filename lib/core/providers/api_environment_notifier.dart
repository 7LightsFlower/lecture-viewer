import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lecture_viewer_v3/core/constants/api_environment.dart';
import 'package:lecture_viewer_v3/core/providers/core_providers.dart';

final apiEnvironmentProvider =
    NotifierProvider<ApiEnvironmentNotifier, ApiEnvironment>(
  ApiEnvironmentNotifier.new,
);

class ApiEnvironmentNotifier extends Notifier<ApiEnvironment> {
  @override
  ApiEnvironment build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return apiEnvironmentFromPrefs(prefs.getString(kApiEnvironmentPrefsKey));
  }

  void setEnvironment(ApiEnvironment environment) {
    if (state == environment) return;
    state = environment;
    ref.read(sharedPreferencesProvider).setString(
          kApiEnvironmentPrefsKey,
          environment.prefsValue,
        );
  }
}
