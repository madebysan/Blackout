// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "TapDim",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.0.0")
    ],
    targets: [
        .executableTarget(
            name: "TapDim",
            dependencies: [
                "KeyboardShortcuts"
            ],
            path: "Sources/TapDim"
        ),
        .testTarget(
            name: "TapDimTests",
            dependencies: ["TapDim"],
            path: "Tests/TapDimTests"
        )
    ]
)
