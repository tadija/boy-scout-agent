# Installation and updates

Run the installer from a checkout of this repository.

Build with Swift 6 or later on macOS or Linux. Install Git and, for external harnesses, install and sign in to your chosen coding agent CLI. BSA looks for Codex, Claude Code, Pi, OpenCode, Gemini. It also includes a standalone [Ollama agent](Configuration.md#ollama) for inference through your Ollama server; no external agent CLI is needed for Ollama.

```sh
./Scripts/install.sh
export PATH="$HOME/.local/bin:$PATH"
bsa --version                     # Boy Scout Agent 0.2.1 (<short commit hash>)
```

`VERSION` is the release version source. A SwiftPM plugin runs the Swift metadata
generator at build time to embed that version and the first seven characters of
Git HEAD. The build command declares the version file, generator script and Git metadata as inputs, so incremental builds refresh metadata on source and revision changes. Installed binaries report their build without Git or a checkout. Builds
from source archives without Git metadata report `unknown` for the build.

To install into a different directory, run `./Scripts/install.sh /path/to/bin`.
The script builds a release executable and replaces any existing BSA installation
only after a successful build.

Update an installed BSA from any directory:

```sh
bsa update
```

This downloads the latest `main` source from `https://github.com/tadija/boy-scout-agent`,
builds it with your local Swift toolchain, and replaces the executable you invoked
(resolving symlinks). Git, Swift 6 or later, network access, and write access to the
installation directory are required. This installs the current development branch,
which may report the same release version as your existing installation; the build
hash identifies its source commit. A failed build leaves your installed executable intact. Local source checkouts are unaffected.
You can also update your checkout and rerun `./Scripts/install.sh`.

