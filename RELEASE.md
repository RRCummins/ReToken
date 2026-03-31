# ReToken Release Process

This is the canonical release flow for ReToken.

Ship a notarized `DMG`, not a zip.

## Release Rules

- Release from `main`
- Start from a clean git worktree
- Verify tests before version bump and again before release
- Publish a notarized `DMG` as the GitHub Release asset
- Prefer replacing zip assets with the `DMG` so the release stays single-path for users

## Prerequisites

- Xcode installed
- `create-dmg` installed
- `gh` authenticated
- Apple notarization credentials available

Install the packaging dependency:

```bash
brew install create-dmg
```

Authenticate GitHub:

```bash
gh auth login
```

Export Apple credentials into your shell:

```bash
export APPLE_ID="you@example.com"
export APPLE_APP_PASSWORD="xxxx-xxxx-xxxx-xxxx"
export APPLE_TEAM_ID="XW3YJZ5VVY"
```

## 1. Verify Clean State

```bash
git status --short
```

Expected output is empty.

## 2. Run Tests

```bash
xcodebuild \
  -project /Users/ryancummins/Developer/ReToken/ReToken/ReToken.xcodeproj \
  -scheme ReToken \
  -configuration Debug \
  test CODE_SIGNING_ALLOWED=NO
```

## 3. Bump Version

ReToken currently uses Xcode project versioning.

For a new release:

```bash
cd /Users/ryancummins/Developer/ReToken/ReToken
xcrun agvtool new-marketing-version 1.1.1
xcrun agvtool new-version -all 124
```

Then commit the release bump:

```bash
cd /Users/ryancummins/Developer/ReToken
git add ReToken/ReToken.xcodeproj/project.pbxproj
git commit -m "chore: release 1.1.1"
git tag -a v1.1.1 -m "ReToken 1.1.1"
git push origin main v1.1.1
```

## 4. Build the Release App

Archive:

```bash
xcodebuild archive \
  -project /Users/ryancummins/Developer/ReToken/ReToken/ReToken.xcodeproj \
  -scheme ReToken \
  -configuration Release \
  -archivePath /Users/ryancummins/Developer/ReToken/ReToken/.build/release/ReToken.xcarchive
```

Export:

```bash
xcodebuild -exportArchive \
  -archivePath /Users/ryancummins/Developer/ReToken/ReToken/.build/release/ReToken.xcarchive \
  -exportOptionsPlist /Users/ryancummins/Developer/ReToken/ReToken/ExportOptions.plist \
  -exportPath /Users/ryancummins/Developer/ReToken/ReToken/.build/release/export
```

Expected exported app:

```text
/Users/ryancummins/Developer/ReToken/ReToken/.build/release/export/ReToken.app
```

## 5. Notarize and Staple

Zip the exported app for notarization:

```bash
ditto -c -k --keepParent \
  /Users/ryancummins/Developer/ReToken/ReToken/.build/release/export/ReToken.app \
  /Users/ryancummins/Developer/ReToken/ReToken/.build/release/ReToken-notarize.zip
```

Submit:

```bash
xcrun notarytool submit \
  /Users/ryancummins/Developer/ReToken/ReToken/.build/release/ReToken-notarize.zip \
  --apple-id "$APPLE_ID" \
  --team-id "$APPLE_TEAM_ID" \
  --password "$APPLE_APP_PASSWORD" \
  --wait
```

Staple:

```bash
xcrun stapler staple /Users/ryancummins/Developer/ReToken/ReToken/.build/release/export/ReToken.app
xcrun stapler validate /Users/ryancummins/Developer/ReToken/ReToken/.build/release/export/ReToken.app
```

Optional signature inspection:

```bash
codesign -dv --verbose=4 /Users/ryancummins/Developer/ReToken/ReToken/.build/release/export/ReToken.app
```

Look for:

- `Notarization Ticket=stapled`
- `TeamIdentifier=XW3YJZ5VVY`

## 6. Build the DMG

Important: `create-dmg` should package from a temporary folder containing `ReToken.app`, not from the bare `.app` path directly.

```bash
tmpdir=$(mktemp -d)
cp -R /Users/ryancummins/Developer/ReToken/ReToken/.build/release/export/ReToken.app "$tmpdir/ReToken.app"

create-dmg \
  --volname "ReToken 1.1.1" \
  --window-size 520 300 \
  --icon-size 128 \
  --icon "ReToken.app" 130 150 \
  --hide-extension "ReToken.app" \
  --app-drop-link 390 150 \
  /Users/ryancummins/Developer/ReToken/ReToken-1.1.1.dmg \
  "$tmpdir"
```

Expected output:

```text
/Users/ryancummins/Developer/ReToken/ReToken-1.1.1.dmg
```

## 7. Publish the GitHub Release

Create the release with the `DMG`:

```bash
cd /Users/ryancummins/Developer/ReToken
gh release create v1.1.1 \
  /Users/ryancummins/Developer/ReToken/ReToken-1.1.1.dmg \
  --title "ReToken 1.1.1" \
  --generate-notes
```

If a release already exists, upload the `DMG`:

```bash
gh release upload v1.1.1 /Users/ryancummins/Developer/ReToken/ReToken-1.1.1.dmg --clobber
```

If a zip asset was uploaded earlier by mistake, remove it:

```bash
gh release delete-asset v1.1.1 ReToken-1.1.1-notarized.zip --yes
```

Inspect the final release:

```bash
gh release view v1.1.1 --json url,assets
```

## 8. Final Checklist

- `main` pushed
- Tag pushed
- Debug tests passed
- Release build passed
- Exported app notarized
- Exported app stapled
- GitHub Release contains `ReToken-<version>.dmg`
- No zip asset remains unless intentionally published

## Notes

- The root-level exported `ReToken.app` can be used for packaging if it is the notarized export you just produced, but the default flow should keep artifacts under `.build/release/`
- Keep release artifacts out of git
- If `spctl` reports an internal signing error on a local export, rely on `codesign -dv` and `xcrun stapler validate` instead
