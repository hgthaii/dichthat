#!/usr/bin/env bash

set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
scratch_path="/private/tmp/dichthat-swiftpm"
package_cache_path="/private/tmp/dichthat-package-cache"
output_root="/private/tmp/dichthat-app"
app_path="${output_root}/DichThat.app"
version="${DICHTHAT_VERSION:-0.0.0}"
build_number="${DICHTHAT_BUILD_NUMBER:-1}"

export CLANG_MODULE_CACHE_PATH="/private/tmp/dichthat-clang-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="/private/tmp/dichthat-swift-cache"

if [[ ! "${version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    printf '%s\n' "Invalid DICHTHAT_VERSION: ${version}" >&2
    exit 1
fi
if [[ ! "${build_number}" =~ ^[1-9][0-9]*$ ]]; then
    printf '%s\n' "Invalid DICHTHAT_BUILD_NUMBER: ${build_number}" >&2
    exit 1
fi

xcrun swift "${repository_root}/scripts/generate-app-icon.swift" "${repository_root}"

swift build \
    --package-path "${repository_root}" \
    --cache-path "${package_cache_path}" \
    --scratch-path "${scratch_path}" \
    --configuration release

binary_path="$(swift build \
    --package-path "${repository_root}" \
    --cache-path "${package_cache_path}" \
    --scratch-path "${scratch_path}" \
    --configuration release \
    --show-bin-path)"

rm -rf "${app_path}"
mkdir -p \
    "${app_path}/Contents/MacOS" \
    "${app_path}/Contents/Resources" \
    "${app_path}/Contents/Frameworks"
install -m 755 "${binary_path}/DichThat" "${app_path}/Contents/MacOS/DichThat"
install -m 644 "${repository_root}/Resources/Info.plist" "${app_path}/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${version}" "${app_path}/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${build_number}" "${app_path}/Contents/Info.plist"
install -m 644 "${repository_root}/Resources/AppIcon.icns" "${app_path}/Contents/Resources/AppIcon.icns"
install -m 644 "${repository_root}/Resources/BrandDT.png" "${app_path}/Contents/Resources/BrandDT.png"
install -m 644 "${repository_root}/Resources/StatusItemTemplate.png" "${app_path}/Contents/Resources/StatusItemTemplate.png"
/usr/bin/ditto "${binary_path}/Sparkle.framework" "${app_path}/Contents/Frameworks/Sparkle.framework"
codesign --force --deep --sign - "${app_path}"

printf '%s\n' "${app_path}"
