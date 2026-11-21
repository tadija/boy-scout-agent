# Boy Scout Agent

One run. One improvement. One commit.

BSA is a local Swift CLI that delegates one bounded improvement to Codex, verifies
it in an isolated Git worktree, and creates one local commit on a dedicated branch.
This repository implements **stage 1**, the reliable single-iteration core.

## Install

Requires macOS 13+ or Linux, Swift 5.10+, Git, and an authenticated Codex CLI with
`exec --sandbox workspace-write --cd --output-last-message` support.

```sh
swift build -c release
mkdir -p ~/.local/bin
cp .build/release/bsa ~/.local/bin/bsa
# Add ~/.local/bin to PATH if needed.
codex login
```

## Use

From an existing repository with at least one commit and a configured Git author:

```sh
bsa --help
bsa run
bsa status
git log --oneline bsa/my-project
git diff main...bsa/my-project
```

Swift packages automatically use `swift test` before and after the improvement.
Untracked files in the root `.build` directory are excluded from staging, even
without a `.gitignore`.
Other projects need explicit verification (below). Runs include committed files
only; staged, unstaged, and untracked files in your checkout remain untouched.
The repository's current HEAD is the default base. Subsequent runs continue on
the BSA branch only while the base remains its ancestor. After development moves
forward, resolve the divergence yourself or choose a new branch:

```sh
bsa run --branch bsa/next-improvement --base main
```

BSA refuses to adopt an existing branch, including one changed externally since
BSA last wrote it. It also refuses to move a branch checked out in any worktree.
The default name is `bsa/<sanitized-directory-name>`; ownership and an atomic
compare-and-swap prevent collisions from overwriting unrelated branches.
Detached development checkouts are supported. Bare repositories and unborn HEADs
are rejected. Nothing fetches or pushes; review and merge commits yourself.

`committed` and `no_candidate` exit 0. Other outcomes and setup errors exit 1;
cooperative cancellation exits 130. Ctrl-C/SIGTERM cancels an active command,
records the result, and attempts worktree cleanup. The timeout covers baseline
checks, the harness, and final verification (Git setup/publication/cleanup have
separate command bounds).

## Configuration

Optional `bsa.json` in the invoking checkout, read once before isolation:

```json
{
  "base": "main",
  "branch": "bsa/my-project",
  "verification": ["npm test", "npm run lint"],
  "timeoutSeconds": 1800,
  "maxChangedFiles": 12
}
```

All fields are optional. CLI `--base`/`--branch` override this file. There is no
global config yet. Unknown keys and incorrect types are errors. Timeout must be
positive and at most 86400 seconds; file limit must be 1–100. An empty verification
array is refused. Commands run sequentially via `/bin/sh -c` inside the isolated
worktree; configuration is trusted executable input. No command is inferred for
non-Swift projects. All final checks must pass, even if a baseline failed. A
baseline failure can be the improvement's target, but unrelated existing failures
still block a commit. BSA never silently opts into unverified commits.

Stage 1 supports `run`, `status`, and help only. Counts, scheduling, other harnesses,
custom rules, history commands, and automatic crash recovery belong to later stages.

## Safety and verification

An exclusive OS lock in the common Git directory prevents overlapping BSA runs,
including runs through linked worktrees and different data directories. A detached
worktree lives outside the checkout. BSA checks HEAD and repository refs, stages
and validates the diff, then checks the proposed Git tree in a second, fresh
worktree. Ignored files and build products from the harness are absent from final
verification. BSA creates the commit and atomically publishes the branch after
all checks pass and confirm the proposed tree is unchanged. Failed publication can
leave an unreachable commit object; it never rewrites a branch or creates a
second published commit. Git hooks are disabled for BSA's Git operations so hooks
cannot silently alter the verified content or run during publication.

Conservative structural guards reject binary diffs, symlink/submodule additions,
large diffs (100 KB), more than the configured file count, common generated paths,
secrets paths/key files, obvious credential markers, changes to BSA config,
repository instruction files, CI, package manifests/lockfiles, and Makefiles.
Removing lines containing common test assertions or test invocations requires
human review and is rejected. These heuristics deliberately reject some valid
improvements; they are not proof that a change is coherent or free of secrets.
The harness receives a bounded selection policy and must self-review one change.

**Use trusted repositories and an appropriately sandboxed environment.** Worktrees
isolate Git content, not filesystem or network access. Codex uses its workspace-write
sandbox and explicit `--ask-for-approval never` for noninteractive execution; its effective permissions still depend on the installed CLI/platform and
local settings. Repository tests and configuration commands execute local code.
BSA does not provide an OS security boundary against malicious agents, commands,
Git filters, or repository content. Never provide credentials unnecessary for the
run. BSA prompts forbid commits/pushes and guards detect Git mutations, but it
cannot undo external effects of arbitrary code or an absolute Git invocation.
Automatic branch rollback would risk overwriting unrelated work, so BSA refuses it.

## Records and troubleshooting

Records are atomic JSON files under `$XDG_DATA_HOME/bsa` (default
`~/.local/share/bsa`), keyed by the canonical common Git directory. Each iteration
stores its ID, times, baseline, selected task, changed paths, baseline/final check
results, outcome, diagnostics, and candidate commit SHA. `latest.json` supports
`bsa status`; individual records retain history without a daemon. Directory
identities use chunked UTF-8 hex encoding to avoid collisions and filename limits.
Output is capped to the last 1 MiB per command and 8 KiB for the harness summary;
records can contain repository/test output, so treat them as private. Retention
and robust secret redaction are deferred; don't print secrets in checks.

- **No checks detected:** add meaningful `verification` commands to `bsa.json`.
- **Codex unavailable/incompatible:** install/authenticate Codex and check `codex exec --help`.
- **Git author missing:** configure `git config user.name` and `git config user.email`.
- **Branch changed/diverged:** inspect it and choose a fresh `--branch`; BSA never rebases it.
- **Interrupted session:** automatic recovery is deferred. The error gives the state
  directory. Inspect its `latest.json`, candidate SHA, Git refs, and any
  `worktree-<id>` or `verify-<id>` directories.
  If the candidate SHA equals the target ref, publication happened: preserve that
  commit. Otherwise it was never accepted. After inspection, remove only those BSA
  worktrees with `git worktree remove --force <path>`. Archive the state directory
  and choose a new branch for the next run; existing BSA branches cannot be adopted
  without their ownership records. Do not remove another process's worktree.
- **Another run holds the lock:** wait for that process. OS locks release on exit;
  the empty `bsa.lock` file is persistent and does not indicate an active lock.

Commands start in their own POSIX process groups using a small C spawn shim.
Termination escalates from TERM to KILL after one second; ordinary background
children are also terminated when the command exits. Deliberately detached
grandchildren may outlive a command; use OS
sandboxing for unattended runs. A hard crash preserves diagnostic state/worktrees
and blocks blind restart rather than risking duplicate publication.

## Development

```sh
swift test
swift build -c release
sh Tests/Integration/cli-smoke.sh "$PWD/.build/release/bsa"
```

Tests create temporary local repositories and fake harnesses. No API credentials,
network calls, or paid model usage are needed. CI exercises macOS and Linux.
See [the v1 spec](Docs/Specs/bsa-v1-specs.md) and
[stage 1 scope](Docs/Specs/bsa-v1-stage-1-reliable-core.md).
