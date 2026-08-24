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
            dependencies: ["DichThatCore"]
        ),
        .testTarget(
            name: "DichThatCoreTests",
            dependencies: ["DichThatCore"]
        ),
    ]
)
