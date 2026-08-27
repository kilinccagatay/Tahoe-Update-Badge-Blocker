#!/bin/zsh

classify_update_output() {
    local update_output="$1"
    local update_lines="$(
        printf '%s\n' "$update_output" | sed -n '/^[[:space:]]*Title:/p'
    )"

    if [[ -n "$update_lines" ]]; then
        if printf '%s\n' "$update_lines" |
            grep -qv 'Title: macOS Tahoe .*Version: 26\.'; then
            # Sequoia, Safari, security, or another non-Tahoe update exists.
            printf 'show\n'
        else
            # Every cached update is a Tahoe 26 upgrade.
            printf 'hide\n'
        fi
    elif printf '%s\n' "$update_output" | grep -q 'No new software available'; then
        printf 'hide\n'
    else
        printf 'unknown\n'
    fi
}
