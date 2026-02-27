// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "WordDuelCore",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "WordDuelCore",
            targets: ["WordDuelCore"]
        )
    ],
    targets: [
        .target(
            name: "WordDuelCore",
            path: "Sources/WordDuelCore"
        ),
        .testTarget(
            name: "WordDuelCoreTests",
            dependencies: ["WordDuelCore"],
            path: "Tests/WordDuelCoreTests"
        )
    ]
)
