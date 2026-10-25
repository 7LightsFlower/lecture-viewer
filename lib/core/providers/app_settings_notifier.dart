import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lecture_viewer_v3/core/providers/core_providers.dart';

const String _kThemeModeKey = 'theme_mode_v1';
const String _kKeepScreenOnKey = 'keep_screen_on_v1';
const String _kTextScaleKey = 'text_scale_v1';

final appSettingsProvider =
    NotifierProvider<AppSettingsNotifier, AppSettingsState>(
  AppSettingsNotifier.new,
);

class AppSettingsState {
  const AppSettingsState({
    required this.themeMode,
    required this.keepScreenOn,
    required this.textScale,
  });

  final ThemeMode themeMode;
  final bool keepScreenOn;
  final double textScale;

  AppSettingsState copyWith({
    ThemeMode? themeMode,
    bool? keepScreenOn,
    double? textScale,
  }) {
    return AppSettingsState(
      themeMode: themeMode ?? this.themeMode,
      keepScreenOn: keepScreenOn ?? this.keepScreenOn,
      textScale: textScale ?? this.textScale,
    );
  }
}

class AppSettingsNotifier extends Notifier<AppSettingsState> {
  @override
  AppSettingsState build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final themeRaw = prefs.getString(_kThemeModeKey);
    final themeMode = switch (themeRaw) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    return AppSettingsState(
      themeMode: themeMode,
      keepScreenOn: prefs.getBool(_kKeepScreenOnKey) ?? false,
      textScale: prefs.getDouble(_kTextScaleKey) ?? 1.0,
    );
  }

  Future<void> increaseTextScale() async {
    final next = (state.textScale + 0.1).clamp(0.8, 2.0);
    await _setTextScale(next);
  }

  Future<void> decreaseTextScale() async {
    final next = (state.textScale - 0.1).clamp(0.8, 2.0);
    await _setTextScale(next);
  }

  Future<void> _setTextScale(double value) async {
    state = state.copyWith(textScale: value);
    await ref.read(sharedPreferencesProvider).setDouble(_kTextScaleKey, value);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await ref.read(sharedPreferencesProvider).setString(
          _kThemeModeKey,
          switch (mode) {
            ThemeMode.light => 'light',
            ThemeMode.dark => 'dark',
            ThemeMode.system => 'system',
          },
        );
  }

  Future<void> setKeepScreenOn(bool value) async {
    state = state.copyWith(keepScreenOn: value);
    await ref.read(sharedPreferencesProvider).setBool(_kKeepScreenOnKey, value);
  }
}
