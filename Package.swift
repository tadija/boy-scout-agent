// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "BoyScoutAgent",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "bsa", targets: ["bsa"])],
    targets: [
        .target(name: "ProcessSupport"),
        .target(name: "BSACore", dependencies: ["ProcessSupport"]),
        .executableTarget(name: "bsa", dependencies: ["BSACore"]),
        .testTarget(name: "BSACoreTests", dependencies: ["BSACore"])
    ]
)
