// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BoyScoutAgent",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "bsa", targets: ["bsa"])],
    dependencies: [
        .package(url: "https://github.com/tadija/swift-agent.git", .upToNextMinor(from: "0.1.0"))
    ],
    targets: [
        .target(name: "BoyScoutAgent", dependencies: [
            .product(name: "SwiftAgent", package: "swift-agent")
        ], plugins: ["EmbedMission"]),
        .plugin(name: "EmbedMission", capability: .buildTool()),
        .plugin(name: "BSABuildVersion", capability: .buildTool()),
        .executableTarget(name: "bsa", dependencies: [
            .product(name: "SwiftAgent", package: "swift-agent"),
            .product(name: "SwiftAgentCLI", package: "swift-agent"), "BoyScoutAgent"
        ], plugins: ["BSABuildVersion"]),
        .testTarget(name: "BoyScoutAgentTests", dependencies: [
            "BoyScoutAgent", .product(name: "SwiftAgent", package: "swift-agent")
        ])
    ]
)
