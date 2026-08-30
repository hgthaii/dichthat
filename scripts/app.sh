#!/usr/bin/env bash

set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

usage() {
    printf '%s\n' "Usage: $0 build | verify [app-path] | build-and-verify" >&2
}

build_app() {
    local scratch_path="/private/tmp/dichthat-swiftpm"
    local package_cache_path="/private/tmp/dichthat-package-cache"
    local output_root="/private/tmp/dichthat-app"
    local app_path="${output_root}/DichThat.app"
    local installer_background_path="${output_root}/InstallerBackground.png"
    local version="${DICHTHAT_VERSION:-0.0.0}"
    local build_number="${DICHTHAT_BUILD_NUMBER:-1}"
    local signing_identity="${DICHTHAT_CODE_SIGN_IDENTITY:--}"
    local require_stable_signing="${DICHTHAT_REQUIRE_STABLE_SIGNING:-false}"

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
            --product DichThat \
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

    local arm64_binary_path
    local x86_64_binary_path
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
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${version}" \
        "${app_path}/Contents/Info.plist"
    /usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${build_number}" \
        "${app_path}/Contents/Info.plist"
    install -m 644 "${repository_root}/Resources/AppIcon.icns" \
        "${app_path}/Contents/Resources/AppIcon.icns"
    install -m 644 "${repository_root}/Resources/AppIconDark.png" \
        "${app_path}/Contents/Resources/AppIconDark.png"
    install -m 644 "${repository_root}/Resources/AppIconLight.png" \
        "${app_path}/Contents/Resources/AppIconLight.png"
    install -m 644 "${repository_root}/Resources/StatusItemTemplate.png" \
        "${app_path}/Contents/Resources/StatusItemTemplate.png"
    install -m 644 "${installer_background_path}" \
        "${app_path}/Contents/Resources/InstallerBackground.png"
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
    if ! otool -l "${app_path}/Contents/MacOS/DichThat" \
        | grep -F '@executable_path/../Frameworks' >/dev/null; then
        install_name_tool -add_rpath '@executable_path/../Frameworks' \
            "${app_path}/Contents/MacOS/DichThat"
    fi

    local codesign_arguments=(--force --deep --sign "${signing_identity}")
    if [[ "${signing_identity}" != "-" ]]; then
        # A private self-signed identity cannot use Apple's timestamp service.
        codesign_arguments+=(--timestamp=none)
    fi
    codesign "${codesign_arguments[@]}" "${app_path}"

    printf '%s\n' "${app_path}"
}

verify_app() {
    local app_path="${1:-/private/tmp/dichthat-app/DichThat.app}"
    local info_plist="${app_path}/Contents/Info.plist"
    local executable="${app_path}/Contents/MacOS/DichThat"
    local sparkle_framework="${app_path}/Contents/Frameworks/Sparkle.framework"
    local dark_icon="${app_path}/Contents/Resources/AppIconDark.png"
    local light_icon="${app_path}/Contents/Resources/AppIconLight.png"
    local installer_background="${app_path}/Contents/Resources/InstallerBackground.png"
    local offline_dictionary="${app_path}/Contents/Resources/OfflineDictionary.sqlite"
    local attributions="${app_path}/Contents/Resources/ThirdPartyNotices/ATTRIBUTIONS.txt"

    test -d "${app_path}"
    test -f "${info_plist}"
    test -x "${executable}"
    test -d "${sparkle_framework}"
    test -f "${dark_icon}"
    test -f "${light_icon}"
    test -f "${installer_background}"
    test -f "${offline_dictionary}"
    test -f "${attributions}"
    plutil -lint "${info_plist}"
    [[ "$(sqlite3 "${offline_dictionary}" "PRAGMA integrity_check;")" == "ok" ]]
    [[ "$(sqlite3 "${offline_dictionary}" \
        "SELECT value FROM metadata WHERE key='wordnet_version';")" == "2025" ]]
    [[ "$(sqlite3 "${offline_dictionary}" \
        "SELECT value FROM metadata WHERE key='cmudict_commit';")" \
        == "74790861f652b15e4ac49015a90074ad62a27690" ]]
    if grep -R -E 'dictionaryapi\.dev|translate\.googleapis\.com|URLSession' \
        "${repository_root}/Sources/DichThatApp/Services/Translation" >/dev/null; then
        printf '%s\n' "Translation services must remain on-device." >&2
        exit 1
    fi

    local display_name
    local bundle_identifier
    local minimum_system
    local version
    local build_number
    display_name="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleDisplayName' "${info_plist}")"
    bundle_identifier="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "${info_plist}")"
    minimum_system="$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "${info_plist}")"
    version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "${info_plist}")"
    build_number="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "${info_plist}")"

    [[ "${display_name}" == "DichThat" ]]
    [[ "${bundle_identifier}" == "dev.hgthaii.dichthat" ]]
    [[ "${minimum_system}" == "26.0" ]]
    [[ "${version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
    [[ "${build_number}" =~ ^[1-9][0-9]*$ ]]
    otool -l "${executable}" | grep -F '@executable_path/../Frameworks' >/dev/null
    otool -L "${executable}" | grep -F '@rpath/Sparkle.framework/Versions/B/Sparkle' >/dev/null

    if ! lipo "${executable}" -verify_arch arm64 x86_64; then
        printf '%s\n' "DichThat executable must be Universal 2 (arm64 and x86_64)." >&2
        exit 1
    fi

    local architecture
    local deployment_target
    for architecture in arm64 x86_64; do
        deployment_target="$(
            otool -arch "${architecture}" -l "${executable}" \
                | awk '/cmd LC_BUILD_VERSION/ { found = 1 } found && !printed && $1 == "minos" { print $2; printed = 1 }'
        )"
        if [[ "${deployment_target}" != "26.0" ]]; then
            printf '%s\n' \
                "DichThat ${architecture} deployment target must be macOS 26.0." >&2
            exit 1
        fi
    done

    local framework_binary
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
        local signature_details
        local designated_requirement
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
}

command_name="${1:-}"
case "${command_name}" in
    build)
        [[ "$#" -eq 1 ]] || { usage; exit 2; }
        build_app
        ;;
    verify)
        [[ "$#" -le 2 ]] || { usage; exit 2; }
        verify_app "${2:-}"
        ;;
    build-and-verify)
        [[ "$#" -eq 1 ]] || { usage; exit 2; }
        build_app
        verify_app
        ;;
    *)
        usage
        exit 2
        ;;
esac
