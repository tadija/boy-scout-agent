# Running and maintaining BSA

## Inspect a run

Use `bsa status` for the latest outcome, branch, commit candidate and diagnostics. Per-iteration JSON records live under `$XDG_DATA_HOME/bsa` (default `~/.local/share/bsa`). After an interrupted publication, inspect the record and Git branch before attempting recovery.

Worktrees isolate proposed edits. Harnesses and verification commands still run with your account's permissions. Use trusted projects and commands, or run BSA in an OS sandbox.

Each iteration starts a fresh agent with recent tasks, failures and changed paths from the target branch. BSA stops after two consecutive empty attempts, three consecutive failures, cancellation, timeout, or an error that needs attention. Running again continues from the BSA branch. If your development branch has diverged, start a new target with `bsa run --branch bsa/next-improvement`.

## Overnight operation

```sh
bsa run --count 100 --until 04:00
bsa run --count 100 --duration 4h
bsa stop
bsa history
bsa doctor
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

Cost budgets are unavailable because the adapters do not expose reliable normalized cost data. Use count and time bounds.

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
