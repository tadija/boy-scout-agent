// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BoyScoutAgent",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "SwiftAgent", targets: ["SwiftAgent"]),
        .library(name: "SwiftAgentCLI", targets: ["SwiftAgentCLI"]),
        .executable(name: "bsa", targets: ["bsa"]),
        .executable(name: "swift-agent", targets: ["swift-agent"])
    ],
    targets: [
        .target(name: "ProcessSupport"),
        .target(name: "SwiftAgent", dependencies: ["ProcessSupport"]),
        .target(name: "SwiftAgentCLI", dependencies: ["SwiftAgent"]),
        .target(name: "BoyScoutAgent", dependencies: ["SwiftAgent"], plugins: ["EmbedMission"]),
        .plugin(name: "EmbedMission", capability: .buildTool()),
        .plugin(name: "BuildVersion", capability: .buildTool()),
        .executableTarget(name: "bsa", dependencies: ["SwiftAgentCLI", "BoyScoutAgent"], plugins: ["BuildVersion"]),
        .executableTarget(name: "swift-agent", dependencies: ["SwiftAgentCLI"], plugins: ["BuildVersion"]),
        .testTarget(name: "SwiftAgentPublicTests", dependencies: ["SwiftAgent"]),
        .testTarget(name: "BSACoreTests", dependencies: ["SwiftAgent", "SwiftAgentCLI", "BoyScoutAgent"])
    ]
)
