#!/bin/bash
# Install and select the repository-pinned Qt SDK in a GitHub Actions job.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
: "${RUNNER_TEMP:?RUNNER_TEMP must be set by GitHub Actions}"
: "${GITHUB_PATH:?GITHUB_PATH must be set by GitHub Actions}"
: "${GITHUB_ENV:?GITHUB_ENV must be set by GitHub Actions}"

# A fresh runner cache forces setup_qt.sh to verify the upstream package
# revision before aqt downloads it, and to validate the installed modules.
export SDR9700_QT_CACHE="$RUNNER_TEMP/sdr9700-qt"
bash "$repo_root/_developer/scripts/setup_qt.sh"
qt_root="$(bash "$repo_root/_developer/scripts/setup_qt.sh" --print-prefix)"
printf '%s\n' "$qt_root/bin" >> "$GITHUB_PATH"
printf 'CMAKE_PREFIX_PATH=%s\n' "$qt_root" >> "$GITHUB_ENV"
