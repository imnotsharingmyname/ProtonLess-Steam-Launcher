# Backup Bottles — NotProton FES

## Integration

The **Status → CrossOver → Backup Bottles** button sits beside **Add CrossOver…**.
It runs `backup_crossover_bottles.sh` with `/bin/bash` via the app's existing
`Shell.run` Process-based executor, on a detached task. Its stdout/stderr and exit
code drive a SwiftUI success/failure alert; ANSI terminal color escapes are
removed from the displayed text.

The script enumerates `~/Library/Application Support/CrossOver/Bottles/**/system.reg`
and creates sibling timestamped `.bak` files. It preserves earlier backups from
the same second, and returns a nonzero exit code if a copy or enumeration fails.
It does **not** edit the original registry or CrossOver's activation/trial files.

This repository does **not** contain an `.xcodeproj`. It uses Swift Package Manager:
`app/Package.swift` declares `.copy("Resources/backup_crossover_bottles.sh")`.
The `Makefile` copies the SwiftPM resource bundle into `NotProton FES.app` and
ensures the script is executable before code signing. No change to the existing
CrossOver trial-detection implementation was made.

## macOS sandbox and file privacy

The original `Makefile` signs the app without an entitlements file (`codesign -s -` by
default); `app/Package.swift` and `app/Info.plist` do not opt into App Sandbox.
For **this** build, no additional sandbox entitlement is required to access the
CrossOver bottles folder, provided the current user has ordinary filesystem
permissions. No TCC request is normally necessary just for that specific folder.
TCC can still intervene if the bottles are redirected into a protected location,
if the app is accessed via a protected container, or if the system applies another
privacy control. If access is denied, check **System Settings → Privacy & Security**,
but do not require Full Disk Access as the default setup.

If you **enable App Sandbox** in a different Xcode app target, the absolute HOME
path in the bundled script is **not** automatically authorised. File access must
be granted with an `NSOpenPanel` folder selection and this entitlement on the main
app (alongside the sandbox flag):

```xml
<key>com.apple.security.app-sandbox</key><true/>
<key>com.apple.security.files.user-selected.read-write</key><true/>
```

For persistent sandbox access across app launches, also add
`com.apple.security.files.bookmarks.app-scope = true` and save/resolve a
security-scoped bookmark to the selected folder. The app must then call
`startAccessingSecurityScopedResource()` / `stopAccessingSecurityScopedResource()`
around its file operations.

**Important:** Open-panel grants obtained dynamically are **not inherited by a
`/bin/bash` child** through `com.apple.security.inherit`. Adding only the
entitlements above **does not make this exact absolute-path Bash implementation
work in a sandbox**. To support App Sandbox properly, refactor to do the
copying using Foundation APIs in the Swift process after the user selects the
folder, or design a dedicated helper/bookmark-based mechanism; do not assume
that a shell subprocess gains security-scoped access. The present implementation
is intended for the original **unsandboxed** packaging. No `com.apple.security.automation.apple-events`
entitlement is required for launching `/bin/bash` with `Process`.

## Validation

Run `bash -n app/Sources/NotProtonApp/Resources/backup_crossover_bottles.sh` and
`make app-tests` on macOS with project prerequisites installed. The added
`CrossOverBottleBackupTests.swift` verifies the bundled script, ANSI cleaning,
backups of synthetic bottles, preservation of earlier backups, and missing-folder
failure. This source checkout cannot be fully built into a signed macOS app on
Linux, where Xcode, `codesign`, and macOS SwiftUI aren't available.
