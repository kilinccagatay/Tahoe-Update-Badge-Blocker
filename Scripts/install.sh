#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
app_support_dir="$HOME/Library/Application Support/HideSystemSettingsBadge"
preference_panes_dir="$HOME/Library/PreferencePanes"
launch_agents_dir="$HOME/Library/LaunchAgents"
helper_path="$app_support_dir/hide-badge.sh"
preference_tool_path="$app_support_dir/badge-preference-tool"
agent_path="$launch_agents_dir/com.cagatay.hide-system-settings-badge.plist"
lock_agent_path="$launch_agents_dir/com.cagatay.badgehider-screen-lock.plist"
prefpane_path="$preference_panes_dir/Tahoe Update Badge Blocker.prefPane"
previous_prefpane_path="$preference_panes_dir/Tahoe Badge Filter.prefPane"
legacy_prefpane_path="$preference_panes_dir/Rozet Gizleyici.prefPane"

mkdir -p "$app_support_dir" "$preference_panes_dir" "$launch_agents_dir"
mkdir -p "$app_support_dir/lib"

cp "$project_dir/Scripts/hide-badge.sh" "$helper_path"
cp "$project_dir/Scripts/lib/classify-updates.sh" "$app_support_dir/lib/classify-updates.sh"
cp "$project_dir/build/BadgePreferenceTool" "$preference_tool_path"
cp "$project_dir/Scripts/uninstall.sh" "$app_support_dir/uninstall.sh"
chmod 755 "$helper_path" "$preference_tool_path" \
    "$app_support_dir/uninstall.sh"

rm -rf "$prefpane_path" "$previous_prefpane_path" "$legacy_prefpane_path"
cp -R "$project_dir/build/BadgePreferencePane.prefPane" "$prefpane_path"

sed "s|__HELPER_PATH__|$helper_path|g" \
    "$project_dir/LaunchAgents/com.cagatay.hide-system-settings-badge.plist" > "$agent_path"
plutil -lint "$agent_path"

if ! defaults read com.cagatay.BadgeHider Enabled >/dev/null 2>&1; then
    defaults write com.cagatay.BadgeHider Enabled -bool true
elif [[ "$(defaults read com.cagatay.BadgeHider Enabled 2>/dev/null)" == "0" ]]; then
    "$preference_tool_path" restore
fi
defaults delete com.cagatay.BadgeHider PendingDockRefresh 2>/dev/null || true

launchctl bootout "gui/$(id -u)" "$agent_path" 2>/dev/null || true
launchctl bootout "gui/$(id -u)" "$lock_agent_path" 2>/dev/null || true
rm -f "$lock_agent_path" "$app_support_dir/screen-lock-listener"
launchctl bootstrap "gui/$(id -u)" "$agent_path"

printf 'Installed: %s\n' "$prefpane_path"
