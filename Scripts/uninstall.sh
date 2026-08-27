#!/bin/zsh
set -euo pipefail

agent_path="$HOME/Library/LaunchAgents/com.cagatay.hide-system-settings-badge.plist"
lock_agent_path="$HOME/Library/LaunchAgents/com.cagatay.badgehider-screen-lock.plist"
helper_dir="$HOME/Library/Application Support/HideSystemSettingsBadge"
prefpane_path="$HOME/Library/PreferencePanes/Tahoe Update Badge Blocker.prefPane"
previous_prefpane_path="$HOME/Library/PreferencePanes/Tahoe Badge Filter.prefPane"
legacy_prefpane_path="$HOME/Library/PreferencePanes/Rozet Gizleyici.prefPane"

launchctl bootout "gui/$(id -u)" "$agent_path" 2>/dev/null || true
launchctl bootout "gui/$(id -u)" "$lock_agent_path" 2>/dev/null || true

if [[ -x "$helper_dir/badge-preference-tool" ]]; then
    "$helper_dir/badge-preference-tool" restore || true
fi
defaults delete com.cagatay.BadgeHider 2>/dev/null || true

rm -f "$agent_path" "$lock_agent_path"
rm -rf "$helper_dir" "$prefpane_path" "$previous_prefpane_path" "$legacy_prefpane_path"

printf 'Tahoe Update Badge Blocker was removed.\n'

if [[ "${1:-}" == "--logout" ]]; then
    /usr/bin/osascript -e 'tell application "System Events" to log out' >/dev/null 2>&1 || true
fi
