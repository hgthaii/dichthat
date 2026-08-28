#!/usr/bin/env bash

set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
scratch_path="/private/tmp/dichthat-swiftpm"
package_cache_path="/private/tmp/dichthat-package-cache"
output_root="/private/tmp/dichthat-app"
app_path="${output_root}/DichThat.app"
installer_background_path="${output_root}/InstallerBackground.png"
version="${DICHTHAT_VERSION:-0.0.0}"
build_number="${DICHTHAT_BUILD_NUMBER:-1}"
signing_identity="${DICHTHAT_CODE_SIGN_IDENTITY:--}"
require_stable_signing="${DICHTHAT_REQUIRE_STABLE_SIGNING:-false}"

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
if [[ "${require_stable_signing}" == "true" && "${signing_identity}" == "-" ]]; then
    printf '%s\n' "A stable code-signing identity is required for release builds." >&2
    exit 1
fi

xcrun swift "${repository_root}/scripts/generate-app-icon.swift" "${repository_root}"
CLANG_MODULE_CACHE_PATH="/private/tmp/dichthat-dmg-clang-cache" \
SWIFTPM_MODULECACHE_OVERRIDE="/private/tmp/dichthat-dmg-swift-cache" \
xcrun swift \
    "${repository_root}/scripts/generate-dmg-background.swift" \
    "${installer_background_path}"

build_architecture() {
    local architecture="$1"
    swift build \
        --package-path "${repository_root}" \
        --disable-sandbox \
        --cache-path "${package_cache_path}" \
        --scratch-path "${scratch_path}" \
        --configuration release \
        --triple "${architecture}-apple-macosx"
}

binary_path_for_architecture() {
    local architecture="$1"
    swift build \
        --package-path "${repository_root}" \
        --disable-sandbox \
        --cache-path "${package_cache_path}" \
        --scratch-path "${scratch_path}" \
        --configuration release \
        --triple "${architecture}-apple-macosx" \
        --show-bin-path
}

build_architecture arm64
build_architecture x86_64

arm64_binary_path="$(binary_path_for_architecture arm64)"
x86_64_binary_path="$(binary_path_for_architecture x86_64)"

rm -rf "${app_path}"
mkdir -p \
    "${app_path}/Contents/MacOS" \
    "${app_path}/Contents/Resources" \
    "${app_path}/Contents/Frameworks"
xcrun lipo -create \
    "${arm64_binary_path}/DichThat" \
    "${x86_64_binary_path}/DichThat" \
    -output "${app_path}/Contents/MacOS/DichThat"
chmod 755 "${app_path}/Contents/MacOS/DichThat"
install -m 644 "${repository_root}/Resources/Info.plist" "${app_path}/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${version}" "${app_path}/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${build_number}" "${app_path}/Contents/Info.plist"
install -m 644 "${repository_root}/Resources/AppIcon.icns" "${app_path}/Contents/Resources/AppIcon.icns"
install -m 644 "${repository_root}/Resources/AppIconDark.png" "${app_path}/Contents/Resources/AppIconDark.png"
install -m 644 "${repository_root}/Resources/AppIconLight.png" "${app_path}/Contents/Resources/AppIconLight.png"
install -m 644 "${repository_root}/Resources/BrandDT.png" "${app_path}/Contents/Resources/BrandDT.png"
install -m 644 "${repository_root}/Resources/StatusItemTemplate.png" "${app_path}/Contents/Resources/StatusItemTemplate.png"
install -m 644 "${installer_background_path}" "${app_path}/Contents/Resources/InstallerBackground.png"
install -m 644 "${repository_root}/Resources/OfflineDictionary.sqlite" \
    "${app_path}/Contents/Resources/OfflineDictionary.sqlite"
if [[ -d "${repository_root}/Resources/ThirdPartyNotices" ]]; then
    /usr/bin/ditto "${repository_root}/Resources/ThirdPartyNotices" \
        "${app_path}/Contents/Resources/ThirdPartyNotices"
fi
/usr/bin/ditto \
    "${arm64_binary_path}/Sparkle.framework" \
    "${app_path}/Contents/Frameworks/Sparkle.framework"

# SwiftPM links dynamic products relative to its build directory. Once the
# executable is moved into an app bundle, it must also search the standard
# Contents/Frameworks directory for Sparkle.
if ! otool -l "${app_path}/Contents/MacOS/DichThat" | grep -F '@executable_path/../Frameworks' >/dev/null; then
    install_name_tool -add_rpath '@executable_path/../Frameworks' \
        "${app_path}/Contents/MacOS/DichThat"
fi

codesign_arguments=(--force --deep --sign "${signing_identity}")
if [[ "${signing_identity}" != "-" ]]; then
    # A private self-signed identity cannot use Apple's timestamp service.
    codesign_arguments+=(--timestamp=none)
fi
codesign "${codesign_arguments[@]}" "${app_path}"

printf '%s\n' "${app_path}"
