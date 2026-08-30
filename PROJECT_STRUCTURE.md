# Project structure

```text
DichThat/
├── .github/
│   ├── ISSUE_TEMPLATE/
│   │   ├── bug_report.yml
│   │   ├── config.yml
│   │   └── feature_request.yml
│   ├── workflows/
│   │   ├── codeql.yml
│   │   ├── dependency-review.yml
│   │   └── release.yml
│   ├── dependabot.yml
│   └── pull_request_template.md
├── Resources/
│   ├── AppIcon.icns
│   ├── AppIconDark.png
│   ├── AppIconLight.png
│   ├── AppIconSource.png
│   ├── BrandDT.png
│   ├── DichThatReleaseSigning.pem
│   ├── Info.plist
│   ├── OfflineDictionary.sqlite
│   ├── StatusItemTemplate.png
│   └── ThirdPartyNotices/
├── Sources/
│   ├── DichThatApp/
│   │   ├── App/
│   │   │   └── AppDelegate.swift
│   │   ├── Configuration/
│   │   │   └── AppConfiguration.swift
│   │   ├── Features/
│   │   │   ├── QuickTranslate/
│   │   │   │   ├── Accessibility/
│   │   │   │   ├── Capture/
│   │   │   │   └── Selection/
│   │   │   └── Settings/
│   │   ├── Services/
│   │   │   ├── Shortcuts/
│   │   │   ├── System/
│   │   │   ├── Translation/
│   │   │   └── Updates/
│   │   ├── Support/
│   │   ├── UI/
│   │   │   ├── Components/
│   │   │   └── Translation/
│   │   └── main.swift
│   └── DichThatCore/
│       ├── Configuration/
│       ├── MenuBar/
│       ├── Preferences/
│       ├── QuickTranslate/
│       ├── Settings/
│       ├── Shortcuts/
│       ├── Translation/
│       │   ├── Models/
│       │   ├── OfflineDictionary/
│       │   ├── Providers/
│       │   ├── Routing/
│       │   ├── Speech/
│       │   └── State/
│       └── Updates/
├── Tests/
│   └── DichThatCoreTests/
│       ├── Configuration/
│       ├── MenuBar/
│       ├── Preferences/
│       ├── QuickTranslate/
│       ├── Settings/
│       ├── Shortcuts/
│       ├── Translation/
│       └── Updates/
├── Tools/
│   └── OfflineDictionaryBuilder/
│       └── main.swift
├── scripts/
│   ├── app.sh
│   ├── build-dmg.sh
│   ├── build-offline-dictionary.sh
│   ├── generate-app-icon.swift
│   ├── generate-dmg-background.swift
│   ├── release.sh
│   ├── signing-certificate.sh
│   └── verify-sparkle-signature.swift
├── AGENTS.md
├── CONTRIBUTING.md
├── LICENSE
├── MDD.md
├── Package.resolved
├── Package.swift
├── PROJECT_STRUCTURE.md
├── README.en.md
├── README.md
└── SECURITY.md
```

## Boundaries

- `DichThatCore` contains platform-independent models, policies, state machines, routing, parsing, and geometry.
- `DichThatApp` contains AppKit UI and macOS integrations such as Accessibility, clipboard, shortcuts, speech, login items, Translation, and Sparkle.
- `Tests/DichThatCoreTests` mirrors the core behavior by feature area.
- `Resources` contains shipped app assets, the offline dictionary, release certificate, and third-party notices.
- `Tools` builds repository-owned data; `scripts` builds, verifies, signs, and packages the app.
- `.github` contains pull-request checks, dependency automation, and contributor templates.
- Generated app and DMG artifacts are written outside the source tree or under ignored output directories.
