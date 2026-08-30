## Summary

- What changed?
- Why is this change needed?

## Validation

- [ ] `swift test`
- [ ] `bash scripts/app.sh build-and-verify` when app behavior or packaging changed
- [ ] `bash scripts/build-dmg.sh` when release packaging changed
- [ ] `git diff --check`
- [ ] Interactive behavior was exercised, or the unverified path is described below

## Privacy and safety

- [ ] No selected text, clipboard contents, translation history, credentials, or other user content is logged, persisted, or included in fixtures
- [ ] Clipboard fallback still uses guarded restoration when affected
- [ ] No signing key or private certificate material is committed
- [ ] The change uses public macOS APIs

## Documentation

- [ ] User-facing behavior is reflected in both `README.md` and `README.en.md`, or no README change is needed
- [ ] Architecture or feature-flow documentation is updated when affected

## Notes

List known limitations, screenshots, or validation that could not be completed.
