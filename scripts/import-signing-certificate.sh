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
signing_probe_path="${runner_temp}/dichthat-signing-probe"
keychain_password="$(uuidgen)"
keychain_created=false
import_completed=false

cleanup_certificate() {
    rm -f -- "${certificate_path}" "${public_certificate_path}" "${signing_probe_path}"
    if [[ "${keychain_created}" == "true" && "${import_completed}" != "true" ]]; then
        security delete-keychain "${keychain_path}" || true
    fi
}
trap cleanup_certificate EXIT
umask 077

printf '%s\n' "Decoding and verifying the release certificate…"
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

signing_identity="$(
    openssl x509 \
        -in "${public_certificate_path}" \
        -noout \
        -fingerprint \
        -sha1 \
        | sed -E 's/^[^=]+=//; s/://g'
)"
if [[ ! "${signing_identity}" =~ ^[0-9A-Fa-f]{40}$ ]]; then
    printf '%s\n' "Could not resolve the release certificate fingerprint." >&2
    exit 1
fi

printf '%s\n' "Creating a temporary signing keychain…"
security create-keychain -p "${keychain_password}" "${keychain_path}"
keychain_created=true
security set-keychain-settings -lut 21600 "${keychain_path}"
security unlock-keychain -p "${keychain_password}" "${keychain_path}"

printf '%s\n' "Importing the release signing identity…"
security import "${certificate_path}" \
    -k "${keychain_path}" \
    -P "${certificate_password}" \
    -T /usr/bin/codesign

printf '%s\n' "Granting non-interactive codesign access…"
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

printf '%s\n' "Validating the imported signing identity…"
/bin/cp /usr/bin/true "${signing_probe_path}"
codesign \
    --force \
    --sign "${signing_identity}" \
    --timestamp=none \
    "${signing_probe_path}"
codesign --verify --strict "${signing_probe_path}"

printf 'DICHTHAT_CODE_SIGN_IDENTITY=%s\n' "${signing_identity}" >> "${github_environment}"
printf 'DICHTHAT_SIGNING_KEYCHAIN=%s\n' "${keychain_path}" >> "${github_environment}"
import_completed=true
printf '%s\n' "Release signing identity is ready."
