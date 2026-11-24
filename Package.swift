// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BoyScoutAgent",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "bsa", targets: ["bsa"])],
    targets: [
        .target(name: "ProcessSupport"),
        .target(name: "BSACore", dependencies: ["ProcessSupport"], plugins: ["EmbedMission"]),
        .executableTarget(name: "MissionGenerator"),
        .plugin(name: "EmbedMission", capability: .buildTool(), dependencies: ["MissionGenerator"]),
        .executableTarget(name: "bsa", dependencies: ["BSACore"]),
        .testTarget(name: "BSACoreTests", dependencies: ["BSACore"])
    ]
)
