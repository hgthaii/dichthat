#!/usr/bin/env bash

set -euo pipefail

app_path="${1:-/private/tmp/dichthat-app/DichThat.app}"
info_plist="${app_path}/Contents/Info.plist"
executable="${app_path}/Contents/MacOS/DichThat"
sparkle_framework="${app_path}/Contents/Frameworks/Sparkle.framework"
dark_icon="${app_path}/Contents/Resources/AppIconDark.png"
light_icon="${app_path}/Contents/Resources/AppIconLight.png"
installer_background="${app_path}/Contents/Resources/InstallerBackground.png"

test -d "${app_path}"
test -f "${info_plist}"
test -x "${executable}"
test -d "${sparkle_framework}"
test -f "${dark_icon}"
test -f "${light_icon}"
test -f "${installer_background}"
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
otool -l "${executable}" | grep -F '@executable_path/../Frameworks' >/dev/null
otool -L "${executable}" | grep -F '@rpath/Sparkle.framework/Versions/B/Sparkle' >/dev/null

if ! lipo "${executable}" -verify_arch arm64 x86_64; then
    printf '%s\n' "DichThat executable must be Universal 2 (arm64 and x86_64)." >&2
    exit 1
fi

for architecture in arm64 x86_64; do
    deployment_target="$(
        otool -arch "${architecture}" -l "${executable}" \
            | awk '/cmd LC_BUILD_VERSION/ { found = 1 } found && !printed && $1 == "minos" { print $2; printed = 1 }'
    )"
    if [[ "${deployment_target}" != "13.0" ]]; then
        printf '%s\n' \
            "DichThat ${architecture} deployment target must be macOS 13.0." >&2
        exit 1
    fi
done

while IFS= read -r -d '' framework_binary; do
    if ! file -b "${framework_binary}" | grep -q 'Mach-O'; then
        continue
    fi
    if ! lipo "${framework_binary}" -verify_arch arm64 x86_64; then
        printf '%s\n' \
            "Sparkle executable must be Universal 2: ${framework_binary}" >&2
        exit 1
    fi
done < <(find "${sparkle_framework}" -type f -perm -111 -print0)

if [[ -n "${DICHTHAT_VERSION:-}" ]]; then
    [[ "${version}" == "${DICHTHAT_VERSION}" ]]
fi
if [[ -n "${DICHTHAT_BUILD_NUMBER:-}" ]]; then
    [[ "${build_number}" == "${DICHTHAT_BUILD_NUMBER}" ]]
fi

codesign --verify --deep --strict --verbose=2 "${app_path}"

if [[ "${DICHTHAT_REQUIRE_STABLE_SIGNING:-false}" == "true" ]]; then
    signature_details="$(codesign -dv --verbose=4 "${app_path}" 2>&1)"
    designated_requirement="$(codesign -d -r- "${app_path}" 2>&1)"
    if [[ "${signature_details}" == *"Signature=adhoc"* ]]; then
        printf '%s\n' "Release app must not use an ad-hoc signature." >&2
        exit 1
    fi
    if [[ "${designated_requirement}" == *"cdhash"* ]]; then
        printf '%s\n' "Release designated requirement must not be tied to a CDHash." >&2
        exit 1
    fi
fi
printf '%s\n' "Verified ${app_path}"
