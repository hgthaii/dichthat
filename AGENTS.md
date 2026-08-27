# Agent Instructions

## Project

DichThat is a native macOS menu-bar app for fast English ↔ Vietnamese translation.

- Language: Swift 6
- UI: AppKit
- Minimum system: macOS 13
- Package targets: `DichThatCore` and `DichThatApp`
- Product name: `DichThat`
- Bundle ID: `dev.hgthaii.dichthat`

The old `.ai/workflow` process is no longer used. Work directly in the repository and do not require task packets, leases, Worker/Auditor roles, or subagents.

## Working rules

1. Read the relevant source and tests before editing.
2. Preserve unrelated and user-owned changes in the dirty worktree.
3. Do not commit, push, create tags, publish releases, or change external state unless the user explicitly asks.
4. Keep changes focused on the requested behavior. Avoid speculative features and broad rewrites.
5. Diagnose crashes from the latest `DichThat-*.ips` report in `~/Library/Logs/DiagnosticReports` before attempting a fix.
6. Never log or persist selected text, clipboard contents, translation history, or other user content.

## Source layout

```text
Sources/
├── DichThatApp/
│   ├── App/             # Application lifecycle and coordination
│   ├── Configuration/   # AppKit layout, timing, resources, feature flags
│   ├── Features/        # Quick Translate and Settings
│   ├── Services/        # Shortcuts, system APIs, translation, updates
│   ├── Support/         # App-only helpers
│   └── UI/              # Shared AppKit components and translation UI
└── DichThatCore/
    ├── Configuration/   # Identity, user-facing text, core tunables
    ├── MenuBar/
    ├── Preferences/
    ├── QuickTranslate/
    ├── Settings/
    ├── Shortcuts/
    ├── Translation/
    └── Updates/
```

Keep platform-independent models, policies, state machines, parsing, and geometry in `DichThatCore`. Keep AppKit, Accessibility, Carbon, clipboard, speech, networking, and workspace integration in `DichThatApp`.

Mirror new core behavior with tests under the corresponding folder in `Tests/DichThatCoreTests`.

## Product invariants

- Support only English and Vietnamese for the MVP.
- Automatically detect the source language and translate into the other supported language.
- Prefer Accessibility capture. Use clipboard fallback only when needed and restore the clipboard using the guarded transaction contract.
- Prefer confirmed selection bounds or the observed selection anchor for popup placement. Do not replace a valid selection anchor with the mouse position.
- Repeated shortcuts must be single-flight, cancellable, and safe from stale completions.
- Keep the global shortcut inactive while Settings is open and restore it when Settings closes.
- Permission changes must refresh or relaunch integrations safely without creating duplicate app instances.
- The selected-text icon remains behind `AppConfiguration.Features.selectionIconEnabled` and is currently disabled.
- Use public macOS APIs only.

## UI guidelines

- Keep the interface minimal, compact, and understandable to nontechnical users.
- Use semantic macOS colors and support Light Mode and Dark Mode.
- Use AppKit controls unless a custom control is necessary to fix a verified behavior.
- Translation and Settings windows close when the user clicks outside them.
- Avoid adding decorative detail, complex navigation, or System Settings imitation without an explicit request.
- Preserve keyboard behavior such as `Command-A` in editable fields.

## Configuration and text

Do not scatter product constants or user-facing strings through controllers.

- App-only layout and timing: `Sources/DichThatApp/Configuration/AppConfiguration.swift`
- Core limits and endpoints: `Sources/DichThatCore/Configuration/CoreConfiguration.swift`
- Product identity: `Sources/DichThatCore/Configuration/AppIdentity.swift`
- User-facing strings: `Sources/DichThatCore/Configuration/AppText.swift`

Release tags use the form `vX.Y.Z` and are the only source of release versions. Build scripts inject the tag version into the app bundle; do not hard-code release versions in Swift or source `Info.plist`.

## Validation

Run validation in proportion to the change. The standard commands are:

```bash
swift test
bash scripts/build-app.sh
bash scripts/verify-app.sh
bash scripts/build-dmg.sh
```

- `swift test` is required for core behavior changes.
- Build and verify the app for AppKit, resource, packaging, or lifecycle changes.
- Build and verify the DMG for release or packaging changes.
- Run `git diff --check` before handing off.
- Do not claim interactive macOS behavior was verified unless it was actually exercised.

The generated artifacts are:

```text
/private/tmp/dichthat-app/DichThat.app
dist/DichThat-X.Y.Z.dmg
```

## CI/CD and releases

`.github/workflows/release.yml` runs tests and builds a verified app artifact for pushes and pull requests. `vX.Y.Z` tags build a DMG, a Sparkle update archive and appcast, then create a GitHub Release.

Sparkle update archives are signed with EdDSA. Never write the private key to the repository or logs; CI reads it only from the `SPARKLE_EDDSA_PRIVATE_KEY` GitHub Secret.

Pull-request and ordinary local builds may use ad-hoc signing. Tagged releases use the pinned DichThat self-signed certificate so their designated requirement remains stable across updates. Do not describe releases as Developer ID signed or notarized until Developer ID signing, notarization, and stapling are actually configured and verified.

## Documentation

- `README.md` is the default Vietnamese README.
- `README.en.md` is the matching English README.
- Keep both concise, nontechnical, and synchronized when product-facing behavior changes.
- Update `docs/` only when the corresponding product or architecture decision changes.
