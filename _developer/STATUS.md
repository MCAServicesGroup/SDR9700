# SDR9700 Development Status

SDR9700 is under active development for Linux and Apple Silicon macOS. The
current source version is `26.10.1`.

## Release State

- `26.10.1` is the current stable GitHub release, published from signed tag
  `v26.10.1` at commit `84dd3bc18d174951b893e520ca97dad6b9d71cb2`.
- The Apple Silicon release workflow built, tested, audited, signed, notarized,
  and stapled `SDR9700-26.10.1-macOS-apple-silicon.dmg` before attaching it to
  the GitHub release. Run `37169042496` passed, and Apple Gatekeeper accepted
  the disk image as a notarized Developer ID release.
- The GitHub repository is public at
  <https://github.com/MCAServicesGroup/SDR9700>, as required by the repository
  policy.
- Linux release packages are not planned at this time. Linux users who want to
  use SDR9700 must build it from source.

## Current Work

- The signed `v26.10.1` tag, Apple Silicon DMG, and stable GitHub release are
  published. Radio and audio hardware validation remains.
- PR #56 merged the Qt 6.12 minimum and local Qt SDK setup target. Linux and
  Apple Silicon CI builds, tests, Metal rendering, and the unsigned macOS
  bundle audit pass. Signed DMG and notarization validation passed in the
  `26.10.1` release; radio/audio hardware validation remains.
- PR #57 fixes Qt SDK setup for Python 3.9 on macOS; its Build and CodeQL
  checks pass. The maintainer's local Qt download remains to be confirmed.
- PR #58 moved repository and application links to
  `MCAServicesGroup/SDR9700` and corrected the code owner entry.
- macOS releases now use a draft-first process: dispatch the release workflow
  from `main` for an existing signed version tag, then publish the draft only
  after the packaged DMG and release notes are reviewed.
- The `macos_release` GitHub environment has a `main`-only deployment policy
  and required maintainer review. The Apple secrets remain at repository scope
  at the maintainer's request; their move into the environment is deferred.
- Keep the normal Linux and Apple Silicon macOS build and test workflows green.
- Preserve hardware-independent automated coverage; radio-dependent behavior
  still requires explicit IC-9700 validation.

## Qt 6.12 Migration Validation

- The local setup script installed the pinned prebuilt Qt 6.12.0 SDK and
  verified package revision `202609280346`, required modules, and its cached
  no-op path. The same revision appears in the macOS package metadata.
- A clean Linux Release build and all 37 tests pass against Qt 6.12.0.
- A clean Linux GPU-panadapter build and all 40 tests pass against Qt 6.12.0,
  using a temporary X server and software Vulkan for the three GPU tests.
- The clang-format 23 and cppcheck 2.21.0 source checks pass.
- GitHub Build run `37158990926` passes the Linux, Linux without HIDAPI,
  Linux GPU panadapter, and Apple Silicon jobs. The Apple Silicon job passes
  Metal rendering tests, the full test suite, and the self-contained bundle
  audit with the official macOS 15.0 floor.
- The `26.10.1` Apple Silicon DMG passed signing, notarization, stapling, and
  Gatekeeper assessment with Qt 6.12. Radio/audio hardware behavior has not
  yet been validated after the migration.

## Pre-Migration Validation State

The results below describe the previous Qt build configuration. The
local Qt 6.8.2 installation is rejected by the new CMake minimum.

- The clean local Release build and all 37 tests pass.
- The clean AddressSanitizer/UndefinedBehaviorSanitizer build and all 37 tests
  pass.
- The clean ThreadSanitizer build and all 31 compatible tests pass. Six tests
  remain covered by normal and ASan/UBSan CI but are excluded from TSan because
  they exercise unsupported process-launch or uninstrumented Qt runtime paths.
- The clang-format 23 and cppcheck 2.21.0 source checks pass.
- The exact `26.9.4` release commit passes the Linux, Linux without HIDAPI,
  Linux GPU panadapter, and Apple Silicon macOS GitHub build jobs.
- The exact `26.9.4` release commit passes the CodeQL GitHub Actions, C/C++,
  and Python analyses.
- The local performance benchmark suite passes, matching every recorded
  nightly workflow run.
- The latest manually dispatched GitHub Nightly Analysis workflow passes its
  ASan/UBSan, TSan, and performance benchmark jobs.
