# Repository configuration

Run `bsa init` in the root of your checkout to generate an optional `bsa.json` with every property set to its built-in default. It refuses to overwrite an existing file and works before Git initialization. Edit the file for your project, or keep only the settings you need. Run `bsa config` to inspect the effective settings.

```sh
bsa init
bsa config
bsa config --prompt
```

`bsa config` includes the configured `instructions` string. `bsa config --prompt`
prints the full prompt that the next iteration would send, including the mandatory execution
contract, resolved mission, configured project guidance, and recent outcomes for the configured
target branch. It does not invoke a harness. History changes after each iteration.
Overrides passed to a previous `bsa run --instructions` are not saved; this preview
uses the current global and repository configuration.

Automatic settings (`prompt`, `base`, `branch`, `harness`, `customCommand`, `ollamaModel`, `baseline`, and `verification`) are written as `null`. For baseline and verification, `null` has the same automatic behavior as omitting the property; `[]` explicitly skips commands. The generated file uses built-in defaults, independent of global settings, and its explicit values override global settings.

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
| `prompt` | `null` uses the embedded Boy Scout mission. A UTF-8 Markdown path replaces the mission. Override for one run with `--prompt PATH`. Configured relative paths use the original repository root (including global config); CLI relative paths use the invocation directory. Explicit missing, unreadable, invalid UTF-8, or whitespace-only files fail. |
| `instructions` | Additional project preferences for the agent. Override for one run with `--instructions "..."`. |
| `harness` | Automatic discovery, or choose `codex`, `claude`, `pi`, `opencode`, `gemini`, `ollama`, or `custom`. |
| `ollamaModel` | `null`; required when selecting Ollama. Name of an installed model with tool support. Override with `--ollama-model`. |
| `ollamaHost` | `http://127.0.0.1:11434`; server base URL. Override with `--ollama-host`. |
| `ollamaMaxTurns` | 40 model responses per iteration (1–200). Exhaustion fails the iteration without committing. |
| `ollamaContextLength` | 32768 context tokens per request (4096–1048576). Set according to model support and server memory. |
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

[Example configuration](Examples/bsa.json)

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
| Gemini | `--approval-mode yolo` instead of `--approval-mode auto_edit` | Auto-approves all tool calls instead of just edit tools. |
| Ollama | No additional effect | Shell commands are available by default. File tools retain path restrictions. |

External CLI mappings are checked against each installed CLI's help output before execution. Older versions missing these flags are rejected. Custom harnesses must configure their own arguments in `customCommand`; combining them with `--yolo` is rejected.

This affects the agent process's execution permissions, not BSA's Git guards, verification commands, or publishing rules. Codex's sandbox is disabled in this mode; a Git worktree does not restrict filesystem or network access. Normal arguments remain the default when the flag is absent. See [Pi's security model](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/security.md) for the distinction between project trust and tool permissions. Other mappings were verified with the installed `codex exec --help`, `claude --help`, and `opencode run --help`.

Gemini runs headlessly with `--prompt` from the BSA worktree. Normal mode uses
`auto_edit`; tools that require additional approval may be denied in headless mode.
Use `bsa run --harness gemini --yolo` for Gemini's permissive mode. These arguments
were checked against the installed `gemini --help` and the official
[Gemini reference](https://geminicli.com/docs/cli/cli-reference/).

## Ollama

Ollama runs through BSA's own tool-calling agent; Codex and other agent CLIs are
not required. Use the base URL of your server, the same address whose root page
says “Ollama is running,” and an installed model that supports tools:

```sh
bsa run --harness ollama --ollama-host http://192.168.1.50:11434 --ollama-model my-coding-model
```

Replace `my-coding-model` with a model installed on your server. To keep the settings:

```json
{
  "harness": "ollama",
  "ollamaHost": "http://192.168.1.50:11434",
  "ollamaModel": "my-coding-model",
  "ollamaMaxTurns": 40,
  "ollamaContextLength": 32768,
  "verification": ["swift test"]
}
```

Use your project's verification commands. `bsa doctor` checks connectivity and
model tool support via `/api/show`; BSA never pulls a model or starts an Ollama
server. An Ollama CLI installation is not needed on the BSA machine. The server
must be listening on an address reachable from that machine. See Ollama's
[network configuration](https://docs.ollama.com/faq#how-can-i-expose-ollama-on-my-network)
for server-side setup. Repository content and project guidance are sent to the
configured server, so choose an endpoint you trust.

The agent can list unignored and tracked files, read text, search literal strings,
write files, and replace unique text matches. File tools stay inside the worktree,
reject symlinks and secret paths, and enforce BSA's protected paths when writing.
File reads/writes are limited to 1 MiB, tool responses to 32 KiB, and each model
response to 16 tool calls. Text files can be read in pages using line ranges.
Baseline and verification commands still run independently as configured.

Shell commands are available by default through `run_command`, so the agent can
inspect Git diffs and run builds or tests without `--yolo`. Those commands run
with the BSA process's permissions and can access paths outside the worktree;
BSA's normal Git and final diff checks still apply. `--yolo` has no additional
effect on Ollama. Runs respect cancellation,
the iteration deadline, and `ollamaMaxTurns`; failed or unfinished runs do not
publish partial edits. Each iteration starts a fresh conversation.

Ollama comes last in discovery order and is available for discovery only when
`ollamaModel` is configured and the server advertises tool support. Select
`--harness ollama` explicitly to ensure a run uses it. API requests follow the
[Ollama tool-calling protocol](https://docs.ollama.com/capabilities/tool-calling).
Use locally installed models and your server's local-only settings if you need
inference to stay on your own infrastructure; BSA does not control Ollama's cloud model routing.

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

Commands run in order from the worktree root, in each phase's separate checkout. Include dependency installation or other setup in each phase that needs it; baseline build artifacts are not shared with verification. Command failures are recorded; publishing requires all final verification commands to succeed. Baseline failures are retained for comparison and diagnostics.

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

## Mission Markdown

The canonical Boy Scout mission lives in [prompt.md](../prompt.md). SwiftPM embeds its exact UTF-8 contents in the executable at build time; installed BSA needs no Markdown file or resource bundle. `--prompt PATH` replaces the mission for one run. The `prompt` setting in `bsa.json` (or global configuration) provides a persistent override. CLI paths resolve from the invocation directory; configured paths resolve from the repository root. Missing, unreadable, invalid UTF-8, or empty explicit missions fail rather than falling back.

The engine composes a mandatory execution contract, the mission, and separate project instructions and recent history. `--instructions` remains additional guidance. A mission override cannot disable Git isolation, protected paths, verification, or commit ownership. `bsa config --prompt` previews the configured composition. The public `AgentDefinition` supplies identity, mission, namespaces, and the default stop policy. BSA is a thin consumer of the reusable `SwiftAgent` engine and `SwiftAgentCLI` command implementation.

Prompt precedence is CLI `--prompt PATH`, repository `prompt`, global `prompt`, then the embedded [Boy Scout mission](../prompt.md). A repository `null` clears a global override. Files are read before execution and the resolved mission stays fixed for the session. Runtime worktrees never change path resolution. The engine contract and runtime history are composed separately and remain present for every harness, including Ollama. Additional `instructions` do not replace the mission or contract.

`bsa config --prompt` retains its existing meaning: preview the configured full prompt without invoking a harness. It takes no path argument; `bsa run --prompt PATH` selects a mission file.

## Generic and specialized agents

The same schema and command flags are implemented by `SwiftAgentCLI` for every agent. `swift-agent` reads repository `swift-agent.json` and global `$XDG_CONFIG_HOME/swift-agent/config.json`; `bsa` continues reading only its existing locations. Configuration paths use the original repository root for both products. A missing or `null` generic `prompt` requires CLI `--prompt`; no mission is embedded in the generic executable. `init` generates defaults but does not invent a mission.

Generic defaults are `Swift Agent <swift-agent@localhost>`, branch `swift-agent/<project>`, and state `$XDG_DATA_HOME/swift-agent`. Count, timeout, verification, harness discovery, failure limit, and no-candidate limit match the existing engine defaults. State and config namespaces can be customized by specialized `AgentDefinition` values. Each agent's repository configuration filename is protected by the runner and CLI; mission overrides cannot remove that guard. BSA's emitted defaults remain unchanged.

For persistent documentation work, create `swift-agent.json`:

```json
{
  "prompt": "missions/documentation.md",
  "verification": ["swift test"],
  "maxIterations": 3
}
```

Use verification commands appropriate to the repository. Generic schedules reload this configuration; configure a persistent mission before scheduling.
