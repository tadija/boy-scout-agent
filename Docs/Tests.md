# Tests

Run the core suite with `swift test`, or use `swift test --parallel --num-workers 4` for faster execution with isolated XCTest worker processes (also used in CI). External integration tests are skipped by default so routine BSA iterations avoid compiling a separate Swift fixture package. Isolation, cancellation, verification, and publication checks stay in the core suite. Ollama tests use simulated tool-call conversations and a mock HTTP transport; they do not require an Ollama server, an installed model, or external agent CLIs.

Before a release, run the external integration suite and CLI smoke test too:

```sh
BSA_INTEGRATION_TESTS=1 swift test --filter ExternalIntegrationTests
sh Tests/Integration/embedding-smoke.sh
sh Tests/Integration/version-smoke.sh
swift build -c release
sh Tests/Integration/cli-smoke.sh "$(swift build -c release --show-bin-path)/bsa"
```

CI runs these suites on macOS and Linux. The external integration test covers a real Swift package with a failing baseline that the harness fixes. CLI smoke tests cover the Codex adapter and other harnesses using fake executables; they never call a real model. Use `BSA_INTEGRATION_TESTS=1 swift test` to run both Swift suites together.

Prompt tests compare embedded bytes with canonical `prompt.md`, cover identity defaults, configured and explicit overrides, composition with guidance/history, invalid files, and protected-path rejection despite a hostile mission. CLI smoke tests exercise invocation-relative prompt paths from a repository subdirectory and CLI precedence over an invalid configured mission. The embedding smoke test builds a tiny clean SwiftPM fixture with the real plugin, verifies special characters, rebuilds after Markdown and generator changes, and runs the executable after removing its Markdown. Run the CLI smoke test against a binary installed outside the checkout to validate self-contained embedding.

The version smoke test uses a tiny SwiftPM fixture to check `VERSION` changes, commits with unchanged sources, branch switches, packed refs, linked Git worktree commits, unchanged output preservation, invalid versions, and archive fallback without borrowing an enclosing repository revision.

Keep current safety and lifecycle regressions in the core suite. Historical record-schema compatibility is not a test requirement at this stage. Reuse successful iteration coverage for timing/history assertions, use only two iterations to prove fresh worktrees, and keep process-only and agent-definition tests independent of Git fixtures.

To use the parallel command during BSA iterations, set `"verification": ["swift test --parallel --num-workers 4"]` in `bsa.json`. The baseline uses the same command unless configured separately. Automatic Swift detection continues to use `swift test`.
