# SDR9700 Development Status

SDR9700 is under active development for Linux and Apple Silicon macOS. The
current source version is `26.9.4`.

## Release State

- `26.9.4` is the current stable GitHub release, published from signed tag
  `v26.9.4` at commit `8427927394c2688bd09015b1daa88c6a1bd598e5`.
- The Apple Silicon release workflow built, tested, audited, signed, notarized,
  and stapled `SDR9700-26.9.4-macOS-apple-silicon.dmg` before attaching it to
  the GitHub release.
- The GitHub repository is public, as required by the repository policy.
- Linux release packages are not planned at this time. Linux users who want to
  use SDR9700 must build it from source.

## Current Work

- The `qt_6_12_migration` branch raises the minimum supported Qt version to
  6.12.0 and provides a local Qt SDK setup target. Local Linux Release and GPU
  builds pass; Apple Silicon CI, packaging, and hardware validation remain.
- macOS releases now use a draft-first process: dispatch the release workflow
  from `main` for an existing signed version tag, then publish the draft only
  after the packaged DMG and release notes are reviewed.
- The `macos_release` GitHub environment has a `main`-only deployment policy
  and required maintainer review. Its Apple secrets still need to be moved
  from repository scope into the environment before the new workflow is used.
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
- Apple Silicon build, Metal rendering, bundle packaging, and radio/audio
  hardware behavior have not yet been validated on this branch.

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
