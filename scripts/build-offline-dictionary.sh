#!/usr/bin/env bash

set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
work_directory="$(mktemp -d /private/tmp/dichthat-dictionary.XXXXXX)"
trap 'rm -rf "${work_directory}"' EXIT

wordnet_url="https://en-word.net/downloads/english-wordnet-2025-json.zip"
wordnet_checksum="7d749f6e2c39e6970e4997839dcf6e42fd281f3c2fae0171d2192bae8cfa4b51"
cmudict_commit="74790861f652b15e4ac49015a90074ad62a27690"
cmudict_url="https://raw.githubusercontent.com/cmusphinx/cmudict/${cmudict_commit}/cmudict.dict"
cmudict_checksum="81917843c7f44ce2b094ac63873c2c7a4cf802040792c455ba3ca406891c3d22"

verify_checksum() {
    local file_path="$1"
    local expected="$2"
    local actual
    actual="$(shasum -a 256 "${file_path}" | awk '{print $1}')"
    if [[ "${actual}" != "${expected}" ]]; then
        printf '%s\n' "Checksum mismatch for ${file_path}" >&2
        exit 1
    fi
}

curl --fail --location --silent --show-error "${wordnet_url}" \
    --output "${work_directory}/wordnet.zip"
curl --fail --location --silent --show-error "${cmudict_url}" \
    --output "${work_directory}/cmudict.dict"
verify_checksum "${work_directory}/wordnet.zip" "${wordnet_checksum}"
verify_checksum "${work_directory}/cmudict.dict" "${cmudict_checksum}"

mkdir -p "${work_directory}/wordnet"
ditto -x -k "${work_directory}/wordnet.zip" "${work_directory}/wordnet"

CLANG_MODULE_CACHE_PATH="/private/tmp/dichthat-dictionary-clang-cache" \
SWIFTPM_MODULECACHE_OVERRIDE="/private/tmp/dichthat-dictionary-swift-cache" \
swift run \
    --package-path "${repository_root}" \
    --disable-sandbox \
    --scratch-path "/private/tmp/dichthat-dictionary-build" \
    OfflineDictionaryBuilder \
    --wordnet "${work_directory}/wordnet" \
    --cmudict "${work_directory}/cmudict.dict" \
    --output "${repository_root}/Resources/OfflineDictionary.sqlite"
