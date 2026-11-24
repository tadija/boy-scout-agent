#!/bin/sh
set -eu
# Invoke with an absolute executable path; this test never calls a real model.
bsa=${1:?usage: cli-smoke.sh /absolute/path/to/bsa}
fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT HUP INT TERM
mkdir -p "$fixture/bin" "$fixture/project"
cat > "$fixture/bin/codex" <<'CODEX'
#!/bin/sh
if [ "$1" = --ask-for-approval ]; then
  [ "$2" = never ] || exit 2
  shift 2
fi
if [ "$2" = --help ]; then
  echo '--sandbox --cd --output-last-message --dangerously-bypass-approvals-and-sandbox'
  exit 0
fi
[ "$1" = exec ] || exit 2
shift
if [ "${BSA_TEST_YOLO:-0}" = 1 ]; then
  [ "$1" = --dangerously-bypass-approvals-and-sandbox ] || exit 2
  shift
else
  [ "$1 $2" = '--sandbox workspace-write' ] || exit 2
  shift 2
fi
[ "$1" = --cd ] && [ "$2" -ef . ] || exit 2
shift 2
[ "$1" = --output-last-message ] || exit 2
if [ -n "${BSA_TEST_PROMPT:-}" ]; then printf '%s\n' "$3" > "$BSA_TEST_PROMPT"; fi
printf 'after\n' > value.txt
printf 'Correct the value fixture\n' > "$2"
CODEX
chmod +x "$fixture/bin/codex"
export PATH="$fixture/bin:$PATH"
export XDG_DATA_HOME="$fixture/data"
export XDG_CONFIG_HOME="$fixture/config-home"
cd "$fixture"
[ "$("$bsa" --version)" = "Boy Scout Agent 0.2.0" ]
if "$bsa" --version extra > "$fixture/invalid-version" 2>&1; then exit 1; fi
cd "$fixture/project"
"$bsa" init > "$fixture/init"
cp bsa.json "$fixture/defaults.json"
if "$bsa" init > "$fixture/existing-init" 2>&1; then exit 1; fi
cmp bsa.json "$fixture/defaults.json"
if "$bsa" init extra > "$fixture/invalid-init" 2>&1; then exit 1; fi
for command in init update run config status history stop doctor harnesses schedule; do
  "$bsa" "$command" --help > "$fixture/command-help"
  grep -q 'config           Print' "$fixture/command-help"
done
if "$bsa" update extra > "$fixture/invalid-update" 2>&1; then exit 1; fi
"$bsa" schedule add --help > "$fixture/schedule-help"
"$bsa" config --help > "$fixture/config-help"
grep -q 'Schedule subcommands:' "$fixture/schedule-help"
if "$bsa" config show > "$fixture/obsolete-config" 2>&1; then exit 1; fi
git init -q -b main
git config user.name 'BSA Test'
git config user.email 'bsa@example.invalid'
printf 'before\n' > value.txt
printf '{"verification":["test -s value.txt"],"instructions":"CONFIG_INSTRUCTIONS_MUST_BE_OVERRIDDEN"}\n' > bsa.json
git add .
git commit -qm Initial
"$bsa" config > "$fixture/config-instructions"
grep -q 'CONFIG_INSTRUCTIONS_MUST_BE_OVERRIDDEN' "$fixture/config-instructions"
"$bsa" config --prompt > "$fixture/prompt-preview"
grep -q 'Make exactly one bounded' "$fixture/prompt-preview"
grep -q 'CONFIG_INSTRUCTIONS_MUST_BE_OVERRIDDEN' "$fixture/prompt-preview"
cp bsa.json "$fixture/project-config.json"
cp "$fixture/defaults.json" bsa.json
"$bsa" config > "$fixture/initial-config"
cmp "$fixture/initial-config" "$fixture/defaults.json"
cp "$fixture/project-config.json" bsa.json
printf 'uncommitted user work\n' > value.txt
"$bsa" --help > "$fixture/help"
"$bsa" status > "$fixture/before"
git branch bsa/project
if "$bsa" run > "$fixture/unowned" 2>&1; then exit 1; fi
grep -q 'use --force' "$fixture/unowned"
export BSA_TEST_PROMPT="$fixture/prompt"
instructions='Focus on error handling; preserve "$HOME" and `literal` text.'
if "$bsa" run --instructions > "$fixture/missing-instructions" 2>&1; then exit 1; fi
"$bsa" run --force --identity "CLI Scout <cli@example.invalid>" --instructions "$instructions" > "$fixture/run" 2> "$fixture/progress"
grep -Fq -- "$instructions" "$BSA_TEST_PROMPT"
if grep -q 'CONFIG_INSTRUCTIONS_MUST_BE_OVERRIDDEN' "$BSA_TEST_PROMPT"; then exit 1; fi
unset BSA_TEST_PROMPT
"$bsa" status > "$fixture/status"
grep -q 'Baseline' "$fixture/progress"
grep -q 'Harness' "$fixture/progress"
grep -q 'Verification' "$fixture/progress"
grep -q 'Time: .*Harness: .*Verification:' "$fixture/run"
grep -q 'committed on bsa/project' "$fixture/run"
grep -q 'Outcome: committed' "$fixture/status"
[ "$(git rev-list --all --count)" = 2 ]
[ "$(cat value.txt)" = 'uncommitted user work' ]
[ "$(git show bsa/project:value.txt)" = after ]
[ "$(git show -s --format='%an <%ae>|%cn <%ce>' bsa/project)" = 'CLI Scout <cli@example.invalid>|CLI Scout <cli@example.invalid>' ]
[ "$(git config user.name)" = 'BSA Test' ]
[ "$(git config user.email)" = 'bsa@example.invalid' ]
[ "$(git symbolic-ref --short HEAD)" = main ]
"$bsa" run --count 100 > "$fixture/empty"
grep -q 'Stopped after 2 consecutive attempts without a candidate' "$fixture/empty"
[ "$(grep -c 'no_candidate on' "$fixture/empty")" = 2 ]
[ "$(git rev-list --all --count)" = 2 ]
# CLI paths resolve from the invocation directory and override repository missions.
cp bsa.json "$fixture/prompt-config-backup"
printf '%s\n' '{"prompt":"missing-config-mission.md","verification":["test -s value.txt"]}' > bsa.json
printf 'CLI_MISSION_MARKER\n' > "$fixture/mission.md"
mkdir "$fixture/project/nested"
export BSA_TEST_PROMPT="$fixture/override-prompt"
(cd nested && "$bsa" run --prompt ../../mission.md) > "$fixture/override-run"
grep -q CLI_MISSION_MARKER "$BSA_TEST_PROMPT"
grep -q 'Do not commit, push' "$BSA_TEST_PROMPT"
if grep -q 'correctness, reliability, warnings' "$BSA_TEST_PROMPT"; then exit 1; fi
for path in "$fixture/missing.md" "$fixture/empty.md"; do
  : > "$fixture/empty.md"
  if "$bsa" run --prompt "$path" > "$fixture/bad-prompt" 2>&1; then exit 1; fi
  grep -q 'Cannot load prompt' "$fixture/bad-prompt"
done
if "$bsa" run --prompt > "$fixture/missing-prompt-option" 2>&1; then exit 1; fi
unset BSA_TEST_PROMPT
# Configuration precedence and repository-relative resolution, including global paths.
mkdir -p "$XDG_CONFIG_HOME/bsa"
printf '%s\n' '{"prompt":"../mission.md"}' > "$XDG_CONFIG_HOME/bsa/config.json"
printf '%s\n' '{}' > bsa.json
"$bsa" config --prompt > "$fixture/global-prompt"
grep -q CLI_MISSION_MARKER "$fixture/global-prompt"
printf 'REPO_MISSION_MARKER\n' > repo-mission.md
printf '%s\n' '{"prompt":"repo-mission.md"}' > bsa.json
"$bsa" config --prompt > "$fixture/repo-prompt"
grep -q REPO_MISSION_MARKER "$fixture/repo-prompt"
if grep -q CLI_MISSION_MARKER "$fixture/repo-prompt"; then exit 1; fi
printf '%s\n' '{"prompt":null}' > bsa.json
"$bsa" config --prompt > "$fixture/default-prompt"
grep -q 'correctness, reliability, warnings' "$fixture/default-prompt"
rm "$XDG_CONFIG_HOME/bsa/config.json" repo-mission.md
cp "$fixture/prompt-config-backup" bsa.json
for harness in claude pi opencode gemini custom; do
  cat > "$fixture/bin/$harness" <<'HARNESS'
#!/bin/sh
if [ "${0##*/}" = gemini ]; then
  case "$*" in *--help*)
    if [ "${BSA_TEST_GEMINI_OLD:-0}" = 1 ]; then echo '--prompt'; else echo '--prompt --approval-mode auto_edit yolo'; fi
    exit 0;;
  esac
fi
case "$*" in *--help*) echo '--print --permission-mode --no-session --dangerously-skip-permissions --approve --auto'; exit 0;; esac
case "${0##*/}" in
  claude)
    if [ "${BSA_TEST_YOLO:-0}" = 1 ]; then
      [ "$1 $2" = '--print --dangerously-skip-permissions' ] && shift 2 || exit 2
    else
      [ "$1 $2 $3" = '--print --permission-mode acceptEdits' ] && shift 3 || exit 2
    fi;;
  pi)
    [ "$1 $2" = '--print --no-session' ] && shift 2 || exit 2
    if [ "${BSA_TEST_YOLO:-0}" = 1 ]; then [ "$1" = --approve ] && shift || exit 2; fi;;
  opencode)
    [ "$1" = run ] && shift || exit 2
    if [ "${BSA_TEST_YOLO:-0}" = 1 ]; then [ "$1" = --auto ] && shift || exit 2; fi;;
  gemini)
    [ "$1" = --approval-mode ] || exit 2
    if [ "${BSA_TEST_YOLO:-0}" = 1 ]; then [ "$2" = yolo ] || exit 2
    else [ "$2" = auto_edit ] || exit 2; fi
    [ "$3" = --prompt ] && shift 3 || exit 2
    [ -f value.txt ] || exit 2;;
  custom) [ "$(cd "$1" && pwd -P)" = "$(pwd -P)" ] && shift || exit 2;;
esac
case "$1" in *'Make exactly one bounded'*) exit 0;; *) exit 2;; esac
HARNESS
  chmod +x "$fixture/bin/$harness"
  printf '%s\n' '{"customCommand":["custom","{cwd}","{prompt}"],"verification":["test -s value.txt"]}' > bsa.json
  "$bsa" run --harness "$harness" > "$fixture/$harness.out"
  grep -q 'no_candidate on' "$fixture/$harness.out"
  if [ "$harness" != custom ]; then
    BSA_TEST_YOLO=1 "$bsa" run --harness "$harness" --yolo > "$fixture/$harness-yolo.out"
    grep -q 'YOLO mode enabled' "$fixture/$harness-yolo.out"
    grep -q 'no_candidate on' "$fixture/$harness-yolo.out"
  else
    if "$bsa" run --harness custom --yolo > "$fixture/custom-yolo" 2>&1; then exit 1; fi
    grep -q 'only supports built-in harnesses' "$fixture/custom-yolo"
  fi
done
if BSA_TEST_GEMINI_OLD=1 "$bsa" run --harness gemini --yolo > "$fixture/old-gemini" 2>&1; then exit 1; fi
grep -q 'Install a compatible gemini CLI' "$fixture/old-gemini"
"$bsa" harnesses > "$fixture/harnesses"
grep -q 'gemini: available' "$fixture/harnesses"
BSA_TEST_YOLO=1 "$bsa" run --harness codex --yolo > "$fixture/codex-yolo"
grep -q 'no_candidate on' "$fixture/codex-yolo"
"$bsa" history > "$fixture/history"
grep -q committed "$fixture/history"
"$bsa" config > "$fixture/config"
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
printf '%s\n' '{"baseline":[],"verification":[]}' > bsa.json
"$bsa" run --branch bsa/skipped > "$fixture/skipped" 2> "$fixture/skipped-progress"
grep -q 'Baseline skipped' "$fixture/skipped-progress"
grep -q 'Verification skipped' "$fixture/skipped-progress"
grep -q 'committed on bsa/skipped' "$fixture/skipped"
"$bsa" doctor > "$fixture/skipped-doctor"
grep -q 'Baseline: skipped. Verification: skipped' "$fixture/skipped-doctor"
# The CLI flag overrides both phases without changing configuration.
printf '%s\n' '{"baseline":["false"],"verification":["false"]}' > bsa.json
cp bsa.json "$fixture/skip-config"
"$bsa" run --skip-checks --branch bsa/skip-both > "$fixture/skip-both" 2> "$fixture/skip-both-progress"
grep -q 'committed on bsa/skip-both' "$fixture/skip-both"
grep -q 'Baseline skipped' "$fixture/skip-both-progress"
grep -q 'Verification skipped' "$fixture/skip-both-progress"
cmp bsa.json "$fixture/skip-config"
printf '%s\n' '{}' > bsa.json
"$bsa" run --skip-checks --branch bsa/no-verification > "$fixture/no-verification" 2> "$fixture/no-verification-progress"
grep -q 'committed on bsa/no-verification' "$fixture/no-verification"
if "$bsa" run --branch bsa/needs-verification > "$fixture/needs-verification" 2>&1; then exit 1; fi
grep -q 'No meaningful verification detected' "$fixture/needs-verification"
printf 'CLI smoke test passed\n'
