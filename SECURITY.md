# Security policy

## Supported versions

Security fixes are provided for the latest published release of DichThat.
Older releases may no longer receive fixes, so users should update before
reporting an issue that is already resolved in the latest version.

| Version | Supported |
| --- | --- |
| Latest release | Yes |
| Older releases | No |

## Reporting a vulnerability

Please do not open a public issue for a suspected vulnerability. Use
[GitHub private vulnerability reporting](https://github.com/hgthaii/dichthat/security/advisories/new)
so the report and any proof of concept remain private while the issue is
investigated.

Include only the information needed to reproduce and assess the issue:

- the affected DichThat and macOS versions;
- the expected and observed behavior;
- minimal reproduction steps;
- the security impact and any known mitigations; and
- sanitized logs or screenshots, when useful.

Never include selected text, clipboard contents, translation content, signing
keys, credentials, or other personal data in a report. The maintainer will
acknowledge the report as soon as practical, coordinate remediation, and agree
on disclosure timing before details are published.

## Scope

Reports involving selection capture, clipboard restoration, update integrity,
release signing, unintended data retention, or arbitrary code execution are
especially important. General bugs and feature requests should use
[GitHub Issues](https://github.com/hgthaii/dichthat/issues).
