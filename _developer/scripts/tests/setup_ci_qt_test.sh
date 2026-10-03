#!/bin/bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
fixture="$(mktemp -d)"
trap 'rm -rf "$fixture"' EXIT
mkdir -p "$fixture/repo/_developer/scripts" "$fixture/runner temp"
cp "$repo_root/_developer/scripts/setup_ci_qt.sh" "$fixture/repo/_developer/scripts/"
cat > "$fixture/repo/_developer/scripts/setup_qt.sh" <<'SH'
#!/bin/bash
set -euo pipefail
if [ "${1:-}" = --print-prefix ]; then
    printf '%s\n' "$TEST_QT_PREFIX"
else
    printf '%s\n' "$SDR9700_QT_CACHE" > "$TEST_CAPTURE"
fi
SH

export RUNNER_TEMP="$fixture/runner temp"
export GITHUB_PATH="$fixture/github_path"
export GITHUB_ENV="$fixture/github_env"
export TEST_QT_PREFIX="$fixture/Qt SDK"
export TEST_CAPTURE="$fixture/capture"
bash "$fixture/repo/_developer/scripts/setup_ci_qt.sh"
test "$(cat "$TEST_CAPTURE")" = "$RUNNER_TEMP/sdr9700-qt"
test "$(cat "$GITHUB_PATH")" = "$TEST_QT_PREFIX/bin"
test "$(cat "$GITHUB_ENV")" = "CMAKE_PREFIX_PATH=$TEST_QT_PREFIX"

if env -u GITHUB_ENV bash "$fixture/repo/_developer/scripts/setup_ci_qt.sh" > "$fixture/output" 2>&1; then
    echo 'setup_ci_qt.sh unexpectedly succeeded without GITHUB_ENV' >&2
    exit 1
fi
grep -Fq 'GITHUB_ENV must be set by GitHub Actions' "$fixture/output"
