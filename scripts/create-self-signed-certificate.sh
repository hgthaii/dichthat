#!/usr/bin/env bash

set -euo pipefail

output_path="${1:?Output .p12 path is required}"
certificate_password="${DICHTHAT_SIGNING_CERTIFICATE_PASSWORD:?Certificate password is required}"
working_directory="$(mktemp -d /private/tmp/dichthat-signing-certificate.XXXXXX)"
certificate_name="DichThat Self-Signed Release"

cleanup() {
    rm -rf -- "${working_directory}"
}
trap cleanup EXIT
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
