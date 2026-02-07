# MiniCalendar Release Instructions

This document contains the complete process for building, signing, notarizing, and releasing MiniCalendar.

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Build Process](#build-process)
3. [Code Signing](#code-signing)
4. [Package Creation](#package-creation)
5. [Notarization](#notarization)
6. [Release to GitHub](#release-to-github)
7. [Re-releasing (Overwriting Existing Release)](#re-releasing-overwriting-existing-release)
8. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Developer Certificate
- **Certificate Name**: Developer ID Application: Pingfan Hu (XC2WL5WN7J)
- **Team ID**: XC2WL5WN7J
- **Certificate ID**: 05B4E6565B931D9CD6845684661BA636331E2056

Verify certificate exists:
```bash
security find-identity -v -p codesigning
```

### Notarization Credentials
- **Apple ID**: pingfan0727@gmail.com
- **Team ID**: XC2WL5WN7J
- **App-Specific Password**: `vsnu-xqac-xvth-skvi`

#### Setup Notarization Profile (One-time)
```bash
xcrun notarytool store-credentials "notarytool-profile" \
  --apple-id "pingfan0727@gmail.com" \
  --team-id "XC2WL5WN7J" \
  --password "vsnu-xqac-xvth-skvi"
```

Verify credentials are stored:
```bash
xcrun notarytool history --keychain-profile "notarytool-profile"
```

---

## Build Process

### 0. Update Version Number (IMPORTANT!)

Before building, update the `MARKETING_VERSION` in the Xcode project:

```bash
# Update version in project.pbxproj (replace X.X.X with your version)
sed -i '' 's/MARKETING_VERSION = [0-9.]*;/MARKETING_VERSION = X.X.X;/g' MiniCalendar.xcodeproj/project.pbxproj

# Verify the change
grep "MARKETING_VERSION" MiniCalendar.xcodeproj/project.pbxproj
```

This ensures the version displays correctly in Settings → About.

### 1. Build Release Version
```bash
xcodebuild -project MiniCalendar.xcodeproj \
  -scheme MiniCalendar \
  -configuration Release \
  clean build
```

**Note**: Using `clean build` ensures a fresh build without cached artifacts.

Build output location:
```
/Users/pingfan/Library/Developer/Xcode/DerivedData/MiniCalendar-*/Build/Products/Release/MiniCalendar.app
```

---

## Code Signing

### CRITICAL: Sign with Entitlements

**The app MUST be signed with the entitlements file to enable calendar access permissions.**

Without entitlements, the app will not prompt for calendar permissions and events will not display.

### Required Files
- **Entitlements**: `MiniCalendar/MiniCalendar.entitlements`
- **Info.plist**: `MiniCalendar/Info.plist`

### Entitlements File Content
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <false/>
    <key>com.apple.security.personal-information.calendars</key>
    <true/>
</dict>
</plist>
```

### Info.plist Requirements

#### Calendar Permissions
```xml
<key>NSCalendarsUsageDescription</key>
<string>MiniCalendar needs access to your calendars to display your events.</string>
<key>NSCalendarsFullAccessUsageDescription</key>
<string>MiniCalendar needs full access to your calendars to display your events.</string>
```

#### Bundled Font Support
```xml
<key>ATSApplicationFontsPath</key>
<string>.</string>
```

**Note**: Custom fonts must also be registered programmatically in AppDelegate using `CTFontManagerRegisterFontsForURL`. See `MiniCalendar/AppDelegate.swift` for implementation.

### Sign the App
```bash
codesign --force --deep \
  --sign "Developer ID Application: Pingfan Hu (XC2WL5WN7J)" \
  --options runtime \
  --entitlements MiniCalendar/MiniCalendar.entitlements \
  /Users/pingfan/Library/Developer/Xcode/DerivedData/MiniCalendar-*/Build/Products/Release/MiniCalendar.app
```

### Verify Signing and Entitlements
```bash
# Verify signature
codesign -v -vvv /Users/pingfan/Library/Developer/Xcode/DerivedData/MiniCalendar-*/Build/Products/Release/MiniCalendar.app

# Verify entitlements are embedded
codesign -d --entitlements - /Users/pingfan/Library/Developer/Xcode/DerivedData/MiniCalendar-*/Build/Products/Release/MiniCalendar.app
```

Expected output should show:
```
[Key] com.apple.security.personal-information.calendars
[Value]
    [Bool] true
```

---

## Package Creation

### IMPORTANT: Create Both DMG and ZIP

Both package formats are required for release:
1. **DMG** - Standard macOS installer with Applications folder shortcut (recommended for users)
2. **ZIP** - Alternative download format

**Note**: All commands below assume you're in the project root directory.

### 1. Create DMG

```bash
# Clean previous builds (if re-releasing)
rm -rf dist/dmg-temp dist/MiniCalendar-v1.X.X.*

# Prepare DMG contents
mkdir -p dist/dmg-temp
cp -R /Users/pingfan/Library/Developer/Xcode/DerivedData/MiniCalendar-*/Build/Products/Release/MiniCalendar.app dist/dmg-temp/
ln -s /Applications dist/dmg-temp/Applications

# Create and sign DMG
hdiutil create -volname "MiniCalendar v1.X.X" \
  -srcfolder dist/dmg-temp \
  -ov -format UDZO \
  dist/MiniCalendar-v1.X.X.dmg

codesign --force \
  --sign "Developer ID Application: Pingfan Hu (XC2WL5WN7J)" \
  dist/MiniCalendar-v1.X.X.dmg
```

### 2. Create ZIP

```bash
ditto -c -k --sequesterRsrc --keepParent \
  /Users/pingfan/Library/Developer/Xcode/DerivedData/MiniCalendar-*/Build/Products/Release/MiniCalendar.app \
  dist/MiniCalendar-v1.X.X.zip
```

---

## Notarization

### Submit DMG for Notarization
```bash
xcrun notarytool submit dist/MiniCalendar-v1.X.X.dmg \
  --keychain-profile "notarytool-profile" \
  --wait
```

This will:
- Upload the DMG to Apple's notarization service
- Wait for processing (usually 1-3 minutes)
- Display the result (Accepted/Rejected)

### Staple Notarization Ticket
After successful notarization:
```bash
xcrun stapler staple dist/MiniCalendar-v1.X.X.dmg
```

### Verify Notarization
```bash
xcrun stapler validate dist/MiniCalendar-v1.X.X.dmg
```

Expected output:
```
Processing: /path/to/MiniCalendar-v1.X.X.dmg
The validate action worked!
```

---

## Release to GitHub

### 1. Commit and Tag

```bash
# If you have changes to commit
git add .
git commit -m "Release v1.X.X"

# Create and push tag
git push origin main
git tag v1.X.X
git push origin v1.X.X
```

### 2. Create GitHub Release

**IMPORTANT: Keep release notes concise.** Focus on user-facing features and changes. Use bullet points. Group related items under clear section headers.

```bash
gh release create v1.X.X \
  --repo pingfan-hu/MiniCalendar \
  --title "v1.X.X" \
  --notes "$(cat <<'EOF'
## What's New in v1.X.X

### New Features
- Feature 1
- Feature 2

### Changes
- Change 1
- Change 2

### Bug Fixes
- Fix 1
- Fix 2

---
> Generated with [Claude Code](https://claude.com/claude-code)
EOF
)" \
  dist/MiniCalendar-v1.X.X.dmg \
  dist/MiniCalendar-v1.X.X.zip
```

### 3. Verify Release
```bash
gh release view v1.X.X --repo pingfan-hu/MiniCalendar
```

Expected assets:
- MiniCalendar-v1.X.X.dmg (signed, notarized, stapled)
- MiniCalendar-v1.X.X.zip
- Source code (zip) - auto-generated by GitHub
- Source code (tar.gz) - auto-generated by GitHub

---

## Re-releasing (Overwriting Existing Release)

If you need to overwrite an existing release (e.g., fixing a critical bug):

### 1. Delete Existing Release and Tag
```bash
# Delete GitHub release
gh release delete v1.X.X --yes --repo pingfan-hu/MiniCalendar

# Delete local and remote tags
git tag -d v1.X.X
git push origin :refs/tags/v1.X.X
```

### 2. Follow Normal Release Process
After deleting the release, follow the complete release process from the beginning:
1. Build
2. Sign
3. Package
4. Notarize
5. Create new release

---

## Troubleshooting

### Calendar Permissions Not Prompting

**Symptom**: App doesn't prompt for calendar access, no events displayed.

**Cause**: App was signed without entitlements file.

**Solution**:
1. Re-sign the app with `--entitlements` flag (see [Code Signing](#code-signing))
2. Verify entitlements are embedded using `codesign -d --entitlements -`
3. Recreate packages (DMG and ZIP)
4. Re-notarize and update release

### Bundled Font Not Loading

**Symptom**: App displays system default font instead of bundled custom font.

**Cause**: Font not properly registered or `ATSApplicationFontsPath` misconfigured.

**Solution**:
1. Verify `Info.plist` contains `ATSApplicationFontsPath` set to `"."`
2. Ensure font file is in `Contents/Resources/` in the app bundle
3. Verify programmatic registration in `AppDelegate.swift` using `CTFontManagerRegisterFontsForURL`
4. Check console logs for font registration errors

### Notarization Failed

**Check logs**:
```bash
xcrun notarytool log <submission-id> --keychain-profile "notarytool-profile"
```

Common issues:
- Missing hardened runtime (`--options runtime` flag)
- Invalid entitlements
- Unsigned binary
- Missing code signature

### DMG Not Opening on Other Macs

**Cause**: DMG was not notarized or stapled.

**Solution**:
1. Submit DMG for notarization
2. Staple the notarization ticket
3. Verify with `xcrun stapler validate`

---

## Complete Release Checklist

- [ ] **Update version number in Xcode project** (MARKETING_VERSION)
- [ ] Build Release version with `clean build`
- [ ] Sign app with entitlements file
- [ ] Verify entitlements are embedded
- [ ] Create DMG with Applications shortcut
- [ ] Sign DMG
- [ ] Create ZIP archive
- [ ] Submit DMG for notarization
- [ ] Wait for notarization acceptance
- [ ] Staple notarization ticket to DMG
- [ ] Verify stapled DMG
- [ ] Commit any final changes
- [ ] Create and push git tag
- [ ] Create GitHub release with both DMG and ZIP
- [ ] Verify release page and download links
- [ ] Test download and installation on clean Mac (optional but recommended)
- [ ] Clean up temporary files (`dist/dmg-temp`)

---

## Quick Reference Script

**Full release script for v1.X.X** (run from project root):

```bash
# 0. Update version number (replace 1.X.X with your version)
sed -i '' 's/MARKETING_VERSION = [0-9.]*;/MARKETING_VERSION = 1.X.X;/g' MiniCalendar.xcodeproj/project.pbxproj
grep "MARKETING_VERSION" MiniCalendar.xcodeproj/project.pbxproj

# 1. Build
xcodebuild -project MiniCalendar.xcodeproj -scheme MiniCalendar -configuration Release clean build

# 2. Sign app with entitlements
codesign --force --deep --sign "Developer ID Application: Pingfan Hu (XC2WL5WN7J)" \
  --options runtime --entitlements MiniCalendar/MiniCalendar.entitlements \
  /Users/pingfan/Library/Developer/Xcode/DerivedData/MiniCalendar-*/Build/Products/Release/MiniCalendar.app

# 3. Verify entitlements
codesign -d --entitlements - /Users/pingfan/Library/Developer/Xcode/DerivedData/MiniCalendar-*/Build/Products/Release/MiniCalendar.app

# 4. Create packages
rm -rf dist/dmg-temp dist/MiniCalendar-v1.X.X.*
mkdir -p dist/dmg-temp
cp -R /Users/pingfan/Library/Developer/Xcode/DerivedData/MiniCalendar-*/Build/Products/Release/MiniCalendar.app dist/dmg-temp/
ln -s /Applications dist/dmg-temp/Applications

# 5. Create and sign DMG
hdiutil create -volname "MiniCalendar v1.X.X" -srcfolder dist/dmg-temp -ov -format UDZO dist/MiniCalendar-v1.X.X.dmg
codesign --force --sign "Developer ID Application: Pingfan Hu (XC2WL5WN7J)" dist/MiniCalendar-v1.X.X.dmg

# 6. Create ZIP
ditto -c -k --sequesterRsrc --keepParent \
  /Users/pingfan/Library/Developer/Xcode/DerivedData/MiniCalendar-*/Build/Products/Release/MiniCalendar.app \
  dist/MiniCalendar-v1.X.X.zip

# 7. Notarize and staple
xcrun notarytool submit dist/MiniCalendar-v1.X.X.dmg --keychain-profile "notarytool-profile" --wait
xcrun stapler staple dist/MiniCalendar-v1.X.X.dmg
xcrun stapler validate dist/MiniCalendar-v1.X.X.dmg

# 8. Release
git push origin main
git tag v1.X.X
git push origin v1.X.X
gh release create v1.X.X --repo pingfan-hu/MiniCalendar --title "v1.X.X" \
  --notes "Release notes here..." dist/MiniCalendar-v1.X.X.dmg dist/MiniCalendar-v1.X.X.zip

# 9. Clean up
rm -rf dist/dmg-temp
```

---

**Last Updated**: 2025-10-21
**Project**: MiniCalendar
**Maintainer**: Pingfan Hu (pingfan0727@gmail.com)
