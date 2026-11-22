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
cd "$fixture"
[ "$("$bsa" --version)" = "Boy Scout Agent 0.1.0" ]
if "$bsa" --version extra > "$fixture/invalid-version" 2>&1; then exit 1; fi
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
"$bsa" run > "$fixture/run" 2> "$fixture/progress"
"$bsa" status > "$fixture/status"
grep -q 'Baseline checks' "$fixture/progress"
grep -q 'Harness' "$fixture/progress"
grep -q 'Verification' "$fixture/progress"
grep -q 'Time: .*Harness: .*Verification:' "$fixture/run"
grep -q 'committed on bsa/project' "$fixture/run"
grep -q 'Outcome: committed' "$fixture/status"
[ "$(git rev-list --all --count)" = 2 ]
[ "$(cat value.txt)" = 'uncommitted user work' ]
[ "$(git show bsa/project:value.txt)" = after ]
[ "$(git symbolic-ref --short HEAD)" = main ]
"$bsa" run --count 100 > "$fixture/empty"
grep -q 'Stopped after 2 consecutive attempts without a candidate' "$fixture/empty"
[ "$(grep -c 'no_candidate on' "$fixture/empty")" = 2 ]
[ "$(git rev-list --all --count)" = 2 ]
for harness in claude pi opencode custom; do
  cat > "$fixture/bin/$harness" <<'HARNESS'
#!/bin/sh
case "$*" in *--help*) echo '--print --permission-mode --no-session'; exit 0;; esac
case "${0##*/}" in
  claude) [ "$1 $2 $3" = '--print --permission-mode acceptEdits' ] && shift 3 || exit 2;;
  pi) [ "$1 $2" = '--print --no-session' ] && shift 2 || exit 2;;
  opencode) [ "$1" = run ] && shift || exit 2;;
  custom) [ "$(cd "$1" && pwd -P)" = "$(pwd -P)" ] && shift || exit 2;;
esac
case "$1" in *'Make exactly one bounded'*) exit 0;; *) exit 2;; esac
HARNESS
  chmod +x "$fixture/bin/$harness"
  printf '%s\n' '{"customCommand":["custom","{cwd}","{prompt}"],"verification":["test -s value.txt"]}' > bsa.json
  "$bsa" run --harness "$harness" > "$fixture/$harness.out"
  grep -q 'no_candidate on' "$fixture/$harness.out"
done
"$bsa" history > "$fixture/history"
grep -q committed "$fixture/history"
"$bsa" config show > "$fixture/config"
"$bsa" schedule add --at 00:00 --duration 4h > "$fixture/schedule"
"$bsa" schedule list > "$fixture/schedules"
grep -q 'daily 00:00 for 4h' "$fixture/schedules"
schedule_id=$(awk '{print $1}' "$fixture/schedules")
"$bsa" schedule remove "$schedule_id" > "$fixture/removed"
"$bsa" schedule list > "$fixture/schedules"
[ ! -s "$fixture/schedules" ]
if "$bsa" run --until 25:00 > "$fixture/invalid" 2>&1; then exit 1; fi
if "$bsa" stop > "$fixture/stop" 2>&1; then exit 1; fi
# Synchronize on an actual partial edit before requesting cancellation.
cat > "$fixture/bin/slow-agent" <<'AGENT'
#!/bin/sh
printf 'partial edit\n' > value.txt
touch "$BSA_TEST_READY"
sleep 60
AGENT
chmod +x "$fixture/bin/slow-agent"
export BSA_TEST_READY="$fixture/ready"
printf '%s\n' '{"harness":"custom","customCommand":["slow-agent","{prompt}"],"verification":["true"]}' > bsa.json
"$bsa" run > "$fixture/slow" 2>&1 &
active=$!
attempt=0
until [ -f "$BSA_TEST_READY" ]; do
  kill -0 "$active" || exit 1
  attempt=$((attempt + 1))
  [ "$attempt" -lt 200 ] || exit 1
  sleep 0.1
done
if "$bsa" run > "$fixture/overlap" 2>&1; then exit 1; fi
grep -q 'holds this repository' "$fixture/overlap"
"$bsa" stop
if wait "$active"; then exit 1; fi
grep -q 'cancelled on' "$fixture/slow"
[ "$(git rev-list --all --count)" = 2 ]
[ "$(cat value.txt)" = 'uncommitted user work' ]
printf 'CLI smoke test passed\n'
