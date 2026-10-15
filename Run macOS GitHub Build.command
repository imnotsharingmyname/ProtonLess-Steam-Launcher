#!/bin/bash
set -Eeuo pipefail
cd "$(dirname "$0")"
for t in gh git; do command -v "$t" >/dev/null || { echo "Missing $t"; exit 1; }; done
if ! gh auth status >/dev/null 2>&1; then gh auth login --web --git-protocol https; fi
repo="$(git remote get-url origin)"
repo="${repo%.git}"
repo="${repo#https://github.com/}"
if [[ "$repo" != */* ]]; then echo 'Open inside your published repository clone.'; exit 1; fi
printf 'Starting public GitHub Actions build for %s\n' "$repo"
gh workflow run app.yml --repo "$repo" --ref main
open "https://github.com/$repo/actions" 2>/dev/null || true
