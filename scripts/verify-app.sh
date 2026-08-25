#!/usr/bin/env bash

set -euo pipefail

app_path="${1:-/private/tmp/dichthat-app/DichThat.app}"
info_plist="${app_path}/Contents/Info.plist"
executable="${app_path}/Contents/MacOS/DichThat"

test -d "${app_path}"
test -f "${info_plist}"
test -x "${executable}"
plutil -lint "${info_plist}"

display_name="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleDisplayName' "${info_plist}")"
bundle_identifier="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "${info_plist}")"
minimum_system="$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "${info_plist}")"

[[ "${display_name}" == "DichThat" ]]
[[ "${bundle_identifier}" == "dev.hgthaii.dichthat" ]]
[[ "${minimum_system}" == "13.0" ]]

codesign --verify --deep --strict --verbose=2 "${app_path}"
printf '%s\n' "Verified ${app_path}"
