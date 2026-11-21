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
