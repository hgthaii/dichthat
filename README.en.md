<p align="center">
  <img src="Resources/AppIconSource.png" width="112" alt="DichThat icon">
</p>

<h1 align="center">DichThat</h1>

<p align="center">
  Fast English ↔ Vietnamese translation wherever you are reading on macOS.
</p>

<p align="center">
  <a href="README.md">Tiếng Việt</a> ·
  <a href="README.en.md"><strong>English</strong></a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-13%2B-000000?logo=apple&logoColor=white" alt="macOS 13+">
  <img src="https://img.shields.io/badge/Swift-6.0-F05138?logo=swift&logoColor=white" alt="Swift 6.0">
  <img src="https://img.shields.io/badge/translation-VI%20%E2%86%94%20EN-34C759" alt="Vietnamese and English">
  <img src="https://img.shields.io/github/v/release/hgthaii/dichthat?display_name=tag&sort=semver" alt="Latest release">
  <a href="https://github.com/hgthaii/dichthat/actions/workflows/release.yml"><img src="https://github.com/hgthaii/dichthat/actions/workflows/release.yml/badge.svg" alt="CI/CD"></a>
</p>

## Introduction

DichThat is a small macOS menu-bar app. Select some text, press a shortcut, and read the translation next to it—without switching to another app.

It automatically detects English or Vietnamese and translates into the other language.
Releases support both Apple Silicon and Intel Macs running macOS 13 or later.

## Highlights

- Translate selected text with a customizable shortcut.
- Type a word or sentence directly from the menu bar.
- See pronunciation, meanings, examples, and synonyms for English words.
- Listen using voices available on macOS.
- Start automatically when you sign in, if enabled.
- Download and install new versions directly from the app.
- Clean interface with Light Mode and Dark Mode support.

## How to use

1. Open the DMG, drag DichThat to **Applications**, then open it from there.
2. If macOS blocks the first launch, use **Privacy & Security → Open Anyway**.
3. Grant **Accessibility** access from Settings.
4. Select English or Vietnamese text and press the default `⌃⌥T` shortcut.
5. The translation appears next to your selected text.

You can also click the DichThat menu-bar icon and type what you want to translate.

## Privacy

- DichThat does not keep translation history.
- It does not log selected text or clipboard contents.
- Text submitted for translation is sent to an online translation service.
- Bug reports include only necessary system details, never your translated content.

## Report a bug

Open **Settings → About → Report a Bug** to create a report with helpful details, or visit [GitHub Issues](https://github.com/hgthaii/dichthat/issues).

## For developers

Requires macOS 13 or later and Swift 6.

```bash
swift test
bash scripts/build-app.sh
bash scripts/verify-app.sh
bash scripts/build-dmg.sh
```

The app is written to `/private/tmp/dichthat-app/DichThat.app`; the DMG is written to `dist/`.
