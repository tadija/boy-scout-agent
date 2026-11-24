# Running and maintaining BSA

BSA delegates execution, scheduling, cancellation, and recovery to SwiftAgent.
The [upstream operations guide](https://github.com/tadija/swift-agent/blob/0.1.0/Docs/Operations.md)
owns the shared operational guarantees and native scheduler setup. Substitute
`bsa` for `swift-agent` in those commands and paths.

## Inspect and bound work

```sh
bsa status
bsa history
bsa run --count 100 --duration 4h
bsa stop
bsa doctor
```

BSA's history remains under `$XDG_DATA_HOME/bsa` (default `~/.local/share/bsa`).
Existing records and branch ownership remain usable; no migration is required.
Run again to continue the owned branch. Inspect preserved worktrees after an
interruption before manually removing them. Never delete state to bypass ownership.

## Continue an existing branch

```sh
bsa run --branch bsa/my-improvements --force
```

This adopts the branch's current tip, preserves its commits, and requires it to
be unchecked out. A diverged target needs `--force` again or a compatible base.
See upstream [recovery details](https://github.com/tadija/swift-agent/blob/0.1.0/Docs/Operations.md#recovery-and-troubleshooting).

## Recurring schedules

```sh
bsa schedule add --at 00:00 --duration 4h
bsa schedule list
bsa schedule remove ID
```

Creation generates files without enabling a service. Existing wrappers and native
services remain valid. BSA keeps `$XDG_DATA_HOME/bsa/schedules`, macOS labels
`local.bsa.ID`, and Linux units `bsa-ID.service` / `bsa-ID.timer`. Disable services
before removal. Follow the upstream native scheduler instructions with these names.
Keep the installed executable at a stable path and configure noninteractive
harness authentication. Schedules reload `bsa.json`, including `maxIterations`.

BSA retains `bsa.lock` and `bsa.stop` in Git's common directory. Generic agents
have separate namespaces; run agents sequentially against the same repository.
