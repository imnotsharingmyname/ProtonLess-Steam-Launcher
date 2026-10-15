#!/bin/bash
# Read-only architecture and build profile diagnostics. Writes plain text to Desktop.
set -uo pipefail
out="$HOME/Desktop/NotProton-Intel-Steam-Diagnostics.txt"
{
  echo "Intel Steam diagnostic $(date)"
  sw_vers
  uname -m
  echo '--- Steam binaries ---'
  for f in "/Applications/Steam.app/Contents/MacOS/steam_osx"            "$HOME/Library/Application Support/Steam/Steam.AppBundle/Steam/Contents/MacOS/steam_osx"            "$HOME/Library/Application Support/Steam/Steam.AppBundle/Steam/Contents/MacOS/steamclient.dylib"            "$HOME/Library/Application Support/Steam/Steam.AppBundle/Steam/Contents/MacOS/steamui.dylib"; do
    if [ -f "$f" ]; then
      echo "--- ${f##*/} ---"
      file "$f"
      xcrun dwarfdump --uuid "$f" 2>&1 || true
      shasum -a 256 "$f" 2>&1 || true
      ls -lh "$f"
    fi
  done
  echo '--- Steam app metadata ---'
  defaults read "$HOME/Library/Application Support/Steam/Steam.AppBundle/Steam/Contents/Info" CFBundleVersion 2>&1 || true
  echo '--- Install state ---'
  ls -la "$HOME/Library/Application Support/notproton/signatures/" 2>&1 || true
} >"$out" 2>&1
printf 'Saved read-only diagnostics to %s\n' "$out"
