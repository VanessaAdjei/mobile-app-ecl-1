#!/bin/bash
# Reclaim ~30GB from bloated Cursor chat/agent storage.
# Quit Cursor completely before running this script.

set -euo pipefail

DB="$HOME/Library/Application Support/Cursor/User/globalStorage/state.vscdb"
BACKUP="$DB.backup"

if pgrep -x Cursor >/dev/null 2>&1; then
  echo "Error: Cursor is still running. Quit Cursor first, then rerun."
  exit 1
fi

if [[ ! -f "$DB" ]]; then
  echo "Error: state database not found at $DB"
  exit 1
fi

echo "Before:"
du -sh "$DB" "$BACKUP" 2>/dev/null || true

# Remove stale backup (often duplicates the main DB).
if [[ -f "$BACKUP" ]]; then
  rm -f "$BACKUP"
  echo "Removed backup file."
fi

# Drop cached agent/chat blobs (safe to regenerate; keeps settings in ItemTable).
sqlite3 "$DB" "DELETE FROM cursorDiskKV WHERE key LIKE 'bubbleId:%' OR key LIKE 'agentKv:%';"
sqlite3 "$DB" "VACUUM;"

echo "After:"
du -sh "$DB" 2>/dev/null || true
echo "Done. Restart Cursor."
