#!/bin/sh
set -eu
# Exercise BSA's actual declaration, entry point and upstream updater from a local Git source.
source_directory=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT HUP INT TERM
mkdir "$fixture/source"
# Keep fixture files owned by the current user, including in root-run CI containers.
(cd "$source_directory" && tar --exclude=.build --exclude=.git --exclude=.swiftpm --exclude=.DS_Store -cf - .) | (cd "$fixture/source" && tar --no-same-owner -xf -)
cd "$fixture/source"
swift - "$fixture/source" <<'SWIFT'
import Foundation
let root = URL(fileURLWithPath: CommandLine.arguments[1])
let input = root.appendingPathComponent("Sources/bsa/agent.json")
var metadata = try JSONSerialization.jsonObject(with: Data(contentsOf: input)) as! [String: Any]
metadata["update"] = ["repository": root.absoluteString]
try JSONSerialization.data(withJSONObject: metadata, options: [.prettyPrinted, .sortedKeys]).write(to: input)
SWIFT
git init -q -b main
git add .
git -c user.name=Fixture -c user.email=fixture@example.invalid commit -qm Fixture
./install.sh --product bsa "$fixture/bin"
ln -s "$fixture/bin/bsa" "$fixture/bsa-link"
before=$("$fixture/bsa-link" --version)
# Run away from both the source and installed directory, through an existing symlink.
cd "$fixture"
"$fixture/bsa-link" update > update.log
grep -q 'Installed Boy Scout Agent .*source ' update.log
[ -L "$fixture/bsa-link" ]
[ "$("$fixture/bin/bsa" --version)" = "$before" ]
sh "$source_directory/Tests/Integration/cli-smoke.sh" "$fixture/bin/bsa"
# A real compiler failure in the selected source must leave the installation intact.
printf '\nThis intentionally cannot compile\n' >> "$fixture/source/Sources/bsa/main.swift"
git -C "$fixture/source" add .
git -C "$fixture/source" -c user.name=Fixture -c user.email=fixture@example.invalid commit -qm 'Broken candidate'
cp "$fixture/bin/bsa" "$fixture/previous"
if "$fixture/bsa-link" update > failure.log 2>&1; then exit 1; fi
grep -q 'Update failed' failure.log
cmp "$fixture/previous" "$fixture/bin/bsa"
[ "$("$fixture/bin/bsa" --version)" = "$before" ]
printf 'BSA source update smoke test passed\n'
