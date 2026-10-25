# Home & Settings Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the Flutter counter template with home (QR + empty state), Branch.io deep links for `lectureviewer.app.link`, settings (theme, keep screen on, API environment), and external-browser launch of resolved session URLs — per `docs/superpowers/specs/2026-05-18-home-settings-design.md`.

**Architecture:** Feature-based layout (`lib/app/`, `lib/core/`, `lib/features/`). Riverpod + `SharedPreferences` for settings. Pure `lecture_app_link.dart` helpers (tested). `flutter_branch_sdk` for tap-to-open-app; `mobile_scanner` for QR. Single `handleLectureSessionLink` for both paths.

**Tech stack:** Flutter 3.10+, `flutter_riverpod`, `shared_preferences`, `flutter_branch_sdk`, `mobile_scanner`, `url_launcher`, `wakelock_plus`.

**Prerequisites:** Branch live/test keys from dashboard; confirm production links include `link_record` in session data (Link Debugger).

---

## File map

| Path | Responsibility |
|------|----------------|
| `lib/main.dart` | Bootstrap prefs, Branch init, `ProviderScope` |
| `lib/app/lecture_viewer_app.dart` | `MaterialApp`, routes, theme |
| `lib/app/wakelock_lifecycle_binding.dart` | Foreground wakelock when setting on |
| `lib/app/branch_session_listener.dart` | `listSession` → launch session |
| `lib/core/constants/api_environment.dart` | Copy semantics from `app_2way_v3` |
| `lib/core/constants/lecture_app_link_constants.dart` | Host string |
| `lib/core/providers/core_providers.dart` | `sharedPreferencesProvider` |
| `lib/core/providers/api_environment_notifier.dart` | Prod/test prefs |
| `lib/core/providers/app_settings_notifier.dart` | Theme + keepScreenOn |
| `lib/core/util/lecture_app_link.dart` | Parse/validate Branch URLs |
| `lib/core/util/launch_lecture_session.dart` | `url_launcher` wrapper |
| `lib/features/home/presentation/home_screen.dart` | App bar + empty body |
| `lib/features/home/presentation/home_empty_body.dart` | CTA copy |
| `lib/features/home/presentation/qr_scan_screen.dart` | Camera scan |
| `lib/features/settings/presentation/settings_screen.dart` | Settings cards |
| `lib/features/settings/presentation/api_environment_selector.dart` | Advanced radios |
| `assets/branch-config.json` | Branch keys (placeholders) |
| `test/core/util/lecture_app_link_test.dart` | Unit tests |
| `test/features/home/home_screen_test.dart` | Widget smoke |

---

### Task 1: Dependencies and assets

**Files:**
- Modify: `pubspec.yaml`
- Create: `assets/branch-config.json`

- [ ] **Step 1:** Add dependencies and register assets:

```yaml
dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8
  flutter_riverpod: ^2.6.1
  shared_preferences: ^2.5.3
  flutter_branch_sdk: ^9.3.1
  mobile_scanner: ^7.0.1
  url_launcher: ^6.3.2
  wakelock_plus: ^1.3.2

flutter:
  uses-material-design: true
  assets:
    - assets/branch-config.json
```

- [ ] **Step 2:** Create `assets/branch-config.json` (replace keys from Branch Dashboard):

```json
{
  "liveKey": "key_live_REPLACE_ME",
  "testKey": "key_test_REPLACE_ME",
  "useTestInstance": false
}
```

- [ ] **Step 3:** Run `flutter pub get`

**Verify:** `flutter pub get` exits 0.

- [ ] **Step 4: Commit**

```bash
git add pubspec.yaml pubspec.lock assets/branch-config.json
git commit -m "chore: add dependencies for home, Branch, and settings"
```

---

### Task 2: Lecture app link helpers (TDD)

**Files:**
- Create: `lib/core/constants/lecture_app_link_constants.dart`
- Create: `lib/core/util/lecture_app_link.dart`
- Create: `test/core/util/lecture_app_link_test.dart`

- [ ] **Step 1: Write constants**

```dart
// lib/core/constants/lecture_app_link_constants.dart
const String kLectureViewerAppLinkHost = 'lectureviewer.app.link';

const String kExampleLectureAppLink =
    'https://lectureviewer.app.link/Il4A2yzQrPb?link_record=lt2srv.iar.kit.edu/mobile/session/tkq1221114001-lecture';
```

- [ ] **Step 2: Write failing tests**

```dart
// test/core/util/lecture_app_link_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lecture_viewer_v3/core/constants/lecture_app_link_constants.dart';
import 'package:lecture_viewer_v3/core/util/lecture_app_link.dart';

void main() {
  group('isLectureViewerAppLink', () {
    test('accepts example Branch link', () {
      final uri = Uri.parse(kExampleLectureAppLink);
      expect(isLectureViewerAppLink(uri), isTrue);
    });

    test('rejects wrong host', () {
      expect(
        isLectureViewerAppLink(Uri.parse('https://example.com/x?link_record=a')),
        isFalse,
      );
    });

    test('rejects missing link_record', () {
      expect(
        isLectureViewerAppLink(
          Uri.parse('https://lectureviewer.app.link/abc'),
        ),
        isFalse,
      );
    });
  });

  group('resolveSessionUrl', () {
    test('prepends https when no scheme', () {
      expect(
        resolveSessionUrl('lt2srv.iar.kit.edu/mobile/session/foo'),
        'https://lt2srv.iar.kit.edu/mobile/session/foo',
      );
    });

    test('keeps https link_record', () {
      expect(
        resolveSessionUrl('https://lt2srv.iar.kit.edu/mobile/session/foo'),
        'https://lt2srv.iar.kit.edu/mobile/session/foo',
      );
    });
  });

  group('linkRecordFromBranchSession', () {
    test('reads direct link_record key', () {
      expect(
        linkRecordFromBranchSession({'link_record': 'host/path'}),
        'host/path',
      );
    });

    test('parses link_record from canonical url', () {
      expect(
        linkRecordFromBranchSession({
          r'$canonical_url':
              'https://lectureviewer.app.link/x?link_record=host/path',
        }),
        'host/path',
      );
    });
  });
}
```

- [ ] **Step 3: Run tests — expect FAIL**

```bash
cd /Users/truong-d/Documents/code/lecture_viewer_v3
flutter test test/core/util/lecture_app_link_test.dart
```

Expected: compilation error — `lecture_app_link.dart` missing.

- [ ] **Step 4: Implement**

```dart
// lib/core/util/lecture_app_link.dart
import 'package:lecture_viewer_v3/core/constants/lecture_app_link_constants.dart';

bool isLectureViewerAppLink(Uri uri) {
  if (uri.scheme != 'https') return false;
  if (uri.host != kLectureViewerAppLinkHost) return false;
  if (uri.pathSegments.isEmpty || uri.pathSegments.every((s) => s.isEmpty)) {
    return false;
  }
  final linkRecord = uri.queryParameters['link_record'];
  return linkRecord != null && linkRecord.trim().isNotEmpty;
}

String? linkRecordFromAppLinkUri(Uri uri) {
  final value = uri.queryParameters['link_record']?.trim();
  if (value == null || value.isEmpty) return null;
  return value;
}

String? linkRecordFromBranchSession(Map<dynamic, dynamic> data) {
  final direct = data['link_record'];
  if (direct is String && direct.trim().isNotEmpty) return direct.trim();

  const urlKeys = [r'$canonical_url', '+url', r'$desktop_url', '~referring_link'];
  for (final key in urlKeys) {
    final raw = data[key];
    if (raw is! String) continue;
    final uri = Uri.tryParse(raw);
    final fromQuery = uri?.queryParameters['link_record']?.trim();
    if (fromQuery != null && fromQuery.isNotEmpty) return fromQuery;
  }
  return null;
}

String resolveSessionUrl(String linkRecord) {
  final trimmed = linkRecord.trim();
  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
    return trimmed;
  }
  return 'https://$trimmed';
}
```

- [ ] **Step 5: Run tests — expect PASS**

```bash
flutter test test/core/util/lecture_app_link_test.dart
```

- [ ] **Step 6: Commit**

```bash
git add lib/core/ test/core/
git commit -m "feat: add lecture app link parsing and validation"
```

---

### Task 3: Launch session URL

**Files:**
- Create: `lib/core/util/launch_lecture_session.dart`

- [ ] **Step 1: Implement**

```dart
import 'package:url_launcher/url_launcher.dart';

import 'package:lecture_viewer_v3/core/util/lecture_app_link.dart';

/// Opens resolved session URL in the system browser.
/// Returns false if launch failed.
Future<bool> handleLectureSessionLink(String linkRecord) async {
  final url = Uri.parse(resolveSessionUrl(linkRecord));
  return launchUrl(url, mode: LaunchMode.externalApplication);
}
```

- [ ] **Step 2: Analyze**

```bash
flutter analyze lib/core/util/launch_lecture_session.dart
```

- [ ] **Step 3: Commit**

```bash
git add lib/core/util/launch_lecture_session.dart
git commit -m "feat: launch resolved lecture session in external browser"
```

---

### Task 4: Core providers — prefs, API environment, app settings

**Files:**
- Create: `lib/core/constants/api_environment.dart`
- Create: `lib/core/providers/core_providers.dart`
- Create: `lib/core/providers/api_environment_notifier.dart`
- Create: `lib/core/providers/app_settings_notifier.dart`

- [ ] **Step 1:** Copy `lib/common/constants/api_environment.dart` from `app_2way_v3` into `lib/core/constants/api_environment.dart` (update package imports to `lecture_viewer_v3`).

- [ ] **Step 2:** Create `core_providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'sharedPreferencesProvider must be overridden in ProviderScope (see main.dart).',
  );
});
```

- [ ] **Step 3:** Create `api_environment_notifier.dart` (same pattern as `app_2way_v3/lib/common/providers/api_environment_notifier.dart`, package `lecture_viewer_v3`).

- [ ] **Step 4:** Create `app_settings_notifier.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lecture_viewer_v3/core/providers/core_providers.dart';

const String _kThemeModeKey = 'theme_mode_v1';
const String _kKeepScreenOnKey = 'keep_screen_on_v1';

final appSettingsProvider =
    NotifierProvider<AppSettingsNotifier, AppSettingsState>(
  AppSettingsNotifier.new,
);

class AppSettingsState {
  const AppSettingsState({
    required this.themeMode,
    required this.keepScreenOn,
  });

  final ThemeMode themeMode;
  final bool keepScreenOn;

  AppSettingsState copyWith({ThemeMode? themeMode, bool? keepScreenOn}) {
    return AppSettingsState(
      themeMode: themeMode ?? this.themeMode,
      keepScreenOn: keepScreenOn ?? this.keepScreenOn,
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
    );
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
```

- [ ] **Step 5: Analyze**

```bash
flutter analyze lib/core/
```

- [ ] **Step 6: Commit**

```bash
git add lib/core/
git commit -m "feat: add Riverpod providers for settings and API environment"
```

---

### Task 5: App shell — main, MaterialApp, wakelock

**Files:**
- Modify: `lib/main.dart` (replace counter template)
- Create: `lib/app/lecture_viewer_app.dart`
- Create: `lib/app/wakelock_lifecycle_binding.dart`

- [ ] **Step 1: `main.dart`**

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_branch_sdk/flutter_branch_sdk.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lecture_viewer_v3/app/branch_session_listener.dart';
import 'package:lecture_viewer_v3/app/lecture_viewer_app.dart';
import 'package:lecture_viewer_v3/app/wakelock_lifecycle_binding.dart';
import 'package:lecture_viewer_v3/core/providers/core_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FlutterBranchSdk.init();
  if (kDebugMode) {
    FlutterBranchSdk.validateSDKIntegration();
  }
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const WakelockLifecycleBinding(
        child: BranchSessionListener(
          child: LectureViewerApp(),
        ),
      ),
    ),
  );
}
```

- [ ] **Step 2: `lecture_viewer_app.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lecture_viewer_v3/core/providers/app_settings_notifier.dart';
import 'package:lecture_viewer_v3/features/home/presentation/home_screen.dart';
import 'package:lecture_viewer_v3/features/settings/presentation/settings_screen.dart';

class LectureViewerApp extends ConsumerWidget {
  const LectureViewerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    return MaterialApp(
      title: 'Lecture Viewer',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: settings.themeMode,
      home: const HomeScreen(),
      onGenerateRoute: (settings) {
        if (settings.name == '/settings') {
          return MaterialPageRoute<void>(
            builder: (_) => const SettingsScreen(),
            settings: settings,
          );
        }
        return null;
      },
    );
  }
}
```

- [ ] **Step 3: `wakelock_lifecycle_binding.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'package:lecture_viewer_v3/core/providers/app_settings_notifier.dart';

class WakelockLifecycleBinding extends ConsumerStatefulWidget {
  const WakelockLifecycleBinding({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<WakelockLifecycleBinding> createState() =>
      _WakelockLifecycleBindingState();
}

class _WakelockLifecycleBindingState
    extends ConsumerState<WakelockLifecycleBinding>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _syncWakelock();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _syncWakelock(lifecycle: state);
  }

  @override
  void didUpdateWidget(covariant WakelockLifecycleBinding oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncWakelock();
  }

  void _syncWakelock({AppLifecycleState? lifecycle}) {
    final keepOn = ref.read(appSettingsProvider).keepScreenOn;
    final resumed = (lifecycle ?? WidgetsBinding.instance.lifecycleState) ==
        AppLifecycleState.resumed;
    if (keepOn && resumed) {
      WakelockPlus.enable();
    } else {
      WakelockPlus.disable();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(appSettingsProvider.select((s) => s.keepScreenOn), (_, __) {
      _syncWakelock();
    });
    return widget.child;
  }
}
```

- [ ] **Step 4: Commit** (after Task 6 adds `BranchSessionListener` — or stub empty listener now)

For this task, create a minimal stub `branch_session_listener.dart` that only passes `child` through, then replace in Task 6.

- [ ] **Step 5: Analyze**

```bash
flutter analyze lib/main.dart lib/app/
```

---

### Task 6: Branch session listener

**Files:**
- Create: `lib/app/branch_session_listener.dart`

- [ ] **Step 1: Implement**

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_branch_sdk/flutter_branch_sdk.dart';

import 'package:lecture_viewer_v3/core/util/launch_lecture_session.dart';
import 'package:lecture_viewer_v3/core/util/lecture_app_link.dart';

class BranchSessionListener extends StatefulWidget {
  const BranchSessionListener({required this.child, super.key});

  final Widget child;

  @override
  State<BranchSessionListener> createState() => _BranchSessionListenerState();
}

class _BranchSessionListenerState extends State<BranchSessionListener> {
  StreamSubscription<Map<dynamic, dynamic>>? _subscription;
  String? _lastLinkRecord;
  DateTime? _lastHandledAt;

  @override
  void initState() {
    super.initState();
    _subscription = FlutterBranchSdk.listSession().listen(
      _onSession,
      onError: (_) {},
    );
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  Future<void> _onSession(Map<dynamic, dynamic> data) async {
    if (data['+clicked_branch_link'] != true) return;
    final linkRecord = linkRecordFromBranchSession(data);
    if (linkRecord == null) {
      _showMessage('Missing session link');
      return;
    }
    if (_isDuplicate(linkRecord)) return;
    final ok = await handleLectureSessionLink(linkRecord);
    if (!mounted) return;
    if (!ok) _showMessage('Could not open session');
  }

  bool _isDuplicate(String linkRecord) {
    final now = DateTime.now();
    if (_lastLinkRecord == linkRecord &&
        _lastHandledAt != null &&
        now.difference(_lastHandledAt!) < const Duration(seconds: 2)) {
      return true;
    }
    _lastLinkRecord = linkRecord;
    _lastHandledAt = now;
    return false;
  }

  void _showMessage(String text) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
```

Add `import 'dart:async';` and use `unawaited` from `dart:async` or cancel synchronously in dispose.

- [ ] **Step 2: Commit**

```bash
git add lib/app/branch_session_listener.dart lib/main.dart
git commit -m "feat: handle Branch deep links and open session URL"
```

---

### Task 7: Home screen + QR scanner

**Files:**
- Create: `lib/features/home/presentation/home_screen.dart`
- Create: `lib/features/home/presentation/home_empty_body.dart`
- Create: `lib/features/home/presentation/qr_scan_screen.dart`

- [ ] **Step 1: `home_screen.dart`**

```dart
import 'package:flutter/material.dart';

import 'package:lecture_viewer_v3/features/home/presentation/home_empty_body.dart';
import 'package:lecture_viewer_v3/features/home/presentation/qr_scan_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _openScanner(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const QrScanScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
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
      body: HomeEmptyBody(onScanPressed: () => _openScanner(context)),
    );
  }
}
```

- [ ] **Step 2: `home_empty_body.dart`**

```dart
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
              'The session opens in your browser.',
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
```

- [ ] **Step 3: `qr_scan_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:lecture_viewer_v3/core/util/launch_lecture_session.dart';
import 'package:lecture_viewer_v3/core/util/lecture_app_link.dart';

class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _handling = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handling) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null) return;
    final uri = Uri.tryParse(raw.trim());
    if (uri == null || !isLectureViewerAppLink(uri)) {
      _showSnack('Invalid lecture link');
      return;
    }
    final linkRecord = linkRecordFromAppLinkUri(uri);
    if (linkRecord == null) {
      _showSnack('Missing session link');
      return;
    }
    _handling = true;
    final ok = await handleLectureSessionLink(linkRecord);
    if (!mounted) return;
    _handling = false;
    if (ok) {
      Navigator.of(context).pop();
    } else {
      _showSnack('Could not open session');
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
      ),
      body: MobileScanner(controller: _controller, onDetect: _onDetect),
    );
  }
}
```

- [ ] **Step 4: Analyze + commit**

```bash
flutter analyze lib/features/home/
git add lib/features/home/
git commit -m "feat: add home screen with QR scanner"
```

---

### Task 8: Settings screen

**Files:**
- Create: `lib/features/settings/presentation/settings_screen.dart`
- Create: `lib/features/settings/presentation/api_environment_selector.dart`
- Create: `lib/features/settings/presentation/settings_section_card.dart`

- [ ] **Step 1:** Copy `ApiEnvironmentSelector` from `app_2way_v3/lib/features/settings/ui/api_environment_selector.dart` → `lib/features/settings/presentation/api_environment_selector.dart` (update imports).

- [ ] **Step 2:** Create `settings_section_card.dart` — extract `_SettingsSectionCard` and `_CollapsibleSettingsSectionCard` from `app_2way_v3` `settings_screen.dart` as public widgets in this file.

- [ ] **Step 3:** Create `settings_screen.dart` with three sections:
  - **Display:** `RadioGroup` / `RadioListTile` for Light, Dark, System → `appSettingsNotifier.setThemeMode`
  - **Device:** `SwitchListTile` “Keep screen on” → `setKeepScreenOn`
  - **Advanced:** collapsible card with `ApiEnvironmentSelector`

Mirror padding and card styling from `app_2way_v3` `SettingsScreen`.

- [ ] **Step 4: Analyze + commit**

```bash
flutter analyze lib/features/settings/
git add lib/features/settings/
git commit -m "feat: add settings screen with theme, wakelock, and API env"
```

---

### Task 9: Platform — Branch native + permissions

**Files:**
- Modify: `android/app/src/main/AndroidManifest.xml`
- Modify: `ios/Runner/Info.plist`
- Modify: `ios/Runner/Runner.entitlements` (create if missing)

- [ ] **Step 1: Android** — inside `<activity android:name=".MainActivity">`:

```xml
<meta-data android:name="flutter_deeplinking_enabled" android:value="false" />
```

Add Branch intent filters and `io.branch.sdk.BranchKey` metadata per [Branch Android Configure App](https://help.branch.io/developers-hub/docs/android-basic-integration#4-configure-app). Use keys from `branch-config.json` / dashboard.

Add before `<application>`:

```xml
<uses-permission android:name="android.permission.CAMERA" />
```

Add to `<queries>` for https browsing if needed by `url_launcher`.

- [ ] **Step 2: iOS `Info.plist`**

```xml
<key>FlutterDeepLinkingEnabled</key>
<false/>
<key>NSCameraUsageDescription</key>
<string>Scan lecture QR codes</string>
```

Add Branch keys (`branch_key`, `branch_universal_link_domains`) per Branch iOS basic integration docs.

- [ ] **Step 3: iOS entitlements** — Associated Domains:

```xml
<key>com.apple.developer.associated-domains</key>
<array>
  <string>applinks:lectureviewer.app.link</string>
</array>
```

Enable capability in Xcode for Runner target.

- [ ] **Step 4: Manual verify on device**

```bash
flutter run
# Debug: check validateSDKIntegration() toast/log output
```

- [ ] **Step 5: Commit**

```bash
git add android/ ios/
git commit -m "chore: configure Branch deep links and camera permissions"
```

---

### Task 10: Widget smoke test

**Files:**
- Modify: `test/widget_test.dart` or create `test/features/home/home_screen_test.dart`

- [ ] **Step 1: Write test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lecture_viewer_v3/app/lecture_viewer_app.dart';
import 'package:lecture_viewer_v3/core/providers/core_providers.dart';

void main() {
  testWidgets('home shows scan and settings', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const LectureViewerApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Lectures'), findsOneWidget);
    expect(find.text('Scan QR'), findsOneWidget);
    expect(find.byIcon(Icons.settings), findsOneWidget);
  });
}
```

Note: Skip `BranchSessionListener` / `FlutterBranchSdk.init` in test by testing `HomeScreen` directly if Branch init fails in CI:

```dart
// Alternative: pump HomeScreen only
import 'package:lecture_viewer_v3/features/home/presentation/home_screen.dart';
// ...
child: const MaterialApp(home: HomeScreen()),
```

- [ ] **Step 2: Run**

```bash
flutter test
```

- [ ] **Step 3: Commit**

```bash
git add test/
git commit -m "test: add home screen widget smoke test"
```

---

### Task 11: Completion

- [ ] Run `flutter analyze`
- [ ] Run `flutter test`
- [ ] Delete old counter code remnants if any remain in `lib/main.dart`
- [ ] Update `README.md` one paragraph: Branch keys setup, `flutter run`, manual test steps
- [ ] Final commit if README changed

```bash
flutter analyze && flutter test
git add README.md
git commit -m "docs: document Branch setup and manual test steps"
```

---

## Spec coverage checklist

| Spec requirement | Task |
|------------------|------|
| QR only `lectureviewer.app.link` + `link_record` | Task 2, 7 |
| External browser for session | Task 3 |
| Branch `listSession` deep links | Task 6 |
| Home app bar QR + settings | Task 7 |
| Empty state CTA | Task 7 |
| Theme light/dark/system | Task 4, 8 |
| Keep screen on while app foreground | Task 4, 5 |
| API environment Advanced | Task 4, 8 |
| `flutter_branch_sdk` native config | Task 9 |
| Unit tests for link helpers | Task 2 |
| iOS + Android only | Task 9 |

## Manual test plan (device)

1. Replace Branch keys in `assets/branch-config.json`.
2. `flutter run` on iOS and Android.
3. Scan example QR → session opens in Safari/Chrome.
4. Tap Branch link in Messages → app opens → session opens in browser.
5. Toggle keep screen on → screen stays awake on home; lock on background.
6. Change theme → UI updates.
7. Change API environment → subtitle updates (no network yet).
