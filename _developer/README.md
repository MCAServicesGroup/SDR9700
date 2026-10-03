# SDR9700 Developer Documentation

This directory is the committed home for repository-wide developer
documentation, implementation status, CI support, analyzer configuration, and
shared maintenance utilities.

## Project State and Design

- [Development Status](STATUS.md) records the current source version and
  verified build, test, analysis, and benchmark state.
- [Project Issues](ISSUES.md) tracks confirmed issues found during project
  work, including their evidence, impact, next action, and resolution.
- [Repository Standard](STANDARD.md) defines cross-cutting implementation and
  maintenance requirements.
- [Architecture](ARCHITECTURE.md) describes the application layers, major
  components, threading model, radio definitions, and current constraints.

## Workflows

- [Qt SDK setup](scripts/setup_qt.sh) downloads the pinned Qt 6.12.0 SDK for
  source builds. Run it through `make qt-setup`; `make qt-prefix` prints the
  CMake prefix. [Qt pin](qt/qt_pin.env) records its version and supported host
  floors. Linux users build from source; Linux release packages are not
  planned at this time.
- [Debugging](DEBUGGING.md) documents debug builds, runtime logging categories,
  and log-file capture.
- [Releasing](RELEASING.md) defines version naming, release notes, verification,
  and publication requirements.

Canonical repository instructions and C++/Qt conventions remain at the root in
[`AGENTS.md`](../AGENTS.md) and [`CONVENTIONS.md`](../CONVENTIONS.md). Technical
IC-9700 protocol and research documents remain indexed in
[`docs/README.md`](../docs/README.md). Component-specific operational guides
remain beside the tooling or packaging components they describe.
