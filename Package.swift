// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OkJson",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "OkJson",
            targets: ["OkJson"]
        )
    ],
    dependencies: [
        // No external dependencies - uses only native frameworks
    ],
    targets: [
        .executableTarget(
            name: "OkJson",
            dependencies: [],
            path: "OkJson",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "OkJsonTests",
            dependencies: ["OkJson"],
            path: "Tests"
        )
    ]
)
