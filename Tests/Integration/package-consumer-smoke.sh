#!/bin/sh
set -eu
source_directory=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT HUP INT TERM
mkdir -p "$fixture/Sources/DocumentationAgent"
# Swift's raw string keeps paths containing spaces or backslashes literal.
cat > "$fixture/Package.swift" <<PACKAGE
// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "Consumer", platforms: [.macOS(.v13)], dependencies: [.package(path: #"$source_directory"#)], targets: [
    .executableTarget(name: "DocumentationAgent", dependencies: [
        .product(name: "SwiftAgent", package: "boy-scout-agent"),
        .product(name: "SwiftAgentCLI", package: "boy-scout-agent")
    ])
])
PACKAGE
cat > "$fixture/Sources/DocumentationAgent/main.swift" <<'SWIFT'
import SwiftAgent
import SwiftAgentCLI
let agent = AgentDefinition(name: "Documentation Agent", executableName: "doc-agent",
                            mission: "Improve one usage example.")
let status = AgentCLI.run(agent: agent, arguments: ["--help"])
precondition(status == 0)
SWIFT
swift run --package-path "$fixture" DocumentationAgent > "$fixture/help"
grep -q 'Usage: doc-agent' "$fixture/help"
# Only engine/CLI products were requested: BSA mission generation must not run.
if find "$fixture/.build" -name EmbeddedMission.swift | grep -q .; then exit 1; fi
printf 'External package consumer smoke test passed\n'
