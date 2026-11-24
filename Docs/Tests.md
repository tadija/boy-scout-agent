# Testing BSA

```sh
swift test --parallel --num-workers 4
sh Tests/Integration/embedding-smoke.sh
sh Tests/Integration/version-smoke.sh
./Scripts/install.sh /tmp/bsa-bin
sh Tests/Integration/cli-smoke.sh /tmp/bsa-bin/bsa
```

BSA tests cover its canonical embedded mission, identity/defaults, historical
configuration and records, branch/commit conventions, mission overrides,
protected product config, scheduling names, and updater behavior. The CLI smoke
test uses fake harnesses to check existing user-facing behavior, dirty-checkout
preservation, independent verification, cancellation, locks, and schedules.
Installed binaries run outside the source tree with no mission resource bundle.

Shared engine regression tests, external Swift fixture integration, Ollama tests,
generic CLI tests, and public API consumer tests are owned by
[SwiftAgent](https://github.com/tadija/swift-agent/blob/0.1.0/Docs/Tests.md).
They are not duplicated here. CI validates each repository independently on
macOS and Linux. No test invokes a live model or paid harness.

The metadata and embedding smoke fixtures remain product-owned because BSA
embeds its own version, revision, and exact mission bytes. See the
[completion report](Plan/stage-3-completion.md) for extraction validation and
remote-release prerequisites.
