#!/bin/bash
# Restore the previously saved CrossOver FirstRunDate preference.
# This does not create a new backup or modify the bottle registry files.
set -u

APP_DOMAIN="com.codeweavers.CrossOver"
BACKUP_FILE="$HOME/Desktop/CrossOver_FirstRunDate_Backup.txt"

echo "Restoring CrossOver trial settings..."

if pgrep -x "CrossOver" >/dev/null; then
    echo "Please quit CrossOver first." >&2
    exit 1
fi

if [ ! -f "$BACKUP_FILE" ]; then
    echo "Backup not found: $BACKUP_FILE. No changes made." >&2
    exit 1
fi

if [ ! -r "$BACKUP_FILE" ]; then
    echo "Cannot read backup: $BACKUP_FILE. Check Desktop privacy permissions." >&2
    exit 1
fi

if [ -s "$BACKUP_FILE" ]; then
    ORIGINAL_DATE=$(cat "$BACKUP_FILE") || {
        echo "Could not read the saved first-run date." >&2
        exit 1
    }
    if [ -z "$ORIGINAL_DATE" ]; then
        echo "The backup contains only whitespace or a newline, not a valid saved date." >&2
        exit 1
    fi
    if ! defaults write "$APP_DOMAIN" FirstRunDate -date "$ORIGINAL_DATE"; then
        echo "Could not restore the saved first-run date." >&2
        exit 1
    fi
    echo "Original first-run date restored: $ORIGINAL_DATE"
else
    # An empty backup means the preference was originally absent.
    # Do not treat 'key does not exist' as an error.
    defaults delete "$APP_DOMAIN" FirstRunDate 2>/dev/null || true
    echo "Original setting restored (FirstRunDate was absent)."
fi

echo ""
echo "Restoration complete."
echo "You can reopen CrossOver."
