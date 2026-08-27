#!/bin/zsh
set -euo pipefail

source "${0:A:h:h}/Scripts/lib/classify-updates.sh"

assert_classification() {
    local expected="$1"
    local input="$2"
    local actual="$(classify_update_output "$input")"

    if [[ "$actual" != "$expected" ]]; then
        printf 'Expected: %s, received: %s\n' "$expected" "$actual" >&2
        exit 1
    fi
}

assert_classification hide $'Software Update found the following new or updated software:\n* Label: macOS Tahoe 26.6.2-25G83\n\tTitle: macOS Tahoe 26.6.2, Version: 26.6.2, Recommended: YES'

assert_classification show $'Software Update found the following new or updated software:\n* Label: macOS Sequoia 15.7.10-24G999\n\tTitle: macOS Sequoia 15.7.10, Version: 15.7.10, Recommended: YES'

assert_classification show $'Software Update found the following new or updated software:\n* Label: macOS Tahoe 26.6.2-25G83\n\tTitle: macOS Tahoe 26.6.2, Version: 26.6.2, Recommended: YES\n* Label: macOS Sequoia 15.7.10-24G999\n\tTitle: macOS Sequoia 15.7.10, Version: 15.7.10, Recommended: YES'

assert_classification show $'Software Update found the following new or updated software:\n* Label: Safari26.1SequoiaAuto-26.1\n\tTitle: Safari, Version: 26.1, Recommended: YES'

assert_classification hide 'No new software available.'
assert_classification unknown 'Scan finished with error: request denied'

printf 'All classification tests passed.\n'
