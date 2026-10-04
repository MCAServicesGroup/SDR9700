# SDR9700 Project Issues

This file is the durable repository-wide ledger for issues identified during
SDR9700 project work. Record findings from implementation, review, testing,
CI, documentation, packaging, release work, hardware validation, security
checks, and repository administration here so they are not lost when they are
outside the immediate task.

## Tracking Rules

- Assign each issue the next sequential `SDR-NNNN` identifier. Never reuse an
  identifier.
- Record a confirmed issue when it is identified, even when it can be resolved
  during the same task. Do not record unsupported speculation as a finding.
- Include concrete evidence, user or project impact, and the next action needed
  to make progress.
- Use one of these statuses: `open`, `investigating`, `blocked`, `deferred`, or
  `resolved`.
- Use one of these severities: `critical`, `high`, `medium`, or `low`.
- Update an existing entry instead of creating a duplicate. Link a GitHub issue
  or pull request when one exists.
- Move completed entries to **Resolved Issues**, adding the resolution and date.
  Do not delete resolved history.
- Do not include credentials, private keys, production data, personal data, or
  other sensitive evidence. Store sensitive local material only under
  `_workspace/private/` and describe it here without exposing it.

## Entry Format

```markdown
### SDR-NNNN: Concise issue title

- Status: `open`
- Severity: `medium`
- Area: Component, workflow, or platform
- Identified: YYYY-MM-DD during the activity that exposed the issue
- Evidence: Reproduction details, logs, test names, or affected paths
- Impact: User-facing or project consequence
- Next action: Specific investigation, decision, or implementation step
- Related: GitHub issue, pull request, commit, or documentation path
```

## Open Issues

### SDR-0006: Apple release secrets remain at repository scope

- Status: `deferred`
- Severity: `high`
- Area: GitHub Actions release credentials
- Identified: 2026-10-03 while configuring the `macos_release` environment
- Evidence: The environment has a `main`-only branch policy and required
  maintainer review, but no environment secrets. The five Apple signing and
  notarization secret names remain configured at repository scope.
- Impact: Other workflows can still access the repository-scoped credentials,
  so the release environment does not yet isolate them.
- Next action: When the maintainer is ready to move the secrets, re-enter the
  five Apple secrets in `macos_release` from the originals, verify their names,
  then delete the repository-scoped copies. The maintainer requested on
  2026-10-03 that repository-scoped copies remain for now.
- Related: `resources/packaging/macos/README.md`, `.github/workflows/release_macos.yml`

## Resolved Issues

### SDR-0010: Qt setup rejected the macOS Python 3.9 environment

- Status: `resolved`
- Severity: `medium`
- Area: Qt SDK setup for macOS source builds
- Identified: 2026-10-03 from a maintainer `make qt-setup` failure on macOS
- Evidence: The helper pinned `py7zr==1.1.3`, which requires Python 3.10 or
  newer. The maintainer's pip listed `1.0.0` as the newest compatible release
  and could not install `1.1.3`. A Python 3.9 Apple Silicon wheel resolution
  succeeds with `aqtinstall==3.3.0` and `py7zr==1.0.0`.
- Impact: Qt SDK setup stopped before downloading Qt on a supported Mac.
- Resolution: 2026-10-03. Pin `py7zr==1.0.0` and document Python 3.9 as the
  minimum for the setup helper.
- Related: `_developer/qt/qt_pin.env`, `_developer/scripts/setup_qt.sh`, PR #56

### SDR-0009: Duplicate Build triggers left canceled checks on the PR

- Status: `resolved`
- Severity: `low`
- Area: GitHub Actions build workflow
- Identified: 2026-10-03 while reviewing PR #56 checks
- Evidence: A push to `qt_6_12_migration` and the corresponding pull request
  started Build runs for the same commit. The later pull request run canceled
  the push run under their shared concurrency group. GitHub displayed its four
  canceled jobs as failed checks alongside four passing pull request jobs.
- Impact: PR #56 appeared to have failing CI despite all current Build and
  CodeQL jobs passing.
- Resolution: 2026-10-03. Build runs on pull requests and pushes to `main` or
  `ci-*` tags; the temporary migration branch no longer starts a duplicate
  push run.
- Related: `.github/workflows/build.yml`, PR #56

### SDR-0008: Bundle audit rejected unused in-bundle rpaths

- Status: `resolved`
- Severity: `medium`
- Area: macOS bundle verification
- Identified: 2026-10-03 in Apple Silicon CI run `37157912537`
- Evidence: Qt plugins carried `@loader_path/../../lib` rpaths whose directories
  were absent from the staged bundle. All linked dependencies resolved through
  other bundled paths, but `verify_macos_bundle.sh` failed on the absent rpath
  directories.
- Impact: A self-contained bundle could fail packaging even though the unused
  rpaths did not prevent loading.
- Resolution: 2026-10-03. The audit allows absent rpath directories only when
  their canonical paths remain inside the bundle; linked dependency targets
  must still exist inside it.
- Related: `resources/packaging/macos/scripts/verify_macos_bundle.sh`

### SDR-0007: Bundled libraries required macOS 15 above the declared floor

- Status: `resolved`
- Severity: `high`
- Area: Apple Silicon macOS packaging
- Identified: 2026-10-03 in Apple Silicon CI run `37157912537`
- Evidence: The bundle declared macOS 14.4, but Homebrew builds of OpenSSL,
  HIDAPI, SpeexDSP, and Opus bundled by the macos-15 job have Mach-O minimum
  version 15.0. The bundle audit caught the mismatch.
- Impact: The DMG could be advertised for Macs on which bundled libraries
  cannot load.
- Resolution: 2026-10-03. With the maintainer's decision, the official DMG
  minimum is 15.0. CMake, Info.plist, documentation, and the bundle audit use
  the release floor separately from Qt's own 14.4 minimum.
- Related: `resources/packaging/macos/release_pin.env`, `CMakeLists.txt`,
  `resources/packaging/macos/scripts/verify_macos_bundle.sh`

### SDR-0005: macOS bundle did not verify its Qt version

- Status: `resolved`
- Severity: `medium`
- Area: macOS application bundling
- Identified: 2026-10-03 during Qt 6.12 migration review
- Evidence: `deploy_macos.sh` selects `macdeployqt` from `PATH` and does not
  verify that it belongs to the Qt installation used to build the application.
  The bundle audit checks load paths and missing dependencies but does not
  verify the bundled Qt version.
- Impact: A mismatched deployment tool can produce a bundle with inconsistent
  Qt libraries or plugins despite a successful build.
- Related: `resources/packaging/macos/scripts/deploy_macos.sh`,
  `resources/packaging/macos/scripts/verify_macos_bundle.sh`

- Resolution: 2026-10-03. The bundle audit now checks the bundled QtCore
  version against the repository pin, verifies required bundle dependencies
  remain inside the application bundle, and checks the macOS deployment floor.

### SDR-0004: Release packaging starts after publication

- Status: `resolved`
- Severity: `medium`
- Area: macOS release workflow
- Identified: 2026-10-03 during Qt 6.12 migration review
- Evidence: The workflow used the `release.published` event, so the release
  could become public before the signed and notarized DMG was available.
- Impact: Packaging, signing, or notarization failure could leave a public
  release without its promised macOS installer.
- Related: `.github/workflows/release_macos.yml`, `_developer/RELEASING.md`

- Resolution: 2026-10-03. Packaging now runs only by manual dispatch,
  requires an existing draft release, and rechecks draft status before
  attaching the DMG. The maintainer publishes the release after reviewing
  the draft.

### SDR-0003: Release workflow accepts an unverified dispatch ref

- Status: `resolved`
- Severity: `medium`
- Area: macOS release workflow
- Identified: 2026-10-03 during Qt 6.12 migration review
- Evidence: The workflow dispatch input selected a checkout ref independently
  of the target GitHub Release; version matching alone did not verify that the
  ref was the signed release tag or that its commit matched the release source.
- Impact: A manually dispatched run could package source other than the
  reviewed, signed release commit.
- Related: `.github/workflows/release_macos.yml`

- Resolution: 2026-10-03. The workflow runs only from `main`, verifies the
  requested signed tag, requires it to point at the dispatch commit, and checks
  that its version matches the source.

### SDR-0002: Qt version is duplicated between the local pin and CI

- Status: `resolved`
- Severity: `low`
- Area: Qt setup and GitHub Actions workflows
- Identified: 2026-10-03 during Qt 6.12 migration documentation
- Evidence: `_developer/qt/qt_pin.env` defines the local SDK version, while
  `.github/workflows/build.yml`, `nightly.yml`, and `release_macos.yml` each
  define their own `QT_VERSION` value.
- Impact: Updating only one value can make local builds and CI or release builds
  use different Qt versions.
- Related: `_developer/qt/qt_pin.env`, `.github/workflows/`

- Resolution: 2026-10-03. CI and release workflows now call the shared Qt
  setup script, which reads the repository pin.

### SDR-0001: Intermittent ThreadSanitizer race in CachingQueueTest

- Status: `resolved`
- Severity: `medium`
- Area: Nightly Analysis ThreadSanitizer job, `src/tests/CachingQueueTest.cpp`
- Identified: 2026-09-29 during review of the failed scheduled Nightly
  Analysis run 36585988851 on commit `047b2fe`
- Evidence: TSan reported a data race in
  `CachingQueueTest::deliversValueArrivingDuringBatchEmission` between the
  main thread constructing a `sendValues` slot object in `connect()` and the
  `CachingQueue` worker invoking it. The worker was still emitting a batch left
  by `emitsCacheChangesWithoutHoldingMutex`; `resetSessionState()` in
  `init()` cannot recall a batch already moved out of `items`, and the
  uninstrumented distribution Qt hides Qt's own connection-list ordering from
  TSan. The original test reproduced the report in 54 of 200 local macOS TSan
  runs.
- Impact: The nightly TSan job failed intermittently, and the stale batch
  could be counted as the test's first emission so the lost-wakeup regression
  test could pass without exercising its window.
- Resolution: 2026-09-29. `CachingQueue` records `m_workerIdle` under its
  mutex while the worker blocks with no work, and `CachingQueueTest::init()`
  waits for an idle worker with empty queues before each test connects
  receivers. The fixed test passed 100 consecutive local TSan runs and the
  full local TSan suite passes.
- Related: `src/core/CachingQueue.cpp`, `src/tests/CachingQueueTest.cpp`
