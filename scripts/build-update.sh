#!/usr/bin/env bash

set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
version="${DICHTHAT_VERSION:?DICHTHAT_VERSION is required}"
private_key="${SPARKLE_EDDSA_PRIVATE_KEY:-}"
release_tag="v${version}"
release_base_url="https://github.com/hgthaii/dichthat/releases/download/${release_tag}/"
output_directory="${repository_root}/dist"
archive_name="DichThat-${version}.zip"
staging_directory="$(mktemp -d /private/tmp/dichthat-update.XXXXXX)"

if [[ "${CI:-}" == "true" && -z "${private_key}" ]]; then
    printf '%s\n' "Missing SPARKLE_EDDSA_PRIVATE_KEY in CI." >&2
    exit 1
fi

cleanup() {
    rm -rf -- "${staging_directory}"
}
trap cleanup EXIT

bash "${repository_root}/scripts/build-app.sh"
mkdir -p "${output_directory}"
/usr/bin/ditto \
    -c -k --sequesterRsrc --keepParent \
    /private/tmp/dichthat-app/DichThat.app \
    "${staging_directory}/${archive_name}"

generate_appcast="$(find /private/tmp/dichthat-swiftpm/artifacts -type f -name generate_appcast -print -quit)"
test -x "${generate_appcast}"

appcast_arguments=(
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

/usr/bin/ditto "${staging_directory}/${archive_name}" "${output_directory}/${archive_name}"
install -m 644 "${staging_directory}/appcast.xml" "${output_directory}/appcast.xml"

printf '%s\n' "${output_directory}/${archive_name}"
printf '%s\n' "${output_directory}/appcast.xml"
