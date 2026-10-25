# Home & Settings — Design Spec

**Date:** 2026-05-18 (updated)  
**Project:** `lecture_viewer_v3`  
**Status:** Approved in brainstorming; amended for Branch.io links + SDK

## Goal

Deliver the first usable shell of the lecture viewer app: a home screen with QR-based lecture entry, **Branch.io** deep-link handling for `lectureviewer.app.link`, a settings screen, and shared infrastructure (theme, wakelock, API environment) aligned with `app_2way_v3` patterns. Meeting history/list is explicitly deferred.

## Decisions (brainstorming)

| Topic | Decision |
|-------|----------|
| After QR / deep link | Resolve `link_record` → open **session URL** in **system browser** — **not** in-app WebView |
| Link host | **`lectureviewer.app.link`** (Branch domain) with required `link_record` query param |
| Deep links | **`flutter_branch_sdk`** — Branch owns App Links / Universal Links for the domain |
| QR scan | `mobile_scanner` reads Branch URL string; validate + parse `link_record` locally (same resolver as Branch session) |
| Platforms | **iOS + Android** only (v1) |
| API environment | Same model as `app_2way_v3`; **no HTTP calls in v1** |
| Keep screen on | While app is in **foreground** when setting is on |
| Meeting list | **Out of scope** |

## Lecture app link format

### Example

```text
https://lectureviewer.app.link/Il4A2yzQrPb?link_record=lt2srv.iar.kit.edu/mobile/session/tkq1221114001-lecture
```

| Part | Rule |
|------|------|
| Scheme | `https` only |
| Host | Exactly `lectureviewer.app.link` |
| Path | One or more non-empty segments (Branch short code; opaque to app) |
| Query | **Required** non-empty `link_record` |

### Resolving `link_record` → browser URL

The app does **not** open the Branch link in the browser. It extracts `link_record` and launches the **session** URL:

| `link_record` value | Resolved launch URL |
|---------------------|---------------------|
| `lt2srv.iar.kit.edu/mobile/session/...` (no scheme) | `https://` + value |
| `https://...` | use as-is |

```text
link_record=lt2srv.iar.kit.edu/mobile/session/tkq1221114001-lecture
→ https://lt2srv.iar.kit.edu/mobile/session/tkq1221114001-lecture
```

### Core helpers (`lib/core/util/lecture_app_link.dart`)

| Function | Purpose |
|----------|---------|
| `isLectureViewerAppLink(Uri uri)` | Host/path/query validation for scanned URLs |
| `linkRecordFromAppLinkUri(Uri uri)` | Read `link_record` query param |
| `linkRecordFromBranchSession(Map data)` | Read `link_record` from Branch session; fallback parse from `$canonical_url` / referring URL in session |
| `resolveSessionUrl(String linkRecord)` | Normalize to `https://…` |
| `handleLectureSessionLink(String linkRecord)` | resolve + `url_launcher` external |

## Entry paths

### 1. QR scan (`mobile_scanner`)

1. Decode QR string → `Uri.tryParse`.
2. If `!isLectureViewerAppLink(uri)` → snackbar “Invalid lecture link”, stay on scanner.
3. `linkRecord = linkRecordFromAppLinkUri(uri)`; if empty → “Missing session link”.
4. `handleLectureSessionLink(linkRecord)` → pop scanner on success.

No Branch API call required for QR (payload is the full Branch URL on the code).

### 2. Branch deep link (tap link — app open or cold start)

Use **`flutter_branch_sdk`** (`^9.3.1` or current stable).

```dart
FlutterBranchSdk.listSession().listen((data) {
  if (data['+clicked_branch_link'] != true) return;
  final linkRecord = linkRecordFromBranchSession(data);
  if (linkRecord == null || linkRecord.isEmpty) { /* snackbar */ return; }
  handleLectureSessionLink(linkRecord);
});
```

- Subscribe once at app root (`BranchSessionListener` widget).
- Deduplicate: ignore repeated session callbacks for the same `link_record` within ~2s.
- **iOS install edge case:** if `+clicked_branch_link` is false on first session, use `getFirstReferringParams()` per Branch docs when needed.

### 3. Unified outcome

Both paths end at **`handleLectureSessionLink`** → external browser with resolved session URL.

## Branch.io integration

### Dashboard (required before store builds)

1. Register iOS + Android apps in [Branch Dashboard](https://dashboard.branch.io).
2. Confirm **Link Domain** `lectureviewer.app.link` is linked to this app.
3. Ensure link template / quick links pass **`link_record`** as a query parameter (or custom control param mirrored as `link_record` in session data — verify in Branch Link Debugger).
4. Run **Link Control Panel** / SDK Integration Tester after native setup.

### Flutter package

| Package | Purpose |
|---------|---------|
| `flutter_branch_sdk` | Session init, deep link callbacks, domain routing |
| `mobile_scanner` | QR camera |
| `url_launcher` | Open resolved session URL |
| `flutter_riverpod`, `shared_preferences`, `wakelock_plus` | (unchanged) |

**Remove:** `app_links` (Branch replaces it).

### Config files

| File | Purpose |
|------|---------|
| `assets/branch-config.json` | `liveKey`, `testKey`, `useTestInstance` (keys from dashboard; **do not commit secrets** if repo is public — use env/CI injection or gitignored local overlay) |
| `ios/Runner/Info.plist` | Branch keys, `FlutterDeepLinkingEnabled` = **false**, camera usage |
| `android/.../AndroidManifest.xml` | Branch intent filters + metadata per [Android basic integration](https://help.branch.io/developers-hub/docs/android-basic-integration); `flutter_deeplinking_enabled` = **false** |
| iOS Associated Domains | `applinks:lectureviewer.app.link` (Branch docs) |

Branch hosts **AASA** and **assetlinks** for `*.app.link` domains — **do not** maintain separate `app_links` verification files unless Branch dashboard directs otherwise.

### App bootstrap (`main.dart`)

```dart
WidgetsFlutterBinding.ensureInitialized();
// SharedPreferences, ProviderScope ...
await FlutterBranchSdk.init(); // if using deferInitForPluginRuntime on iOS, init here after ATT if needed
runApp(...);
```

- Debug only: `FlutterBranchSdk.validateSDKIntegration()` (strip/ guard in release).
- Wrap app with `BranchSessionListener` (subscribes to `listSession`).

### Architecture (updated)

```text
lib/
  main.dart
  app/
    lecture_viewer_app.dart
    wakelock_lifecycle_binding.dart
    branch_session_listener.dart   # listSession → handleLectureSessionLink
  core/
    util/
      lecture_app_link.dart
      launch_lecture_session.dart
    ...
  features/home/presentation/
    qr_scan_screen.dart            # mobile_scanner only
```

## App shell & navigation

(Unchanged.)

- Home: QR leading, Settings action, empty state + Scan QR CTA
- Routes: `/`, `/settings`

## Settings screen

(Unchanged: theme, keep screen on, Advanced API environment UI-only.)

## Wakelock lifecycle

(Unchanged.)

## Error handling

| Case | UX |
|------|-----|
| Invalid / non-Branch QR URL | “Invalid lecture link” |
| Missing `link_record` (QR or Branch session) | “Missing session link” |
| Branch session without click | No action (ignore) |
| `launchUrl` fails | “Could not open session” |
| Camera denied | Guidance + pop scanner |

## Testing

- **Unit:** `isLectureViewerAppLink`, `resolveSessionUrl`, `linkRecordFromBranchSession` (fixture maps mimicking Branch).
- **Manual:** `FlutterBranchSdk.validateSDKIntegration()` on device.
- **Manual:** Tap Branch link from Notes/Messages → app opens → session page opens in browser.
- **Manual:** Scan same URL QR → same browser destination.
- **Branch Dashboard:** Link Debugger with example URL + `link_record`.

## Out of scope (v1)

- In-app WebView
- Meeting list / scan history
- `app_links` package
- Branch QR code **generation** (only scan existing codes)
- Desktop / Web Branch init
- Custom assetlinks/AASA files (Branch-managed)

## Prerequisites (team)

- Branch live/test keys and dashboard access
- Confirm `link_record` appears in `listSession` payload for production links (adjust Branch link template if not)

## Future work

- Meeting list (persist `link_record` or session id from Branch data)
- HTTP APIs via `apiEnvironmentProvider`

## Doc drift

- `docs/1-home.md`: external browser for session URL; Branch domain + SDK.
