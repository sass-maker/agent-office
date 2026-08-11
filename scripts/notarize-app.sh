#!/bin/zsh

set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
project_dir="$(cd "$script_dir/.." && pwd)"
app_path="${1:-$project_dir/dist/AgentOffice.app}"
notary_profile="${AGENT_OFFICE_NOTARY_PROFILE:-}"

[[ -d "$app_path" ]] || { print -u2 "missing app bundle: $app_path"; exit 1; }
[[ -n "$notary_profile" ]] || {
    print -u2 "AGENT_OFFICE_NOTARY_PROFILE must name an existing notarytool Keychain profile"
    exit 64
}

signature_authority="$(codesign -dv --verbose=4 "$app_path" 2>&1 | sed -n 's/^Authority=//p' | head -1)"
[[ "$signature_authority" == Developer\ ID\ Application:* ]] || {
    print -u2 "app is not signed with Developer ID Application: $app_path"
    exit 1
}

submission_zip="$(mktemp "${TMPDIR:-/tmp}/agent-office-notary.XXXXXX.zip")"
ditto -c -k --keepParent "$app_path" "$submission_zip"
xcrun notarytool submit "$submission_zip" --keychain-profile "$notary_profile" --wait
xcrun stapler staple "$app_path"
xcrun stapler validate "$app_path"
spctl --assess --type execute --verbose=2 "$app_path"
print "$app_path"
