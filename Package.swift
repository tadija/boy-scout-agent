// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BoyScoutAgent",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "bsa", targets: ["bsa"])],
    targets: [
        .target(name: "ProcessSupport"),
        .target(name: "BSACore", dependencies: ["ProcessSupport"], plugins: ["EmbedMission"]),
        .plugin(name: "EmbedMission", capability: .buildTool()),
        .plugin(name: "BuildVersion", capability: .buildTool()),
        .executableTarget(name: "bsa", dependencies: ["BSACore"], plugins: ["BuildVersion"]),
        .testTarget(name: "BSACoreTests", dependencies: ["BSACore"])
    ]
)
