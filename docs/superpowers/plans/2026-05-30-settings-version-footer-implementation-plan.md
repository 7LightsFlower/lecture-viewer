# Settings Version Footer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show `Version x.y.z (build)` at the bottom of the Settings screen, scrolled with list content, per `docs/superpowers/specs/2026-05-30-settings-version-footer-design.md`.

**Architecture:** Add `package_info_plus` dependency. New `SettingsVersionFooter` `StatefulWidget` loads `PackageInfo.fromPlatform()` once in `initState`, formats the label, and renders muted centered text. Append widget as last child of Settings `ListView`.

**Tech stack:** Flutter 3.10+, `package_info_plus ^8.x`.

---

## File map

| Path | Action | Responsibility |
|------|--------|----------------|
| `pubspec.yaml` | Modify | Add `package_info_plus` dependency |
| `lib/features/settings/presentation/settings_version_footer.dart` | Create | Async version load + footer UI |
| `lib/features/settings/presentation/settings_screen.dart` | Modify | Append footer to `ListView` |

---

### Task 1: Add `package_info_plus` dependency

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1:** Add under `dependencies:` (after existing entries, e.g. after `wakelock_plus`):

```yaml
  package_info_plus: ^8.3.0
```

- [ ] **Step 2:** Run pub get

Run: `cd /Users/macbook/Works/Lecture_Translation_Alex/lecture_viewer_v3 && flutter pub get`

Expected: exit code 0; `package_info_plus` resolved in `pubspec.lock`.

---

### Task 2: Create `SettingsVersionFooter` widget

**Files:**
- Create: `lib/features/settings/presentation/settings_version_footer.dart`

- [ ] **Step 1:** Create the widget file with full content:

```dart
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
        _label = 'Version ${info.version} (${info.buildNumber})';
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
```

- [ ] **Step 2:** Analyze the new file

Run: `cd /Users/macbook/Works/Lecture_Translation_Alex/lecture_viewer_v3 && dart analyze lib/features/settings/presentation/settings_version_footer.dart`

Expected: no issues.

---

### Task 3: Wire footer into Settings screen

**Files:**
- Modify: `lib/features/settings/presentation/settings_screen.dart`

- [ ] **Step 1:** Add import:

```dart
import 'package:lecture_viewer_v3/features/settings/presentation/settings_version_footer.dart';
```

- [ ] **Step 2:** Append footer as last `ListView` child (after `CollapsibleSettingsSectionCard` for Advanced):

```dart
          CollapsibleSettingsSectionCard(
            title: 'Advanced',
            subtitle: apiEnvironment.settingsLabel,
            children: const [ApiEnvironmentSelector()],
          ),
          const SettingsVersionFooter(),
```

- [ ] **Step 3:** Analyze settings feature

Run: `cd /Users/macbook/Works/Lecture_Translation_Alex/lecture_viewer_v3 && dart analyze lib/features/settings/`

Expected: no issues.

---

### Task 4: Manual verification

- [ ] **Step 1:** Run app on simulator or device

Run: `cd /Users/macbook/Works/Lecture_Translation_Alex/lecture_viewer_v3 && flutter run`

- [ ] **Step 2:** Open Settings from home app bar → scroll to bottom

Expected:
- Muted centered text, e.g. `Version 1.2.7 (47)` matching `pubspec.yaml` version/build.
- No flash of placeholder while loading.
- Text scrolls with list (not pinned to viewport bottom).

- [ ] **Step 3:** Toggle light/dark theme in Settings

Expected: footer text remains readable (`onSurfaceVariant`).

---

## Spec coverage checklist

| Spec requirement | Task |
|------------------|------|
| Format `Version x.y.z (n)` | Task 2 |
| Last child of Settings `ListView` | Task 3 |
| `package_info_plus` runtime source | Tasks 1–2 |
| Hidden loading/error states | Task 2 |
| Muted centered `bodySmall` styling | Task 2 |
| No Riverpod provider | Task 2 |
| Manual iOS/Android check | Task 4 |
