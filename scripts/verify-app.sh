#!/usr/bin/env bash

set -euo pipefail

app_path="${1:-/private/tmp/dichthat-app/DichThat.app}"
info_plist="${app_path}/Contents/Info.plist"
executable="${app_path}/Contents/MacOS/DichThat"
sparkle_framework="${app_path}/Contents/Frameworks/Sparkle.framework"

test -d "${app_path}"
test -f "${info_plist}"
test -x "${executable}"
test -d "${sparkle_framework}"
plutil -lint "${info_plist}"

display_name="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleDisplayName' "${info_plist}")"
bundle_identifier="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "${info_plist}")"
minimum_system="$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "${info_plist}")"
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "${info_plist}")"
build_number="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "${info_plist}")"

[[ "${display_name}" == "DichThat" ]]
[[ "${bundle_identifier}" == "dev.hgthaii.dichthat" ]]
[[ "${minimum_system}" == "13.0" ]]
[[ "${version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
[[ "${build_number}" =~ ^[1-9][0-9]*$ ]]

if [[ -n "${DICHTHAT_VERSION:-}" ]]; then
    [[ "${version}" == "${DICHTHAT_VERSION}" ]]
fi
if [[ -n "${DICHTHAT_BUILD_NUMBER:-}" ]]; then
    [[ "${build_number}" == "${DICHTHAT_BUILD_NUMBER}" ]]
fi

codesign --verify --deep --strict --verbose=2 "${app_path}"
printf '%s\n' "Verified ${app_path}"
