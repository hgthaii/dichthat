#!/usr/bin/env bash

set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dmg_path="${1:?DMG path is required}"
archive_path="${2:?Sparkle ZIP path is required}"
appcast_path="${3:?Appcast path is required}"
version="${DICHTHAT_VERSION:?DICHTHAT_VERSION is required}"
working_directory="$(mktemp -d /private/tmp/dichthat-release-verification.XXXXXX)"
mount_directory="${working_directory}/mounted-dmg"
archive_directory="${working_directory}/archive"
dmg_app_copy_path="${working_directory}/dmg-app/DichThat.app"
dmg_is_mounted=false

cleanup() {
    if [[ "${dmg_is_mounted}" == "true" ]]; then
        hdiutil detach "${mount_directory}" -quiet || true
    fi
    rm -rf -- "${working_directory}"
}
trap cleanup EXIT

test -f "${dmg_path}"
test -f "${archive_path}"
test -f "${appcast_path}"
[[ "$(basename "${dmg_path}")" == "DichThat-${version}.dmg" ]]
[[ "$(basename "${archive_path}")" == "DichThat-${version}.zip" ]]

mkdir -p "${mount_directory}" "${archive_directory}"
hdiutil attach \
    "${dmg_path}" \
    -mountpoint "${mount_directory}" \
    -readonly \
    -nobrowse \
    -noverify \
    -quiet
dmg_is_mounted=true

bash "${repository_root}/scripts/verify-app.sh" \
    "${mount_directory}/DichThat.app"
test ! -e "${mount_directory}/.background"
if [[ "${DICHTHAT_REQUIRE_STABLE_SIGNING:-false}" == "true" ]]; then
    mkdir -p "$(dirname "${dmg_app_copy_path}")"
    /usr/bin/ditto "${mount_directory}/DichThat.app" "${dmg_app_copy_path}"
fi

hdiutil detach "${mount_directory}" -quiet
dmg_is_mounted=false

/usr/bin/ditto -x -k "${archive_path}" "${archive_directory}"
archive_app_path="$(find "${archive_directory}" -maxdepth 2 -type d -name DichThat.app -print -quit)"
test -n "${archive_app_path}"
bash "${repository_root}/scripts/verify-app.sh" "${archive_app_path}"

if [[ "${DICHTHAT_REQUIRE_STABLE_SIGNING:-false}" == "true" ]]; then
    dmg_requirement="${working_directory}/dmg-requirement.txt"
    archive_requirement="${working_directory}/archive-requirement.txt"
    codesign -d -r- "${dmg_app_copy_path}" 2>&1 \
        | sed -nE 's/^#? ?designated => //p' > "${dmg_requirement}"
    codesign -d -r- "${archive_app_path}" 2>&1 \
        | sed -nE 's/^#? ?designated => //p' > "${archive_requirement}"
    codesign --verify --deep --strict -R "${dmg_requirement}" "${archive_app_path}"
    codesign --verify --deep --strict -R "${archive_requirement}" \
        "${dmg_app_copy_path}"
fi

appcast_version="$(xmllint --xpath 'string(//*[local-name()="shortVersionString"][1])' "${appcast_path}")"
appcast_build_number="$(xmllint --xpath 'string(//*[local-name()="version"][1])' "${appcast_path}")"
appcast_archive_url="$(xmllint --xpath 'string(//*[local-name()="enclosure"]/@url)' "${appcast_path}")"
appcast_signature="$(xmllint --xpath 'string(//*[local-name()="enclosure"]/@*[local-name()="edSignature"])' "${appcast_path}")"
appcast_hardware_requirements="$(xmllint --xpath 'string(//*[local-name()="hardwareRequirements"][1])' "${appcast_path}")"
expected_archive_url="https://github.com/hgthaii/dichthat/releases/download/v${version}/DichThat-${version}.zip"

[[ "${appcast_version}" == "${version}" ]]
if [[ -n "${DICHTHAT_BUILD_NUMBER:-}" ]]; then
    [[ "${appcast_build_number}" == "${DICHTHAT_BUILD_NUMBER}" ]]
fi
[[ "${appcast_archive_url}" == "${expected_archive_url}" ]]
test -n "${appcast_signature}"
test -z "${appcast_hardware_requirements}"
xcrun swift "${repository_root}/scripts/verify-sparkle-signature.swift" \
    "${archive_path}" \
    "${appcast_signature}" \
    "${archive_app_path}/Contents/Info.plist"

hdiutil verify "${dmg_path}"
printf '%s\n' "Verified release artifacts for DichThat ${version}"
