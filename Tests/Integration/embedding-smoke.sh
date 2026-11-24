#!/bin/sh
set -eu
# Exercise the real plugin in a tiny clean package, without rebuilding the engine.
source_directory=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT HUP INT TERM
mkdir -p "$fixture/Plugins" "$fixture/Sources/Fixture" "$fixture/Scripts"
cp -R "$source_directory/Plugins/EmbedMission" "$fixture/Plugins/"
cp "$source_directory/Scripts/embed-mission.swift" "$fixture/Scripts/"
cat > "$fixture/Package.swift" <<'PACKAGE'
// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "EmbeddingFixture", targets: [
    .executableTarget(name: "Fixture", plugins: ["EmbedMission"]),
    .plugin(name: "EmbedMission", capability: .buildTool())
])
PACKAGE
cat > "$fixture/Sources/Fixture/main.swift" <<'SWIFT'
import Foundation
FileHandle.standardOutput.write(Data(EmbeddedMission.markdown.utf8))
SWIFT
cat > "$fixture/prompt.md" <<'MARKDOWN'
# Mission: café 🏕️
Preserve "quotes", \slashes, \(interpolation), and {prompt} literally.
MARKDOWN
swift build --package-path "$fixture" --product Fixture
binary_directory=$(swift build --package-path "$fixture" --show-bin-path)
"$binary_directory/Fixture" > "$fixture/actual"
cmp "$fixture/prompt.md" "$fixture/actual"
printf '\nChanged mission input.\n' >> "$fixture/prompt.md"
swift build --package-path "$fixture" --product Fixture
"$binary_directory/Fixture" > "$fixture/actual"
cmp "$fixture/prompt.md" "$fixture/actual"
# A changed generator must also invalidate the generated source.
sed 's/Generated from/Regenerated from/' "$fixture/Scripts/embed-mission.swift" > "$fixture/generator"
mv "$fixture/generator" "$fixture/Scripts/embed-mission.swift"
swift build --package-path "$fixture" --product Fixture
generated_file=$(find "$fixture/.build" -name EmbeddedMission.swift -print -quit)
grep -q 'Regenerated from' "$generated_file"
# The binary must still work after its canonical Markdown is removed.
mv "$fixture/prompt.md" "$fixture/expected"
(cd / && "$binary_directory/Fixture") > "$fixture/actual"
cmp "$fixture/expected" "$fixture/actual"
printf 'Embedding smoke test passed\n'
