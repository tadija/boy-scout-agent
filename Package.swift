// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "BoyScoutAgent",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "bsa", targets: ["bsa"])],
    dependencies: [
        .package(url: "https://github.com/tadija/swift-agent.git", .upToNextMinor(from: "0.2.0"))
    ],
    targets: [
        .executableTarget(name: "bsa", dependencies: [
            .product(name: "SwiftAgent", package: "swift-agent"),
            .product(name: "SwiftAgentCLI", package: "swift-agent")
        ], exclude: ["agent.json", "prompt.md"], plugins: [
            .plugin(name: "AgentProductPlugin", package: "swift-agent")
        ]),
        .testTarget(name: "BoyScoutAgentTests", dependencies: [
            "bsa", .product(name: "SwiftAgent", package: "swift-agent")
        ])
    ]
)
