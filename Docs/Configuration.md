# Repository configuration

Create an optional `bsa.json` in the root of your checkout. Run `bsa config show` to inspect the effective settings.

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

## Commit identity

```sh
bsa run --identity "Custom Scout <scout@example.com>"
bsa run --identity git
```

Both author and committer use the selected identity. It applies only when BSA creates its commit; repository and global Git configuration are unchanged. `git` uses Git's configured author/committer identities and requires a usable Git identity. Inherited `GIT_*` environment variables are filtered by BSA.

To keep your Git identity for every run, set `"commitIdentity": "git"` in your repository or global BSA config. Scheduled runs use these same config files.
