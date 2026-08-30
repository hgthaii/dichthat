// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "DichThat",
    platforms: [
        .macOS("26.0"),
    ],
    products: [
        .library(name: "DichThatCore", targets: ["DichThatCore"]),
        .executable(name: "DichThat", targets: ["DichThatApp"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/sparkle-project/Sparkle",
            exact: "2.9.6"
        ),
    ],
    targets: [
        .target(name: "DichThatCore"),
        .executableTarget(
            name: "DichThatApp",
            dependencies: [
                "DichThatCore",
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            swiftSettings: [
                // AppKit invokes Objective-C entry points on the main thread
                // without entering a Swift task executor. Static actor
                // isolation remains enforced; unsafe callback boundaries are
                // bridged explicitly before touching main-actor state.
                .unsafeFlags([
                    "-Xfrontend",
                    "-disable-dynamic-actor-isolation",
                ]),
            ],
            linkerSettings: [.linkedLibrary("sqlite3")]
        ),
        .executableTarget(
            name: "OfflineDictionaryBuilder",
            dependencies: ["DichThatCore"],
            path: "Tools/OfflineDictionaryBuilder",
            linkerSettings: [.linkedLibrary("sqlite3")]
        ),
        .testTarget(
            name: "DichThatCoreTests",
            dependencies: ["DichThatCore"]
        ),
    ]
)
