#!/bin/bash
# Back up each CrossOver bottle's system.reg next to its original file.
# This does not alter CrossOver licensing, activation, or trial data.

BOTTLES_PATH="$HOME/Library/Application Support/CrossOver/Bottles"
TOTAL_STEPS=3
STEP=0

addStep() {
    STEP=$((STEP + 1))
    printf '\n\033[33m%s/%s %s\033[0m\n' "$STEP" "$TOTAL_STEPS" "$1"
}

find_bottles() {
    find "$1" -name "system.reg" -type f -print0
}

backupBottle() {
    local bottlePath="$1"
    local bottleName
    local backupFile
    local suffix=1
    bottleName=$(basename "$bottlePath")
    backupFile="$bottlePath/system.reg.$(date +%Y-%m-%d_%H-%M-%S).bak"

    # Do not silently replace a backup if the button is pressed twice in one second.
    while [ -e "$backupFile" ] || [ -L "$backupFile" ]; do
        backupFile="$bottlePath/system.reg.$(date +%Y-%m-%d_%H-%M-%S).$suffix.bak"
        suffix=$((suffix + 1))
    done

    if cp "$bottlePath/system.reg" "$backupFile"; then
        printf '\033[32m%s backed up successfully\033[0m\n' "$bottleName"
        return 0
    else
        printf '\033[31mBackup failed: %s\033[0m\n' "$bottleName" >&2
        return 1
    fi
}

main() {
    addStep "Checking CrossOver installation"
    if [ ! -d "$BOTTLES_PATH" ]; then
        echo "CrossOver bottles directory not found: $BOTTLES_PATH" >&2
        return 1
    fi

    addStep "Finding CrossOver bottles"
    local count=0
    local failures=0
    local registry
    local bottle
    REGISTRY_LIST=$(mktemp "${TMPDIR:-/tmp}/notproton-bottles.XXXXXXXX") || return 1
    trap 'rm -f "$REGISTRY_LIST"' EXIT

    # A manifest lets us notice a failed find, unlike process substitution.
    if ! find_bottles "$BOTTLES_PATH" > "$REGISTRY_LIST"; then
        echo "Could not enumerate all CrossOver bottles." >&2
        return 1
    fi

    while IFS= read -r -d '' registry; do
        bottle="${registry%/system.reg}"
        printf 'Found: %s\n' "$(basename "$bottle")"
        count=$((count + 1))
    done < "$REGISTRY_LIST"

    addStep "Backing up bottle registries"
    while IFS= read -r -d '' registry; do
        bottle="${registry%/system.reg}"
        if ! backupBottle "$bottle"; then
            failures=$((failures + 1))
        fi
    done < "$REGISTRY_LIST"

    printf '\nCompleted. Found %s bottle(s). %s failure(s).\n' "$count" "$failures"
    [ "$failures" -eq 0 ]
}

main "$@"
