# Tests

Run the core suite with `swift test`. External integration tests are skipped by default so routine BSA iterations avoid compiling a separate Swift fixture package. Isolation, cancellation, verification, and publication checks stay in the core suite. Ollama tests use simulated tool-call conversations and a mock HTTP transport; they do not require an Ollama server, an installed model, or external agent CLIs.

Before a release, run the external integration suite and CLI smoke test too:

```sh
BSA_INTEGRATION_TESTS=1 swift test --filter ExternalIntegrationTests
sh Tests/Integration/embedding-smoke.sh
swift build -c release
sh Tests/Integration/cli-smoke.sh "$(swift build -c release --show-bin-path)/bsa"
```

CI runs these suites on macOS and Linux. External integration tests cover a real Swift package with a failing baseline that the harness fixes, and the Codex adapter using a fake executable; they never call a real model. Use `BSA_INTEGRATION_TESTS=1 swift test` to run both Swift suites together.

Prompt tests compare embedded bytes with canonical `prompt.md`, cover identity defaults, configured and explicit overrides, composition with guidance/history, invalid files, and protected-path rejection despite a hostile mission. CLI smoke tests exercise invocation-relative prompt paths from a repository subdirectory and CLI precedence over an invalid configured mission. The embedding smoke test builds a tiny clean SwiftPM fixture with the real plugin, verifies special characters, rebuilds after Markdown and generator changes, and runs the executable after removing its Markdown. Run the CLI smoke test against a binary installed outside the checkout to validate self-contained embedding.
