#!/bin/zsh

source "${0:A:h}/lib/classify-updates.sh"

force_refresh=0
[[ "${1:-}" == "--force-refresh" ]] && force_refresh=1

settings_domain="com.cagatay.BadgeHider"
system_settings_domain="$HOME/Library/Preferences/com.apple.systempreferences.plist"
attention_key="AttentionPrefBundleIDs"
software_update_id="com.apple.Software-Update-Settings.extension"
scan_interval=300
scan_timeout="${TAHOE_BADGE_SCAN_TIMEOUT:-45}"
preference_tool="${0:A:h}/badge-preference-tool"

enabled="$(defaults read "$settings_domain" Enabled 2>/dev/null || printf '1')"

read_badge_value() {
    defaults export "$system_settings_domain" - 2>/dev/null |
        plutil -extract "$attention_key.$software_update_id" raw -o - - 2>/dev/null || true
}

set_badge_value() {
    local desired_value="$1"
    local current_value="$(read_badge_value)"
    local changed=0

    if [[ "$desired_value" == "0" && "$current_value" != "0" ]]; then
        "$preference_tool" hide || return 1
        changed=1
    elif [[ "$desired_value" == "1" && "$current_value" == "0" ]]; then
        "$preference_tool" restore || return 1
        changed=1
    fi

    if [[ "$changed" == "0" && ("$force_refresh" == "1" || "$desired_value" == "0") ]]; then
        "$preference_tool" refresh || return 1
    fi
}

list_cached_updates() {
    local output_file
    local update_pid
    local elapsed=0
    local exit_status=0

    output_file="$(mktemp "${TMPDIR:-/tmp}/TahoeUpdateBadgeBlocker.XXXXXX")" || return 1
    softwareupdate --list --no-scan >"$output_file" 2>&1 &
    update_pid=$!

    while kill -0 "$update_pid" 2>/dev/null && [[ "$elapsed" -lt "$scan_timeout" ]]; do
        sleep 1
        elapsed=$((elapsed + 1))
    done

    if kill -0 "$update_pid" 2>/dev/null; then
        kill "$update_pid" 2>/dev/null || true
        wait "$update_pid" 2>/dev/null || true
        exit_status=124
    else
        wait "$update_pid" || exit_status=$?
    fi

    cat "$output_file"
    rm -f "$output_file"
    return "$exit_status"
}

if [[ "$enabled" == "0" ]]; then
    set_badge_value 1
    defaults write "$settings_domain" LastAppliedEnabled -int 0
    exit 0
fi

now="$(date +%s)"
last_scan="$(defaults read "$settings_domain" LastScanEpoch 2>/dev/null || printf '0')"
if [[ "$force_refresh" != "1" && "$((now - last_scan))" -lt "$scan_interval" ]]; then
    exit 0
fi
defaults write "$settings_domain" LastScanEpoch -int "$now"

update_output="$(list_cached_updates)"
classification="$(classify_update_output "$update_output")"

case "$classification" in
    show)
        set_badge_value 1
        ;;
    hide)
        set_badge_value 0
        ;;
    *)
        # On scan/parsing errors, preserve the current badge state.
        exit 0
        ;;
esac

defaults write "$settings_domain" LastAppliedEnabled -int 1
