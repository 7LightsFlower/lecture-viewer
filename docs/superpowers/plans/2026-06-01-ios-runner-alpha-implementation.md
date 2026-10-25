# iOS Runner-alpha Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild and standardize iOS `Runner-alpha` so Xcode can reliably Build/Run/Archive `product` and `alpha` variants with correct app name and bundle id.

**Architecture:** Keep native multi-target structure (`Runner` for product, `Runner-alpha` for alpha). Normalize `Runner-alpha` build settings in `project.pbxproj`, replace temporary alpha plist with stable repo-relative plist, and verify both schemes end-to-end in Xcode/CLI. Keep shared versioning between both variants; only app identity differs.

**Tech Stack:** Flutter iOS, Xcode project (`project.pbxproj`), plist configuration, `xcodebuild`.

---

### Task 1: Snapshot Current iOS Target State

**Files:**
- Modify: None
- Verify: `ios/Runner.xcodeproj/project.pbxproj`

- [ ] **Step 1: Confirm current references for alpha plist and bundle id**

Run:
```bash
rg -n "Runner copy-Info.plist|PRODUCT_BUNDLE_IDENTIFIER|INFOPLIST_FILE|Runner-alpha" ios/Runner.xcodeproj/project.pbxproj
```
Expected: output includes `Runner copy-Info.plist` and `com.vais.lectureTranslate.alpha`.

- [ ] **Step 2: Confirm currently tracked plist files**

Run:
```bash
ls ios/Runner
```
Expected: `Info.plist` exists; alpha dedicated plist may be missing.

- [ ] **Step 3: Commit checkpoint (no code change, optional)**

Run:
```bash
git status --short
```
Expected: shows current working state before edits.

---

### Task 2: Create Stable Alpha Info.plist

**Files:**
- Create: `ios/Runner/Info-Alpha.plist`
- Reference: `ios/Runner/Info.plist`

- [ ] **Step 1: Create `Info-Alpha.plist` from existing product plist**

Run:
```bash
cp ios/Runner/Info.plist ios/Runner/Info-Alpha.plist
```
Expected: `ios/Runner/Info-Alpha.plist` created.

- [ ] **Step 2: Set alpha display name**

Edit `ios/Runner/Info-Alpha.plist` and ensure:
```xml
<key>CFBundleDisplayName</key>
<string>Lecture Viewer Alpha</string>
```
If key does not exist, add it under top-level `<dict>`.

- [ ] **Step 3: Keep product display name unchanged**

Verify `ios/Runner/Info.plist` still maps to:
```xml
<key>CFBundleDisplayName</key>
<string>Lecture Viewer</string>
```
If key is absent in product plist, set in target build setting using:
```text
INFOPLIST_KEY_CFBundleDisplayName = Lecture Viewer
```

- [ ] **Step 4: Verify plist syntax**

Run:
```bash
plutil -lint ios/Runner/Info-Alpha.plist && plutil -lint ios/Runner/Info.plist
```
Expected: both return `OK`.

- [ ] **Step 5: Commit**

Run:
```bash
git add ios/Runner/Info-Alpha.plist
git commit -m "ios: add stable Info-Alpha plist for Runner-alpha"
```

---

### Task 3: Normalize Runner-alpha Build Settings in Xcode Project

**Files:**
- Modify: `ios/Runner.xcodeproj/project.pbxproj`
- Verify: `ios/Runner/Info-Alpha.plist`

- [ ] **Step 1: Replace temporary plist reference with stable file**

In `ios/Runner.xcodeproj/project.pbxproj`, for `Runner-alpha` `Debug/Release/Profile` build configs, change:
```text
INFOPLIST_FILE = "Runner copy-Info.plist";
```
to:
```text
INFOPLIST_FILE = Runner/Info-Alpha.plist;
```

- [ ] **Step 2: Enforce alpha bundle id for all alpha configs**

Ensure all `Runner-alpha` build configs include:
```text
PRODUCT_BUNDLE_IDENTIFIER = com.vais.lectureTranslate.alpha;
```

- [ ] **Step 3: Ensure alpha app name is stable**

For all `Runner-alpha` configs, add:
```text
INFOPLIST_KEY_CFBundleDisplayName = "Lecture Viewer Alpha";
```
This guards against accidental plist drift.

- [ ] **Step 4: Keep shared versioning policy**

Ensure `Runner-alpha` and `Runner` use aligned:
```text
MARKETING_VERSION = <same value>;
CURRENT_PROJECT_VERSION = <same value>;
```
Use `Runner` values as source of truth.

- [ ] **Step 5: Remove obsolete plist file references**

In `project.pbxproj`, remove stale file reference entries for `Runner copy-Info.plist` if no longer used by any build config.

- [ ] **Step 6: Verify no absolute-path or old plist dependency remains**

Run:
```bash
rg -n "/Users/|Runner copy-Info.plist" ios/Runner.xcodeproj/project.pbxproj
```
Expected: no matches.

- [ ] **Step 7: Commit**

Run:
```bash
git add ios/Runner.xcodeproj/project.pbxproj
git commit -m "ios: standardize Runner-alpha target settings and plist path"
```

---

### Task 4: Verify Scheme Build and Archive Behavior

**Files:**
- Modify: None
- Verify: `ios/Runner.xcodeproj/project.pbxproj`, `ios/Runner/Info-Alpha.plist`

- [ ] **Step 1: Build product scheme (Debug simulator)**

Run:
```bash
xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -configuration Debug -sdk iphonesimulator build
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 2: Build alpha scheme (Debug simulator)**

Run:
```bash
xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner-alpha -configuration Debug -sdk iphonesimulator build
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Archive alpha scheme (Release)**

Run:
```bash
xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner-alpha -configuration Release -sdk iphoneos -destination "generic/platform=iOS" archive -archivePath build/Runner-alpha.xcarchive
```
Expected: archive succeeds without plist path or signing config mismatch errors.

- [ ] **Step 4: Validate built alpha app metadata**

Run:
```bash
/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" build/Runner-alpha.xcarchive/Products/Applications/Runner-alpha.app/Info.plist
/usr/libexec/PlistBuddy -c "Print :CFBundleDisplayName" build/Runner-alpha.xcarchive/Products/Applications/Runner-alpha.app/Info.plist
```
Expected:
- Bundle identifier is `com.vais.lectureTranslate.alpha`
- Display name is `Lecture Viewer Alpha`

- [ ] **Step 5: Commit verification note (if docs updated)**

If verification commands or caveats are documented, commit those documentation updates:
```bash
git add <doc-paths>
git commit -m "docs: add iOS alpha scheme verification notes"
```

---

### Task 5: Final Regression Check and Handoff

**Files:**
- Modify: Optional docs only
- Verify: working tree

- [ ] **Step 1: Validate no accidental changes outside iOS scope**

Run:
```bash
git status --short
git diff --name-only HEAD~3..HEAD
```
Expected: only iOS config/plist (and optional docs) changed.

- [ ] **Step 2: Summarize achieved done criteria against spec**

Create short checklist in PR/notes:
```text
- Runner + Runner-alpha schemes available
- Runner-alpha Debug build pass
- Runner-alpha Release archive pass
- Alpha app name/bundle id correct
- Product app name/bundle id unchanged
- No Runner copy-Info.plist dependency
- No absolute-path plist config
```

- [ ] **Step 3: Final commit (if summary doc is in repo)**

Run:
```bash
git add <summary-doc-if-any>
git commit -m "docs: capture Runner-alpha rebuild completion checklist"
```
