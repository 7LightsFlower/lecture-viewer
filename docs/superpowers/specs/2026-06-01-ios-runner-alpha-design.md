# iOS Runner-alpha Design

Date: 2026-06-01
Project: `lecture_viewer_v3`
Scope: Rebuild and standardize iOS `Runner-alpha` target using approach A (native target/scheme).

## 1) Goal

Provide two iOS app variants that can be built directly from Xcode with stable, machine-independent configuration:

- `product`: App Name `Lecture Viewer`, Bundle ID `com.vais.lectureTranslate`
- `alpha`: App Name `Lecture Viewer Alpha`, Bundle ID `com.vais.lectureTranslate.alpha`

Both variants use the same versioning policy (shared version), while app identity differs.

## 2) Current Issues

Current iOS setup already includes a `Runner-alpha` target, but it is not fully standardized:

- `INFOPLIST_FILE` for alpha points to `Runner copy-Info.plist` (temporary naming).
- Some references are absolute-path style in project structure, which is fragile across machines.
- Configuration consistency between `Runner` and `Runner-alpha` needs explicit normalization.

These issues increase risk of broken archive/build on different developer machines.

## 3) Architecture Decision

Use native multi-target setup in Xcode:

- Keep target `Runner` for product.
- Keep target `Runner-alpha` for alpha.
- Keep dedicated schemes `Runner` and `Runner-alpha`.

Reasoning:

- Best compatibility with Xcode build/archive workflows.
- Clear separation for signing, provisioning, and app identity.
- Minimal cognitive overhead for developers building via Xcode UI.

## 4) Configuration Design

### 4.1 Target Identity

`Runner` target:

- `PRODUCT_BUNDLE_IDENTIFIER = com.vais.lectureTranslate`
- App display name: `Lecture Viewer`

`Runner-alpha` target:

- `PRODUCT_BUNDLE_IDENTIFIER = com.vais.lectureTranslate.alpha`
- App display name: `Lecture Viewer Alpha`

### 4.2 Build Configurations

For `Runner-alpha`, keep all 3 configurations:

- `Debug`
- `Release`
- `Profile`

All 3 configs must use the same alpha identity settings (bundle id + display name mapping), matching behavior across run and archive paths.

### 4.3 Info.plist Strategy

Standardize alpha plist:

- Replace temporary `Runner copy-Info.plist` with stable file name in repo, for example: `Runner/Info-Alpha.plist`.
- Ensure `INFOPLIST_FILE` points to repo-relative path only.
- Set `CFBundleDisplayName` in alpha plist to `Lecture Viewer Alpha`.

Product target keeps existing `Runner/Info.plist` with `Lecture Viewer`.

### 4.4 Versioning Policy

Use shared version for both product and alpha:

- Same `MARKETING_VERSION`
- Same `CURRENT_PROJECT_VERSION`

Only name and bundle id differ between variants.

## 5) Data Flow / Build Flow

Xcode selection flow:

1. Developer selects scheme `Runner` or `Runner-alpha`.
2. Xcode resolves target-specific build settings.
3. Target-specific plist provides display name.
4. Output app artifact carries correct bundle id + app name.

No custom script layer is required for iOS build in this phase.

## 6) Error Handling and Guardrails

- Remove absolute-path plist references to prevent machine-specific failures.
- Keep target settings explicit in `project.pbxproj` for deterministic behavior.
- Ensure both schemes can independently Build/Run/Archive.

## 7) Validation Plan

Definition of done:

1. Xcode shows both schemes: `Runner` and `Runner-alpha`.
2. `Runner-alpha` builds and runs in Debug.
3. `Runner-alpha` archives in Release.
4. Installed alpha app shows:
   - Name: `Lecture Viewer Alpha`
   - Bundle ID: `com.vais.lectureTranslate.alpha`
5. Product app remains:
   - Name: `Lecture Viewer`
   - Bundle ID: `com.vais.lectureTranslate`
6. No `Runner copy-Info.plist` dependency remains in alpha target settings.
7. No absolute-path plist configuration remains.

## 8) Out of Scope

- Android flavor implementation details.
- CI pipeline or fastlane automation changes.
- Runtime feature-flag behavior differences between product and alpha.

## 9) Implementation Boundary

This spec only defines iOS target/scheme/configuration structure.  
Implementation plan will detail exact file edits (`project.pbxproj`, plist files, and scheme/config alignment) and verification steps.
