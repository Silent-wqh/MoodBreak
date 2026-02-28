// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MoodBreak",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "MoodBreak"
        ),
        .testTarget(
            name: "MoodBreakTests",
            dependencies: ["MoodBreak"]
        ),
    ]
)
