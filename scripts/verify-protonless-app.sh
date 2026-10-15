#!/bin/bash
# Runs on a macOS runner after `make app` and before creating the ZIP.
set -euo pipefail

app="${1:-out/ProtonLess Steam.app}"
info="$app/Contents/Info.plist"
executable="$app/Contents/MacOS/ProtonLessSteam"
script="$app/Contents/Resources/NotProtonApp_NotProtonApp.bundle/Contents/Resources/backup_crossover_bottles.sh"
restore_script="$app/Contents/Resources/NotProtonApp_NotProtonApp.bundle/Contents/Resources/restore_crossover_first_run_date.sh"

if [[ ! -d "$app" || ! -f "$info" ]]; then
    echo "Missing ProtonLess Steam.app bundle: $app" >&2
    exit 1
fi

/usr/bin/plutil -lint "$info"

assert_plist() {
    local key="$1" expected="$2" actual
    actual="$(/usr/libexec/PlistBuddy -c "Print :$key" "$info")"
    if [[ "$actual" != "$expected" ]]; then
        echo "Unexpected $key: expected '$expected', got '$actual'" >&2
        exit 1
    fi
}

assert_plist CFBundleName 'ProtonLess Steam'
assert_plist CFBundleDisplayName 'ProtonLess Steam'
assert_plist CFBundleIdentifier 'io.protonless.steam'
assert_plist CFBundleExecutable 'ProtonLessSteam'

if [[ ! -x "$executable" ]]; then
    echo "Missing app executable: $executable" >&2
    exit 1
fi
if [[ ! -x "$script" ]]; then
    echo "Bundled bottle backup script missing or not executable: $script" >&2
    exit 1
fi

if [[ ! -x "$restore_script" ]]; then
    echo "Bundled CrossOver settings restore script missing or not executable: $restore_script" >&2
    exit 1
fi

expected_arch="${2:-arm64}"
/usr/bin/lipo -verify_arch "$expected_arch" "$executable"
engine="$app/Contents/Resources/NotProtonApp_NotProtonApp.bundle/Contents/Resources/payload/notproton.dylib"
/usr/bin/lipo -verify_arch "$expected_arch" "$engine"
/usr/bin/codesign --verify --strict "$app"
echo 'Verified ProtonLess Steam.app: name, identity, expected architecture, backup and restore scripts, signature.'
