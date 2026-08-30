#!/usr/bin/env bash

set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

usage() {
    printf '%s\n' \
        "Usage: $0 build-update | verify <dmg-path> <sparkle-zip-path> <appcast-path>" >&2
}

build_update() (
    local version="${DICHTHAT_VERSION:?DICHTHAT_VERSION is required}"
    local private_key="${SPARKLE_EDDSA_PRIVATE_KEY:-}"
    local release_tag="v${version}"
    local release_base_url="https://github.com/hgthaii/dichthat/releases/download/${release_tag}/"
    local output_directory="${repository_root}/dist"
    local archive_name="DichThat-${version}.zip"
    local staging_directory
    staging_directory="$(mktemp -d /private/tmp/dichthat-update.XXXXXX)"

    if [[ "${CI:-}" == "true" && -z "${private_key}" ]]; then
        printf '%s\n' "Missing SPARKLE_EDDSA_PRIVATE_KEY in CI." >&2
        exit 1
    fi

    cleanup_update() {
        rm -rf -- "${staging_directory}"
    }
    trap cleanup_update EXIT

    bash "${repository_root}/scripts/app.sh" build
    mkdir -p "${output_directory}"
    /usr/bin/ditto \
        -c -k --sequesterRsrc --keepParent \
        /private/tmp/dichthat-app/DichThat.app \
        "${staging_directory}/${archive_name}"

    local generate_appcast
    generate_appcast="$(
        find /private/tmp/dichthat-swiftpm/artifacts \
            -type f -name generate_appcast -print -quit
    )"
    test -x "${generate_appcast}"

    local appcast_arguments=(
        --download-url-prefix "${release_base_url}"
        --link "https://github.com/hgthaii/dichthat"
        --maximum-deltas 0
        "${staging_directory}"
    )
    if [[ -n "${private_key}" ]]; then
        printf '%s' "${private_key}" | "${generate_appcast}" \
            --ed-key-file - \
            "${appcast_arguments[@]}"
    else
        "${generate_appcast}" \
            --account dev.hgthaii.dichthat \
            "${appcast_arguments[@]}"
    fi

    /usr/bin/ditto \
        "${staging_directory}/${archive_name}" \
        "${output_directory}/${archive_name}"
    install -m 644 "${staging_directory}/appcast.xml" "${output_directory}/appcast.xml"

    printf '%s\n' "${output_directory}/${archive_name}"
    printf '%s\n' "${output_directory}/appcast.xml"
)

verify_release() (
    local dmg_path="$1"
    local archive_path="$2"
    local appcast_path="$3"
    local version="${DICHTHAT_VERSION:?DICHTHAT_VERSION is required}"
    local working_directory
    working_directory="$(mktemp -d /private/tmp/dichthat-release-verification.XXXXXX)"
    local mount_directory="${working_directory}/mounted-dmg"
    local archive_directory="${working_directory}/archive"
    local dmg_app_copy_path="${working_directory}/dmg-app/DichThat.app"
    local dmg_is_mounted=false

    cleanup_verification() {
        if [[ "${dmg_is_mounted}" == "true" ]]; then
            hdiutil detach "${mount_directory}" -quiet || true
        fi
        rm -rf -- "${working_directory}"
    }
    trap cleanup_verification EXIT

    test -f "${dmg_path}"
    test -f "${archive_path}"
    test -f "${appcast_path}"
    [[ "$(basename "${dmg_path}")" == "DichThat.dmg" ]]
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

    bash "${repository_root}/scripts/app.sh" verify \
        "${mount_directory}/DichThat.app"
    test ! -e "${mount_directory}/.background"
    if [[ "${DICHTHAT_REQUIRE_STABLE_SIGNING:-false}" == "true" ]]; then
        mkdir -p "$(dirname "${dmg_app_copy_path}")"
        /usr/bin/ditto "${mount_directory}/DichThat.app" "${dmg_app_copy_path}"
    fi

    hdiutil detach "${mount_directory}" -quiet
    dmg_is_mounted=false

    /usr/bin/ditto -x -k "${archive_path}" "${archive_directory}"
    local archive_app_path
    archive_app_path="$(
        find "${archive_directory}" -maxdepth 2 -type d -name DichThat.app -print -quit
    )"
    test -n "${archive_app_path}"
    bash "${repository_root}/scripts/app.sh" verify "${archive_app_path}"

    if [[ "${DICHTHAT_REQUIRE_STABLE_SIGNING:-false}" == "true" ]]; then
        local dmg_requirement="${working_directory}/dmg-requirement.txt"
        local archive_requirement="${working_directory}/archive-requirement.txt"
        codesign -d -r- "${dmg_app_copy_path}" 2>&1 \
            | sed -nE 's/^#? ?designated => //p' > "${dmg_requirement}"
        codesign -d -r- "${archive_app_path}" 2>&1 \
            | sed -nE 's/^#? ?designated => //p' > "${archive_requirement}"
        codesign --verify --deep --strict -R "${dmg_requirement}" "${archive_app_path}"
        codesign --verify --deep --strict -R "${archive_requirement}" \
            "${dmg_app_copy_path}"
    fi

    local appcast_version
    local appcast_build_number
    local appcast_archive_url
    local appcast_signature
    local appcast_hardware_requirements
    local expected_archive_url
    appcast_version="$(
        xmllint --xpath 'string(//*[local-name()="shortVersionString"][1])' "${appcast_path}"
    )"
    appcast_build_number="$(
        xmllint --xpath 'string(//*[local-name()="version"][1])' "${appcast_path}"
    )"
    appcast_archive_url="$(
        xmllint --xpath 'string(//*[local-name()="enclosure"]/@url)' "${appcast_path}"
    )"
    appcast_signature="$(
        xmllint --xpath \
            'string(//*[local-name()="enclosure"]/@*[local-name()="edSignature"])' \
            "${appcast_path}"
    )"
    appcast_hardware_requirements="$(
        xmllint --xpath 'string(//*[local-name()="hardwareRequirements"][1])' \
            "${appcast_path}"
    )"
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
)

command_name="${1:-}"
case "${command_name}" in
    build-update)
        [[ "$#" -eq 1 ]] || { usage; exit 2; }
        build_update
        ;;
    verify)
        [[ "$#" -eq 4 ]] || { usage; exit 2; }
        verify_release "$2" "$3" "$4"
        ;;
    *)
        usage
        exit 2
        ;;
esac
