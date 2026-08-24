#!/usr/bin/env bash

set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
scratch_path="/private/tmp/dichthat-swiftpm"
output_root="/private/tmp/dichthat-app"
app_path="${output_root}/DichThat.app"

swift build \
    --package-path "${repository_root}" \
    --scratch-path "${scratch_path}" \
    --configuration release

binary_path="$(swift build \
    --package-path "${repository_root}" \
    --scratch-path "${scratch_path}" \
    --configuration release \
    --show-bin-path)"

rm -rf "${app_path}"
mkdir -p "${app_path}/Contents/MacOS" "${app_path}/Contents/Resources"
install -m 755 "${binary_path}/DichThat" "${app_path}/Contents/MacOS/DichThat"
install -m 644 "${repository_root}/Resources/Info.plist" "${app_path}/Contents/Info.plist"
install -m 644 "${repository_root}/Resources/AppIcon.icns" "${app_path}/Contents/Resources/AppIcon.icns"
install -m 644 "${repository_root}/Resources/BrandDT.png" "${app_path}/Contents/Resources/BrandDT.png"
install -m 644 "${repository_root}/Resources/StatusItemTemplate.png" "${app_path}/Contents/Resources/StatusItemTemplate.png"
codesign --force --deep --sign - "${app_path}"

printf '%s\n' "${app_path}"
