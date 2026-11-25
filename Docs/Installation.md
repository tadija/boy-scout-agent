# Installation and updates

Build with Swift 6+ and Git on macOS or Linux. See the [README](../README.md#install)
for initial setup and harness prerequisites.

```sh
./Scripts/install.sh                  # ~/.local/bin/bsa
./Scripts/install.sh /path/to/bin     # custom destination
```

The installer builds only `bsa` in release mode and atomically replaces the
installed executable after a successful build. `--product bsa` remains accepted
for existing installation scripts.

```sh
bsa update
```

Self-update clones `https://github.com/tadija/boy-scout-agent` at `main`, builds
with your local Swift toolchain, validates the binary, and atomically replaces
the invoked executable, resolving symlinks. It needs network access and write
access to the installation directory. Failed builds preserve the installed binary.
This installs the development branch, which may retain the same release version.
Alternatively, update your checkout and rerun the installer.

`VERSION` supplies BSA's release version; `bsa --version` also reports the first
seven characters of its source commit. Archive builds without Git metadata report
`unknown`. Both metadata and the default mission are embedded: no SwiftAgent
installation, source tree, Markdown file, or resource bundle is needed at runtime.
Explicit prompt override files and project/harness toolchains remain user supplied.

SwiftPM resolves SwiftAgent from its public repository at `0.1.0..<0.2.0`;
[Package.resolved](../Package.resolved) records the tested revision. Existing BSA
configuration, history, branches, and schedules need no migration.

CI independently tests macOS and Linux and packages the installed binary, README,
and license as workflow artifacts. It does not publish GitHub releases.
