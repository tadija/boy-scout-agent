#!/bin/sh
set -eu
# Invoke with an absolute executable path; this test never calls a real model.
bsa=${1:?usage: cli-smoke.sh /absolute/path/to/bsa}
fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT HUP INT TERM
mkdir -p "$fixture/bin" "$fixture/project"
cat > "$fixture/bin/codex" <<'CODEX'
#!/bin/sh
[ "$1" = --ask-for-approval ] && [ "$2" = never ] || exit 2
shift 2
if [ "$2" = --help ]; then
  echo '--sandbox --cd --output-last-message'
  exit 0
fi
printf 'after\n' > value.txt
printf 'Correct the value fixture\n' > "$7"
CODEX
chmod +x "$fixture/bin/codex"
export PATH="$fixture/bin:$PATH"
export XDG_DATA_HOME="$fixture/data"
cd "$fixture/project"
git init -q -b main
git config user.name 'BSA Test'
git config user.email 'bsa@example.invalid'
printf 'before\n' > value.txt
printf '{"verification":["test -s value.txt"]}\n' > bsa.json
git add .
git commit -qm Initial
printf 'uncommitted user work\n' > value.txt
"$bsa" --help > "$fixture/help"
"$bsa" status > "$fixture/before"
"$bsa" run > "$fixture/run"
"$bsa" status > "$fixture/status"
grep -q 'committed on bsa/project' "$fixture/run"
grep -q 'Outcome: committed' "$fixture/status"
[ "$(git rev-list --all --count)" = 2 ]
[ "$(cat value.txt)" = 'uncommitted user work' ]
[ "$(git show bsa/project:value.txt)" = after ]
[ "$(git symbolic-ref --short HEAD)" = main ]
if "$bsa" run --count 2 > "$fixture/error" 2>&1; then
  echo 'unsupported stage 2 flag unexpectedly succeeded' >&2
  exit 1
fi
printf 'CLI smoke test passed\n'
