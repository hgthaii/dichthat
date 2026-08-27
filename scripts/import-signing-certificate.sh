#!/usr/bin/env bash

set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
pinned_certificate_path="${repository_root}/Resources/DichThatReleaseSigning.pem"
certificate_base64="${DICHTHAT_SIGNING_CERTIFICATE_P12_BASE64:?Signing certificate secret is required}"
certificate_password="${DICHTHAT_SIGNING_CERTIFICATE_PASSWORD:?Signing certificate password is required}"
runner_temp="${RUNNER_TEMP:-/private/tmp}"
github_environment="${GITHUB_ENV:?GITHUB_ENV is required}"
keychain_path="${runner_temp}/dichthat-signing.keychain-db"
certificate_path="${runner_temp}/dichthat-signing.p12"
public_certificate_path="${runner_temp}/dichthat-signing.pem"
keychain_password="$(uuidgen)"
keychain_created=false
import_completed=false

cleanup_certificate() {
    rm -f -- "${certificate_path}" "${public_certificate_path}"
    if [[ "${keychain_created}" == "true" && "${import_completed}" != "true" ]]; then
        security delete-keychain "${keychain_path}" || true
    fi
}
trap cleanup_certificate EXIT
umask 077

printf '%s' "${certificate_base64}" | /usr/bin/base64 -D > "${certificate_path}"
openssl pkcs12 \
    -in "${certificate_path}" \
    -clcerts \
    -nokeys \
    -passin "pass:${certificate_password}" \
    -out "${public_certificate_path}"
actual_fingerprint="$(
    openssl x509 -in "${public_certificate_path}" -noout -fingerprint -sha256
)"
expected_fingerprint="$(
    openssl x509 -in "${pinned_certificate_path}" -noout -fingerprint -sha256
)"
if [[ "${actual_fingerprint}" != "${expected_fingerprint}" ]]; then
    printf '%s\n' "Signing certificate does not match the pinned DichThat identity." >&2
    exit 1
fi
security create-keychain -p "${keychain_password}" "${keychain_path}"
keychain_created=true
security set-keychain-settings -lut 21600 "${keychain_path}"
security unlock-keychain -p "${keychain_password}" "${keychain_path}"
security import "${certificate_path}" \
    -k "${keychain_path}" \
    -P "${certificate_password}" \
    -T /usr/bin/codesign
security add-trusted-cert \
    -r trustRoot \
    -k "${keychain_path}" \
    "${public_certificate_path}"
security set-key-partition-list \
    -S apple-tool:,apple: \
    -s \
    -k "${keychain_password}" \
    "${keychain_path}" >/dev/null

current_keychains=()
while IFS= read -r current_keychain; do
    current_keychain="${current_keychain//\"/}"
    current_keychain="${current_keychain#${current_keychain%%[![:space:]]*}}"
    [[ -n "${current_keychain}" ]] && current_keychains+=("${current_keychain}")
done < <(security list-keychains -d user)
security list-keychains -d user -s "${keychain_path}" "${current_keychains[@]}"

signing_identity="$(
    security find-identity -v -p codesigning "${keychain_path}" \
        | awk '$1 ~ /^[0-9]+\)$/ { print $2; exit }'
)"
if [[ -z "${signing_identity}" ]]; then
    printf '%s\n' "No valid code-signing identity was imported." >&2
    exit 1
fi

printf 'DICHTHAT_CODE_SIGN_IDENTITY=%s\n' "${signing_identity}" >> "${github_environment}"
printf 'DICHTHAT_SIGNING_KEYCHAIN=%s\n' "${keychain_path}" >> "${github_environment}"
import_completed=true
