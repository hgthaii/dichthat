#!/usr/bin/env bash

set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
output_directory="${repository_root}/dist"
staging_directory="$(mktemp -d /private/tmp/dichthat-dmg.XXXXXX)"
payload_directory="${staging_directory}/payload"
read_write_image="${staging_directory}/DichThat-rw.dmg"
mount_directory=""
device_name=""

cleanup() {
    if [[ -n "${device_name}" ]] && hdiutil info | grep -Fq "${device_name}"; then
        hdiutil detach "${device_name}" -quiet || true
    fi
    rm -rf -- "${staging_directory}"
}
trap cleanup EXIT

bash "${repository_root}/scripts/build-app.sh"
bash "${repository_root}/scripts/verify-app.sh"
output_path="${output_directory}/DichThat.dmg"
mkdir -p "$(dirname "${output_path}")"
/usr/bin/ditto \
    "/private/tmp/dichthat-app/DichThat.app" \
    "${payload_directory}/DichThat.app"
ln -s /Applications "${payload_directory}/Applications"

hdiutil create \
    -volname "DichThat" \
    -srcfolder "${payload_directory}" \
    -fs HFS+ \
    -fsargs "-c c=64,a=16,e=16" \
    -format UDRW \
    -ov \
    "${read_write_image}"

attach_output="$(hdiutil attach \
    "${read_write_image}" \
    -mountrandom /Volumes \
    -readwrite \
    -nobrowse \
    -noautoopen \
    -noverify)"
device_name="$(printf '%s\n' "${attach_output}" | awk '/^\/dev\// { print $1; exit }')"
mount_directory="$(printf '%s\n' "${attach_output}" | awk -F '\t' '$NF ~ /^\/Volumes\// { print $NF; exit }')"

if [[ -z "${device_name}" || -z "${mount_directory}" ]]; then
    printf '%s\n' "Unable to locate mounted DMG" >&2
    exit 1
fi

osascript - "$(basename "${mount_directory}")" <<'APPLESCRIPT'
on run arguments
set diskName to item 1 of arguments
tell application "Finder"
    tell disk diskName
        open
        tell container window
            set current view to icon view
            set toolbar visible to false
            set statusbar visible to false
            set bounds to {120, 120, 840, 650}
        end tell
        set viewOptions to the icon view options of container window
        set backgroundFile to file "DichThat.app:Contents:Resources:InstallerBackground.png"
        tell viewOptions
            set icon size to 96
            set text size to 12
            set arrangement to not arranged
            set background picture to backgroundFile
        end tell
        set position of item "DichThat.app" to {180, 120}
        set position of item "Applications" to {540, 120}
        close
        open
        delay 1
        tell container window
            set bounds to {120, 120, 830, 640}
        end tell
    end tell
    delay 1
    tell disk diskName
        tell container window
            set bounds to {120, 120, 840, 650}
        end tell
    end tell
    delay 3
    tell disk diskName
        close container window
    end tell
end tell
end run
APPLESCRIPT

sync
hdiutil detach "${device_name}" -quiet
device_name=""
mount_directory=""

hdiutil convert \
    "${read_write_image}" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -ov \
    -o "${output_path}"

hdiutil verify "${output_path}"
printf '%s\n' "${output_path}"
