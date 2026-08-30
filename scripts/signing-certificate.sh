#!/usr/bin/env bash

set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

usage() {
    printf '%s\n' "Usage: $0 create <output.p12> | import" >&2
}

create_certificate() (
    local output_path="$1"
    local certificate_password="${DICHTHAT_SIGNING_CERTIFICATE_PASSWORD:?Certificate password is required}"
    local working_directory
    working_directory="$(mktemp -d /private/tmp/dichthat-signing-certificate.XXXXXX)"
    local certificate_name="DichThat Self-Signed Release"

    cleanup_creation() {
        rm -rf -- "${working_directory}"
    }
    trap cleanup_creation EXIT
    umask 077

    mkdir -p "$(dirname "${output_path}")"
    openssl req \
        -newkey rsa:3072 \
        -x509 \
        -sha256 \
        -nodes \
        -days 3650 \
        -subj "/CN=${certificate_name}/O=DichThat" \
        -addext "basicConstraints=critical,CA:TRUE" \
        -addext "keyUsage=critical,digitalSignature,keyCertSign" \
        -addext "extendedKeyUsage=codeSigning" \
        -keyout "${working_directory}/private-key.pem" \
        -out "${working_directory}/certificate.pem"

    # LibreSSL otherwise encrypts certificates with RC2-40, which OpenSSL 3 rejects.
    openssl pkcs12 \
        -export \
        -descert \
        -name "${certificate_name}" \
        -inkey "${working_directory}/private-key.pem" \
        -in "${working_directory}/certificate.pem" \
        -passout "pass:${certificate_password}" \
        -out "${output_path}"

    openssl x509 \
        -in "${working_directory}/certificate.pem" \
        -outform der \
        -out "${output_path%.p12}.cer"
    install -m 644 \
        "${working_directory}/certificate.pem" \
        "${output_path%.p12}.pem"

    printf '%s\n' "Created ${output_path}"
    printf '%s\n' "Created ${output_path%.p12}.cer"
    printf '%s\n' "Created ${output_path%.p12}.pem"
)

import_certificate() (
    local pinned_certificate_path="${repository_root}/Resources/DichThatReleaseSigning.pem"
    local certificate_base64="${DICHTHAT_SIGNING_CERTIFICATE_P12_BASE64:?Signing certificate secret is required}"
    local certificate_password="${DICHTHAT_SIGNING_CERTIFICATE_PASSWORD:?Signing certificate password is required}"
    local runner_temp="${RUNNER_TEMP:-/private/tmp}"
    local github_environment="${GITHUB_ENV:?GITHUB_ENV is required}"
    local keychain_path="${runner_temp}/dichthat-signing.keychain-db"
    local certificate_path="${runner_temp}/dichthat-signing.p12"
    local public_certificate_path="${runner_temp}/dichthat-signing.pem"
    local signing_probe_path="${runner_temp}/dichthat-signing-probe"
    local keychain_password
    keychain_password="$(uuidgen)"
    local keychain_created=false
    local import_completed=false

    cleanup_import() {
        rm -f -- "${certificate_path}" "${public_certificate_path}" "${signing_probe_path}"
        if [[ "${keychain_created}" == "true" && "${import_completed}" != "true" ]]; then
            security delete-keychain "${keychain_path}" || true
        fi
    }
    trap cleanup_import EXIT
    umask 077

    printf '%s\n' "Decoding and verifying the release certificate…"
    printf '%s' "${certificate_base64}" | /usr/bin/base64 -D > "${certificate_path}"
    local pkcs12_arguments=(
        -in "${certificate_path}"
        -clcerts
        -nokeys
        -passin "pass:${certificate_password}"
        -out "${public_certificate_path}"
    )
    if openssl version | grep -Eq '^OpenSSL 3([.[:space:]]|$)'; then
        # Existing release secrets may have been exported with LibreSSL's RC2 default.
        pkcs12_arguments=(-legacy "${pkcs12_arguments[@]}")
    fi
    openssl pkcs12 "${pkcs12_arguments[@]}"

    local actual_fingerprint
    local expected_fingerprint
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

    local signing_identity
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

    local current_keychains=()
    local current_keychain
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
)

command_name="${1:-}"
case "${command_name}" in
    create)
        [[ "$#" -eq 2 ]] || { usage; exit 2; }
        create_certificate "$2"
        ;;
    import)
        [[ "$#" -eq 1 ]] || { usage; exit 2; }
        import_certificate
        ;;
    *)
        usage
        exit 2
        ;;
esac
