#!/bin/sh
set -eu
# Installed BSA product assembly. Generic CLI compatibility belongs to SwiftAgent.
bsa=${1:?usage: cli-smoke.sh /absolute/path/to/bsa}
source_directory=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
version=$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$source_directory/Sources/bsa/agent.json")
fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT HUP INT TERM
export XDG_DATA_HOME="$fixture/data"
export XDG_CONFIG_HOME="$fixture/config"
export BSA_TEST_PROMPT="$fixture/prompt"
mkdir -p "$fixture/bin" "$fixture/project" "$XDG_CONFIG_HOME/bsa"
cat > "$fixture/bin/product-harness" <<'HARNESS'
#!/bin/sh
printf '%s\n' "$1" > "$BSA_TEST_PROMPT"
printf 'after\n' > value.txt
printf 'Correct the product fixture\n'
HARNESS
chmod +x "$fixture/bin/product-harness"
export PATH="$fixture/bin:$PATH"
cd "$fixture/project"
"$bsa" --version > "$fixture/version"
grep -Eq "^Boy Scout Agent $version( \([^()]+\))?$" "$fixture/version"

"$bsa" --help > "$fixture/help"
grep -q 'Usage: bsa ' "$fixture/help"
"$bsa" init > "$fixture/init"
[ -f bsa.json ]
grep -q 'Boy Scout Agent <boy-scout-agent@localhost>' bsa.json
# Verify discovery of the historical product configuration namespace.
printf '%s\n' '{"instructions":"BSA_GLOBAL_GUIDANCE"}' > "$XDG_CONFIG_HOME/bsa/config.json"
printf '%s\n' '{"harness":"custom","customCommand":["product-harness","{prompt}"],"verification":["test -s value.txt"]}' > bsa.json
git init -q -b main
git config user.name 'BSA Test'
git config user.email bsa@example.invalid
printf 'before\n' > value.txt
git add .
git commit -qm Initial
"$bsa" config --prompt > "$fixture/preview"
grep -q '^# Boy Scout Agent' "$fixture/preview"
grep -q 'Leave the codebase a little better' "$fixture/preview"
grep -q BSA_GLOBAL_GUIDANCE "$fixture/preview"
"$bsa" run > "$fixture/run"
grep -q 'committed on bsa/project' "$fixture/run"
grep -q '^# Boy Scout Agent' "$BSA_TEST_PROMPT"
grep -q 'Leave the codebase a little better' "$BSA_TEST_PROMPT"
[ "$(git show -s --format='%an <%ae>|%s' bsa/project)" = 'Boy Scout Agent <boy-scout-agent@localhost>|bsa: Correct the product fixture' ]
[ -d "$XDG_DATA_HOME/bsa/repositories" ]

# Runtime mission replacement still works in the standalone product.
printf 'BSA_RUNTIME_MISSION\n' > "$fixture/override.md"
"$bsa" run --prompt "$fixture/override.md" > "$fixture/override-run"
grep -q BSA_RUNTIME_MISSION "$BSA_TEST_PROMPT"
if grep -q '^# Boy Scout Agent' "$BSA_TEST_PROMPT"; then exit 1; fi
printf 'BSA product CLI smoke test passed\n'

# Existing installations may have history without terminal metadata.
# Exercise that format through the installed product, alongside current history.
swift - "$XDG_DATA_HOME/bsa" <<'SWIFT'
import Foundation
let root = URL(fileURLWithPath: CommandLine.arguments[1])
for case let record as URL in FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)! {
    guard record.pathExtension == "json",
          var object = try JSONSerialization.jsonObject(with: Data(contentsOf: record)) as? [String: Any],
          object.removeValue(forKey: "terminal") != nil else { continue }
    try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]).write(to: record)
}
SWIFT
"$bsa" status > "$fixture/legacy-status"
"$bsa" history > "$fixture/legacy-history"
"$bsa" run > "$fixture/legacy-run"
printf 'BSA history upgrade smoke test passed\n'
