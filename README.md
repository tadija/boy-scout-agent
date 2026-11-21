# Boy Scout Agent

Leave your codebase a little better than you found it. Boy Scout Agent (`bsa`) asks an installed coding agent to find one worthwhile improvement, checks its work, and gives you a local Git commit to review. You can run it once or give it a few more turns.

## Install

Build with Swift 6 or later on macOS or Linux. Install Git and sign in to at least one supported coding agent CLI. BSA looks for Codex, Claude Code, Pi, then OpenCode, in that order.

```sh
swift build -c release
mkdir -p ~/.local/bin
cp .build/release/bsa ~/.local/bin/bsa
export PATH="$HOME/.local/bin:$PATH"
```

## Improve a project

Open a trusted repository with at least one commit and a configured Git author. Swift packages use `swift test` automatically. For other projects, set up verification below first.

```sh
bsa run
bsa status
git diff HEAD...bsa/my-project
```

Use the branch name printed by BSA in the diff command. BSA starts from your current commit, runs the baseline checks and gives the agent a detached worktree. Your local edits stay in your checkout. BSA inspects the diff and runs verification again against the proposed contents in a fresh worktree. Each accepted improvement adds one commit to the local BSA branch. You decide what to merge or push.

For a longer run, set an iteration limit and optionally choose the agent.

```sh
bsa run --count 10 --harness claude
```

Each iteration starts a fresh agent with recent tasks, failures and changed paths from the target branch. BSA stops after two consecutive empty attempts, three consecutive failures, cancellation, timeout, or an error that needs attention. Running again continues from the BSA branch. If your development branch has diverged, start a new target with `bsa run --branch bsa/next-improvement`.

## Configure a repository

Create an optional `bsa.json` in the root of your checkout. CLI flags override repository settings.

```json
{
  "verification": ["python3 -m unittest discover -s tests"],
  "instructions": "Prioritize error handling in the importer."
}
```

| Setting | Default or behavior |
| --- | --- |
| `verification` | Ordered shell commands. Include any setup they need in a fresh checkout. |
| `protectedPaths` | Additional case-sensitive POSIX glob patterns against repository-relative paths. `*` can match slashes, e.g. `vendor/*`. Built-in protections always apply. |
| `instructions` | Additional project preferences for the agent. |
| `harness` | Automatic discovery, or choose `codex`, `claude`, `pi`, `opencode`, or `custom`. |
| `customCommand` | For a custom harness, give the executable and arguments as an array, e.g. `["my-agent", "{prompt}"]`. Use `{cwd}` for the worktree path. Arguments are passed directly. |
| `base`, `branch` | Starting revision and local target branch. Defaults are HEAD and `bsa/<project>`. |
| `maxIterations` | 1 attempt per invocation. Override with `--count`. |
| `failureLimit`, `saturationLimit` | 3 consecutive failures or 2 consecutive empty attempts. |
| `timeoutSeconds`, `maxChangedFiles` | 1800 seconds per iteration and 12 changed files. |

## Inspect a run

Use `bsa status` for the latest outcome, branch, commit candidate and diagnostics. Per-iteration JSON records live under `$XDG_DATA_HOME/bsa` (default `~/.local/share/bsa`). After an interrupted publication, inspect the record and Git branch before attempting recovery.

Worktrees isolate proposed edits. Harnesses and verification commands still run with your account's permissions. Use trusted projects and commands, or run BSA in an OS sandbox.

## Overnight operation

```sh
bsa run --count 100 --until 04:00
bsa run --count 100 --duration 4h
bsa stop
bsa history
bsa doctor
bsa config show
```

Time windows cap active work as well as iteration starts; the smaller of the
iteration timeout and remaining window applies. Cleanup and process termination
may take additional time. `--until` uses the next local HH:MM, advancing missing
DST times and choosing the first repeated time. Use one window flag per run.
A window does not change the default one-iteration count; supply `--count` for
repeated work. SIGINT, SIGTERM and `stop` terminate process groups with a bounded
TERM grace period before KILL. Repository locks cover all branches and linked
worktrees, including runs using different data directories; kernel locks release
on process exit and require no stale PID deletion.

Global defaults may be set in `$XDG_CONFIG_HOME/bsa/config.json` (normally
`~/.config/bsa/config.json`). Repository config overrides global settings and CLI
flags override repository settings. `push: true` explicitly enables non-forced
pushes to `origin` after accepted commits. A failed push retains the local commit
and stops the run. Cost budgets are unavailable because the adapters do not
currently expose reliable normalized cost data; use count and time bounds.

## Recurring schedules

```sh
bsa schedule add --at 00:00 --duration 4h
bsa schedule list
```

Definitions and executable wrappers live in `$XDG_DATA_HOME/bsa/schedules`.
Creation prepares files without enabling a service. The wrapper captures the
repository and executable paths, honors the configured `maxIterations` (default 1) and uses the current
repository configuration at execution time. Keep the installed BSA executable at
a stable absolute path. Native services need the harness executable on their PATH
and existing noninteractive authentication. Test the generated `.sh` manually
before enabling overnight execution.

On macOS, enable the generated plist with:

```sh
launchctl bootstrap "gui/$(id -u)" /absolute/path/to/ID.plist
# Disable before removing:
launchctl bootout "gui/$(id -u)" /absolute/path/to/ID.plist
```

On Linux, copy the generated `bsa-ID.service` and `bsa-ID.timer` into
`~/.config/systemd/user`, then:

```sh
systemctl --user daemon-reload
systemctl --user enable --now bsa-ID.timer
# Disable before removing:
systemctl --user disable --now bsa-ID.timer
```

After disabling, use `bsa schedule remove ID` to delete the definition and wrapper.
Where no user service manager is available, run the wrapper from your existing
scheduler. Schedules use host local time; the creation timezone is recorded for
reference. Native launchd/systemd DST and sleeping-host behavior applies; missed
runs are not explicitly replayed. Concurrent invocations fail safely on the
repository lock. User services require a logged-in user (or systemd lingering).

## Recovery and troubleshooting

After a crash, the next run acquires the repository lock and reconciles the latest
running record. If its candidate SHA equals the target ref, it records the commit
and restores branch ownership; otherwise it marks the attempt interrupted.
Unpublished candidates are never automatically published. Abandoned worktrees
remain in the repository's data directory for inspection and copying partial work.
Use `git worktree list`, inspect the relevant `worktree-ID` / `verify-ID`, then
remove them manually with `git worktree remove` when their contents are no longer
needed. Never delete the data directory to bypass branch ownership checks.
Externally changed or diverged target branches require manual resolution or a new
`--branch`; BSA does not reset them. Normal rejected attempts discard their isolated
changes after saving bounded diagnostics, as required by the verification contract.

History JSON records retain bounded harness summaries and check outputs, IDs,
SHAs, paths and timings. Records are retained indefinitely for audit; native
schedule output logs should be rotated by the operator. They may contain sensitive
repository output. No dashboard, database or background BSA daemon is required.

Cancellation and timeout preserve dirty implementation worktrees. The iteration
record includes the path when Git refuses to remove one.
