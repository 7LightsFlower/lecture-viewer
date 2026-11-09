/// SharedPreferences key for [ApiEnvironment].
const String kApiEnvironmentPrefsKey = 'api_environment_v1';

/// Backend deployment the app talks to.
enum ApiEnvironment {
  production,
  testing,
  customOnDeeplink,

  /// No app backend: read sessions straight from the public KIT Lecture
  /// Translator (`/webapi/...`). Text edits from the backend are not shown.
  kitPublicDirect,
}

/// Canonical HTTPS origins for each [ApiEnvironment].
abstract final class ApiEnvironmentOrigins {
  static const production = 'https://lt2srv.iar.kit.edu';
  static const testing = 'https://ltg-api.vais.vn';
  static const kitPublicDirect = 'https://lecture-translator.kit.edu';

  static String forEnvironment(ApiEnvironment environment) =>
      switch (environment) {
        ApiEnvironment.production => production,
        ApiEnvironment.testing => testing,
        ApiEnvironment.customOnDeeplink => production,
        ApiEnvironment.kitPublicDirect => kitPublicDirect,
      };

  static String normalizeOrigin(String origin) {
    var value = origin.trim();
    while (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    return value;
  }
}

ApiEnvironment apiEnvironmentFromPrefs(String? raw) {
  return switch (raw) {
    'testing' => ApiEnvironment.testing,
    'production' => ApiEnvironment.production,
    'customOnDeeplink' => ApiEnvironment.customOnDeeplink,
    'kitPublicDirect' => ApiEnvironment.kitPublicDirect,
    _ => ApiEnvironment.customOnDeeplink,
  };
}

extension ApiEnvironmentDisplay on ApiEnvironment {
  String get prefsValue => name;

  String get origin => ApiEnvironmentOrigins.forEnvironment(this);

  String get settingsLabel => switch (this) {
        ApiEnvironment.production => 'Production',
        ApiEnvironment.testing => 'Testing',
        ApiEnvironment.customOnDeeplink => 'Custom',
        ApiEnvironment.kitPublicDirect => 'KIT public (direct)',
      };

  /// Subtitle under the settings radio (origin URL, or deeplink hint).
  String get settingsSubtitle => switch (this) {
        ApiEnvironment.customOnDeeplink => 'From deeplink',
        ApiEnvironment.kitPublicDirect => '$origin · no app backend',
        _ => origin,
      };
}
