#!/usr/bin/env bash

set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "${repository_root}/Resources/Info.plist")"
output_directory="${repository_root}/dist"
output_path="${1:-${output_directory}/DichThat-${version}.dmg}"
staging_directory="$(mktemp -d /private/tmp/dichthat-dmg.XXXXXX)"

cleanup() {
    rm -rf -- "${staging_directory}"
}
trap cleanup EXIT

bash "${repository_root}/scripts/build-app.sh"
mkdir -p "$(dirname "${output_path}")"
/usr/bin/ditto \
    "/private/tmp/dichthat-app/DichThat.app" \
    "${staging_directory}/DichThat.app"
ln -s /Applications "${staging_directory}/Applications"

hdiutil create \
    -volname "DichThat" \
    -srcfolder "${staging_directory}" \
    -format UDZO \
    -ov \
    "${output_path}"

hdiutil verify "${output_path}"
printf '%s\n' "${output_path}"
