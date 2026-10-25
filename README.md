# lecture_viewer_v3

Flutter lecture viewer shell: QR scan and Branch deep links for `lectureviewer.app.link`, opening resolved session URLs in the system browser.

## Setup

1. Install [FVM](https://fvm.app) (`dart pub global activate fvm`) and ensure `~/.pub-cache/bin` is on your `PATH`.
2. From the project root: `fvm install` then `fvm flutter pub get`.
3. Copy Branch live/test keys from the [Branch Dashboard](https://dashboard.branch.io) into `assets/branch-config.json`.
4. In Xcode, enable **Associated Domains** for the Runner target (`applinks:lectureviewer.app.link`). `ios/Runner/Runner.entitlements` is provided as a starting point.
5. `fvm flutter run` (iOS or Android device recommended for camera and deep links)

This project pins Flutter **3.41.9** in `.fvmrc` (same as `app_2way_v3`). Use `fvm flutter` / `fvm dart` instead of a global `flutter` binary so everyone builds with the same SDK.

## Manual checks

- Scan a lecture QR encoding a `https://lectureviewer.app.link/...?link_record=...` URL.
- Tap the same link from Messages/Notes — app should open and launch the session in the browser.
- Debug builds call `FlutterBranchSdk.validateSDKIntegration()` on startup.

## Tests

```bash
fvm flutter test

fvm flutter analyze
```
