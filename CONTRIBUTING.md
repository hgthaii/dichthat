# Contributing to DichThat

Thank you for helping improve DichThat. Keep contributions focused, reviewable,
and consistent with the app's privacy boundary.

## Requirements

- macOS 26 or later
- Swift 6
- Xcode with the macOS 26 SDK

## Project boundaries

- Put platform-independent models, policies, state machines, parsing, and
  geometry in `DichThatCore`.
- Keep AppKit, Accessibility, clipboard, shortcuts, speech, networking, login
  items, and workspace integration in `DichThatApp`.
- Mirror new core behavior under the matching folder in
  `Tests/DichThatCoreTests`.
- Keep user-facing strings in `AppText.swift` and product constants in the
  appropriate configuration file.

See [PROJECT_STRUCTURE.md](PROJECT_STRUCTURE.md) for the source tree and
[MDD.md](MDD.md) for the implemented feature flows.

## Privacy and security

- Never log or persist selected text, clipboard contents, translation history,
  or other user content.
- Preserve the guarded clipboard snapshot and restoration contract.
- Use public macOS APIs only.
- Never commit signing keys, certificates containing private keys, credentials,
  or real user content in test fixtures.
- Report suspected vulnerabilities through the private channel described in
  [SECURITY.md](SECURITY.md), not through a public issue.

## Development workflow

1. Create a focused branch from the current default branch.
2. Make the smallest change that solves the issue.
3. Add or update tests for changed core behavior.
4. Run validation in proportion to the change:

   ```bash
   swift test
   bash scripts/app.sh build-and-verify
   bash scripts/build-dmg.sh # packaging or release changes only
   git diff --check
   ```

5. Open a pull request using the repository template and describe any validation
   that could not be completed.

Run `bash scripts/build-offline-dictionary.sh` only when intentionally updating
the bundled dictionary sources.

## Pull requests

- Keep unrelated cleanup out of the same pull request.
- Explain user-visible behavior and important tradeoffs.
- Do not claim interactive macOS behavior was verified unless it was exercised.
- Keep `README.md` and `README.en.md` synchronized when product-facing behavior
  changes.
- Do not manually hard-code a release version; release tags are the source of
  truth.
