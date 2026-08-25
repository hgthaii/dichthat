// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "DichThat",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .library(name: "DichThatCore", targets: ["DichThatCore"]),
        .executable(name: "DichThat", targets: ["DichThatApp"]),
    ],
    dependencies: [],
    targets: [
        .target(name: "DichThatCore"),
        .executableTarget(
            name: "DichThatApp",
            dependencies: ["DichThatCore"],
            swiftSettings: [
                // AppKit invokes Objective-C entry points on the main thread
                // without entering a Swift task executor. Static actor
                // isolation remains enforced; unsafe callback boundaries are
                // bridged explicitly before touching main-actor state.
                .unsafeFlags([
                    "-Xfrontend",
                    "-disable-dynamic-actor-isolation",
                ]),
            ]
        ),
        .testTarget(
            name: "DichThatCoreTests",
            dependencies: ["DichThatCore"]
        ),
    ]
)
