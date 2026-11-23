# Repository configuration

Run `bsa init` in the root of your checkout to generate an optional `bsa.json` with every property set to its built-in default. It refuses to overwrite an existing file and works before Git initialization. Edit the file for your project, or keep only the settings you need. Run `bsa config` to inspect the effective settings.

```sh
bsa init
bsa config
```

Automatic settings (`base`, `branch`, `harness`, `customCommand`, `baseline`, and `verification`) are written as `null`. For baseline and verification, `null` has the same automatic behavior as omitting the property; `[]` explicitly skips commands. The generated file uses built-in defaults, independent of global settings, and its explicit values override global settings.

A minimal hand-written configuration also works:

```json
{
  "verification": ["python3 -m unittest discover -s tests"],
  "instructions": "Prioritize error handling in the importer."
}
```

| Setting | Default or behavior |
| --- | --- |
| `baseline` | Ordered shell commands before the harness. Defaults to the resolved `verification` commands. Set `[]` to skip baseline commands. |
| `verification` | Ordered shell commands for the proposed change in a fresh checkout. Include any setup they need. Defaults to `swift test` for Swift packages; otherwise commands must be configured. Set `[]` to explicitly skip project verification. |
| `protectedPaths` | Additional case-sensitive POSIX glob patterns against repository-relative paths. `*` can match slashes, e.g. `vendor/*`. Built-in protections always apply. |
| `instructions` | Additional project preferences for the agent. Override for one run with `--instructions "..."`. |
| `harness` | Automatic discovery, or choose `codex`, `claude`, `pi`, `opencode`, or `custom`. |
| `customCommand` | For a custom harness, give the executable and arguments as an array, e.g. `["my-agent", "{prompt}"]`. Use `{cwd}` for the worktree path. Arguments are passed directly. |
| `commitIdentity` | Author and committer for BSA commits. Default: `Boy Scout Agent <boy-scout-agent@localhost>`. Set `git` to use the configured Git identity, or supply `Name <email>`. Override with `--identity`. |
| `base`, `branch` | Starting revision and local target branch. Defaults are HEAD and `bsa/<project>`. |
| `maxIterations` | 1 attempt per invocation. Override with `--count`. |
| `failureLimit`, `saturationLimit` | 3 consecutive failures or 2 consecutive empty attempts. |
| `timeoutSeconds`, `maxChangedFiles` | 1800 seconds per iteration and 12 changed files. |

Global defaults may be set in `$XDG_CONFIG_HOME/bsa/config.json` (normally
`~/.config/bsa/config.json`). Repository config overrides global settings and CLI
flags override repository settings. `push: true` explicitly enables non-forced
pushes to `origin` after accepted commits. A failed push retains the local commit
and stops the run.

[Example configuration](../Examples/bsa.json)

## Permissive harness mode

```sh
bsa run --harness claude --yolo
```

`--yolo` is a per-run CLI flag. It selects the built-in agent's supported permissive arguments:

| Harness | Arguments used in YOLO mode | Effect |
| --- | --- | --- |
| Codex | `--dangerously-bypass-approvals-and-sandbox` instead of `--ask-for-approval never` and `--sandbox workspace-write` | Disables Codex approval prompts and sandboxing. |
| Claude Code | `--dangerously-skip-permissions` instead of `--permission-mode acceptEdits` | Bypasses Claude permission checks. |
| Pi | Adds `--approve` | Trusts project-local resources for this invocation. Pi already runs tools without per-call approvals. |
| OpenCode | Adds `--auto` | Auto-approves permissions that are not explicitly denied. Explicit denials still apply. |

The mappings are checked against each installed CLI's help output before execution. Older versions missing these flags are rejected. Custom harnesses must configure their own arguments in `customCommand`; combining them with `--yolo` is rejected.

This affects the agent process's execution permissions, not BSA's Git guards, verification commands, or publishing rules. Codex's sandbox is disabled in this mode; a Git worktree does not restrict filesystem or network access. Normal arguments remain the default when the flag is absent. See [Pi's security model](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/security.md) for the distinction between project trust and tool permissions. Other mappings were verified with the installed `codex exec --help`, `claude --help`, and `opencode run --help`.

## Instructions from the CLI

```sh
bsa run --instructions "Focus on error handling; preserve public APIs."
```

The quoted text replaces configured `instructions` for this invocation and applies to every iteration. Use `--instructions ""` to clear configured guidance for a run. No `bsa.json` file is required; BSA's built-in constraints remain in effect.

## Baseline and verification

Skip both phases for one invocation without changing configuration:

```sh
bsa run --skip-checks
```

`--skip-checks` takes no value and skips baseline and verification commands for
every iteration in the run, including configured commands and automatic Swift
checks. It also permits running projects without detected verification.
To skip only one phase, configure its command array as `[]`.

Commands run in order from the worktree root, in each phase's separate checkout. Include dependency installation or other setup in each phase that needs it; baseline build artifacts are not shared with verification. A failed command stops the phase.

For a Swift package, the defaults run `swift test` in both phases. To use a quick baseline and a broader final check:

```json
{
  "baseline": ["swift build"],
  "verification": ["swift test", "swift build -c release"]
}
```

For a Rust project, check compilation first, then run tests and Clippy (requires the Clippy component):

```json
{
  "baseline": ["cargo check --all-targets"],
  "verification": ["cargo test --all-targets", "cargo clippy --all-targets -- -D warnings"]
}
```

For a TypeScript project using npm and a committed `package-lock.json`, install dependencies in both checkouts. This example assumes `typecheck`, `test`, and `build` scripts in `package.json`, with `test` configured to exit after one run:

```json
{
  "baseline": ["npm ci", "npm run typecheck"],
  "verification": ["npm ci", "npm run typecheck", "npm test", "npm run build"]
}
```

Adapt commands to your project's scripts and toolchain. To run identical commands in both phases, configure only `verification`.

Skip baseline commands while keeping final verification:

```json
{
  "baseline": [],
  "verification": ["swift test"]
}
```

Use different commands for each phase by providing both arrays. Omitted `baseline` uses the resolved verification commands. Omitted `verification` uses automatic Swift detection; other projects still require explicit configuration.

To skip both sets of project commands, set `"baseline": []` and `"verification": []`. An empty `verification` array also skips baseline commands when `baseline` is omitted. Explicit empty arrays override automatic detection. Empty strings inside either array are invalid.

Skipping commands is an explicit opt-in to commits without those project checks. Git isolation, protected-path checks, diff validation, and clean-tree integrity checks still run. The harness may run its own tests independently.

## Commit identity

```sh
bsa run --identity "Custom Scout <scout@example.com>"
bsa run --identity git
```

Both author and committer use the selected identity. It applies only when BSA creates its commit; repository and global Git configuration are unchanged. `git` uses Git's configured author/committer identities and requires a usable Git identity. Inherited `GIT_*` environment variables are filtered by BSA.

To keep your Git identity for every run, set `"commitIdentity": "git"` in your repository or global BSA config. Scheduled runs use these same config files.
