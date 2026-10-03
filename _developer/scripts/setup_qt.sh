#!/bin/bash
# Download the pinned Qt SDK for SDR9700 source builds on Linux or macOS.
# The SDK is cached per user, outside the repository. An install is published
# only after its version and required modules have been checked. Older installs
# remain available until --prune, because built applications may refer to their
# absolute paths.
#
# Usage:
#   bash _developer/scripts/setup_qt.sh                 install the pinned SDK
#   bash _developer/scripts/setup_qt.sh --print-prefix  print its CMake prefix
#   bash _developer/scripts/setup_qt.sh --prune         remove old SDK generations
#
# Requires python3 with venv, curl, network access, and about 3 GB free space.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PIN_FILE="$REPO_ROOT/_developer/qt/qt_pin.env"

die() { echo "ERROR: $*" >&2; exit 1; }

[ -f "$PIN_FILE" ] || die "$PIN_FILE is missing."
# shellcheck source=../qt/qt_pin.env
. "$PIN_FILE"

PRINT_PREFIX=0
PRUNE=0
for arg in "$@"; do
    case "$arg" in
        --print-prefix) PRINT_PREFIX=1 ;;
        --prune)        PRUNE=1 ;;
        -h|--help)      sed -n '2,/^set -euo/p' "$0" | sed '$d; s/^# \{0,1\}//'; exit 0 ;;
        *)              die "unknown argument: $arg (try --help)" ;;
    esac
done

# ── Platform → aqt host/arch and the directory aqt lays the kit down in ──
OS="$(uname -s)"
MACHINE="$(uname -m)"
case "$OS/$MACHINE" in
    Linux/x86_64)
        AQT_HOST=linux; AQT_ARCH=linux_gcc_64; KIT_DIR=gcc_64
        REPO_HOST=linux_x64; MIN_GLIBC="$QT_MIN_GLIBC_X86_64" ;;
    Linux/aarch64|Linux/arm64)
        AQT_HOST=linux_arm64; AQT_ARCH=linux_gcc_arm64; KIT_DIR=gcc_arm64
        REPO_HOST=linux_arm64; MIN_GLIBC="$QT_MIN_GLIBC_AARCH64" ;;
    Darwin/*)
        # clang_64 is universal2 — one kit for Intel and Apple Silicon.
        AQT_HOST=mac; AQT_ARCH=clang_64; KIT_DIR=macos
        REPO_HOST=mac_x64; MIN_GLIBC="" ;;
    *)
        die "Qt publishes no desktop binaries for $OS/$MACHINE. Build Qt $QT_SOURCE_FLOOR+
       from source, or use a distro Qt $QT_SOURCE_FLOOR+ if yours ships one." ;;
esac

if [ "$OS" = "Darwin" ]; then
    CACHE_ROOT="${SDR9700_QT_CACHE:-$HOME/Library/Caches/sdr9700/qt}"
else
    CACHE_ROOT="${SDR9700_QT_CACHE:-${XDG_CACHE_HOME:-$HOME/.cache}/sdr9700/qt}"
fi
case "$CACHE_ROOT" in
    /*) ;;
    *) die "SDR9700_QT_CACHE must be an absolute path." ;;
esac
# The revision is part of every name: RC and final share a version string, and
# a rebuilt Qt behind an unchanged pin must never be mistaken for the old one.
PIN_TAG="$QT_VERSION-$QT_PACKAGE_REVISION"
POINTER="$CACHE_ROOT/$PIN_TAG.current"
GEN_ROOT="$CACHE_ROOT/gen"
STAMP_CONTENT="version=$QT_VERSION revision=$QT_PACKAGE_REVISION arch=$AQT_ARCH modules=$QT_MODULES aqt=$AQTINSTALL_VERSION"

# The live generation's directory name, or nothing.
CURRENT_GEN=""
if [ -f "$POINTER" ]; then
    CURRENT_GEN="$(head -n 1 "$POINTER")"
fi
prefix_of() { echo "$GEN_ROOT/$1/$QT_VERSION/$KIT_DIR"; }
QT_PREFIX=""
[ -n "$CURRENT_GEN" ] && QT_PREFIX="$(prefix_of "$CURRENT_GEN")"

# ── --prune: reclaim superseded generations, on request only ────────────
# Keeps the live generation of the current pin and any unfinished generation
# whose owning install is still running (another checkout, mid-install).
# Everything else under gen/ goes, including generations of earlier pins, along
# with pointer files that would be left naming them.
if [ "$PRUNE" = 1 ]; then
    removed=0
    for d in "$GEN_ROOT"/*; do
        [ -d "$d" ] || continue
        name="${d##*/}"
        [ "$name" = "$CURRENT_GEN" ] && continue
        if [ ! -f "$d/.sdr9700_qt_stamp" ] && kill -0 "${name##*-}" 2>/dev/null; then
            echo "Keeping $name: an install is still running in it"
            continue
        fi
        echo "Removing $name"
        rm -rf "${d:?}"
        removed=$((removed + 1))
    done
    for ptr in "$CACHE_ROOT"/*.current; do
        [ -f "$ptr" ] || continue
        [ "$ptr" = "$POINTER" ] && continue
        [ -d "$GEN_ROOT/$(head -n 1 "$ptr")" ] || rm -f "$ptr"
    done
    echo "Pruned $removed generation(s). Live: ${CURRENT_GEN:-none}"
    echo "Applications linked against a removed generation must be rebuilt."
    exit 0
fi

if [ "$PRINT_PREFIX" = 1 ]; then
    if [ -n "$QT_PREFIX" ] && [ -f "$GEN_ROOT/$CURRENT_GEN/.sdr9700_qt_stamp" ] &&
       [ "$(cat "$GEN_ROOT/$CURRENT_GEN/.sdr9700_qt_stamp")" = "$STAMP_CONTENT" ] &&
       [ -x "$QT_PREFIX/bin/qmake" ] &&
       [ "$("$QT_PREFIX/bin/qmake" -query QT_VERSION)" = "$QT_VERSION" ]; then
        echo "$QT_PREFIX"
        exit 0
    fi
    echo "Qt $QT_VERSION is not installed; run bash _developer/scripts/setup_qt.sh" >&2
    exit 1
fi

# True when numeric version $1 is older than $2.
older_than() {
    python3 - "$1" "$2" <<'PY'
import sys
parse = lambda value: tuple(int(part) for part in value.split('.'))
sys.exit(0 if parse(sys.argv[1]) < parse(sys.argv[2]) else 1)
PY
}

# ── Already installed? ───────────────────────────────────────────────────
if [ -n "$CURRENT_GEN" ] && [ -f "$GEN_ROOT/$CURRENT_GEN/.sdr9700_qt_stamp" ] &&
   [ "$(cat "$GEN_ROOT/$CURRENT_GEN/.sdr9700_qt_stamp")" = "$STAMP_CONTENT" ] &&
   [ -x "$QT_PREFIX/bin/qmake" ] &&
   [ "$("$QT_PREFIX/bin/qmake" -query QT_VERSION)" = "$QT_VERSION" ]; then
    echo "Qt $QT_VERSION ($QT_PACKAGE_REVISION) already installed at $QT_PREFIX"
    exit 0
fi

# ── Preflight: refuse before downloading, with the way out ───────────────
command -v python3 >/dev/null 2>&1 || die "python3 not found (needed for aqtinstall)."
command -v curl >/dev/null 2>&1 || die "curl not found."
if [ -n "$MIN_GLIBC" ]; then
    GLIBC="$(getconf GNU_LIBC_VERSION 2>/dev/null | awk '{print $2}')"
    if [ -z "$GLIBC" ]; then
        die "this system's C library is not glibc (musl?). Qt's Linux binaries
       need glibc $MIN_GLIBC+. Use a distro Qt $QT_SOURCE_FLOOR+ if yours ships one,
       or build Qt from source."
    fi
    if older_than "$GLIBC" "$MIN_GLIBC"; then
        die "Qt $QT_VERSION's $MACHINE binaries need glibc $MIN_GLIBC; this system has $GLIBC.
       They would install, then fail to load. Options: a distro Qt $QT_SOURCE_FLOOR+,
       or a newer OS release."
    fi
    echo "glibc $GLIBC — OK (Qt $QT_VERSION needs $MIN_GLIBC)"
fi

if [ "$OS" = "Darwin" ]; then
    # `|| true`: with only the Command Line Tools, xcodebuild exits non-zero,
    # and under set -e that would end the script before the guidance below.
    XCODE="$(xcodebuild -version 2>/dev/null | awk '/^Xcode/ {print $2}' || true)"
    if [ -z "$XCODE" ]; then
        die "Xcode not found. Qt $QT_VERSION needs Xcode $QT_MIN_XCODE+ (the Command Line
       Tools alone are not enough for Qt's SDK check)."
    fi
    if older_than "$XCODE" "$QT_MIN_XCODE"; then
        die "Qt $QT_VERSION needs Xcode $QT_MIN_XCODE+; this Mac has Xcode $XCODE. Qt's CMake
       stops at configure otherwise."
    fi
    MACOS="$(sw_vers -productVersion)"
    if older_than "$MACOS" "$QT_MIN_MACOS"; then
        echo "WARNING: this Mac runs macOS $MACOS; Qt $QT_VERSION apps need $QT_MIN_MACOS+." >&2
        echo "         It can build here, but the result will not launch on this Mac." >&2
    fi
    echo "Xcode $XCODE — OK (Qt $QT_VERSION needs $QT_MIN_XCODE)"
fi

mkdir -p "$CACHE_ROOT"
# 3 GB: ~2 GB installed plus the archives aqt holds while extracting.
FREE_KB="$(df -Pk "$CACHE_ROOT" | awk 'NR==2 {print $4}')"
if [ "${FREE_KB:-0}" -lt 3145728 ]; then
    die "need ~3 GB free under $CACHE_ROOT, have $((FREE_KB / 1024)) MB.
       Point SDR9700_QT_CACHE at a roomier disk."
fi

# The repository must still serve the build the pin names. aqt asks for the
# version string only, so a republished Qt would otherwise install silently.
VER_TAG="qt6_$(echo "$QT_VERSION" | tr -d .)"
UPDATES_URL="https://download.qt.io/online/qtsdkrepository/$REPO_HOST/desktop/$VER_TAG/$VER_TAG/Updates.xml"
PKG="qt.qt6.$(echo "$QT_VERSION" | tr -d .).$AQT_ARCH"
# Fetched whole, then parsed: piping curl straight into an awk that exits at the
# first match kills curl with SIGPIPE, which pipefail reports as a failed fetch.
UPDATES_XML="$(curl -fsSL --max-time 60 "$UPDATES_URL")" \
    || die "could not read $UPDATES_URL (offline?)."
SERVED="$(printf '%s\n' "$UPDATES_XML" | tr -d '\r' | awk -v pkg="$PKG" '
    /<Name>/    { name = $0; sub(/.*<Name>/, "", name); sub(/<\/Name>.*/, "", name) }
    /<Version>/ && name == pkg && !done { v = $0; sub(/.*<Version>/, "", v); sub(/<\/Version>.*/, "", v); print v; done = 1 }')"
case "$SERVED" in
    *-"$QT_PACKAGE_REVISION") echo "Qt repository serves $SERVED — matches the pin" ;;
    "") die "$PKG is not listed in $UPDATES_URL." ;;
    *)  die "the Qt repository now serves $PKG $SERVED, but _developer/qt/qt_pin.env pins
       revision $QT_PACKAGE_REVISION. Qt has republished $QT_VERSION; the pin needs a
       deliberate bump (and CI a re-run) before anyone builds against it." ;;
esac

# ── Install ──────────────────────────────────────────────────────────────
# Install into a new generation and publish its pointer only once complete.
# An interrupted extraction must never become the selected kit.
# The marker, not bin/aqt, says the venv is complete: an interrupted pip can
# leave the aqt entry point in place with its dependencies half-installed.
VENV="$CACHE_ROOT/aqt-venv-$AQTINSTALL_VERSION-py7zr$PY7ZR_VERSION"
if [ ! -f "$VENV/.complete" ]; then
    rm -rf "$VENV"
    if ! python3 -m venv "$VENV" >/dev/null 2>&1; then
        rm -rf "$VENV"
        die "python3 cannot create a virtual environment. On Debian, Ubuntu and
       Raspberry Pi OS install it with:  sudo apt install python3-venv"
    fi
    "$VENV/bin/pip" install -q "aqtinstall==$AQTINSTALL_VERSION" "py7zr==$PY7ZR_VERSION"
    touch "$VENV/.complete"
fi

# Generations left by a run that was killed outright (no EXIT trap) are
# unpublished and unfinished; their owning PID is in the name. Remove only
# those whose owner is gone: a live one may be another checkout's install in
# progress.
mkdir -p "$GEN_ROOT"
for d in "$GEN_ROOT/$PIN_TAG"-*; do
    [ -d "$d" ] || continue
    name="${d##*/}"
    [ "$name" = "$CURRENT_GEN" ] && continue
    [ -f "$d/.sdr9700_qt_stamp" ] && continue
    pid="${name##*-}"
    if ! kill -0 "$pid" 2>/dev/null; then
        echo "Removing an abandoned partial install: $name"
        rm -rf "$d"
    fi
done

# The new generation is built in its final location. Nothing points at it
# until the pointer is replaced below, so a failure here removes only itself.
NEW_GEN="$PIN_TAG-$(date +%s)-$$"
NEW_DIR="$GEN_ROOT/$NEW_GEN"
trap 'rm -rf "$NEW_DIR" "$POINTER.tmp.$$"' EXIT
echo "Installing Qt $QT_VERSION $AQT_ARCH ($QT_MODULES) — about 2 GB..."
# shellcheck disable=SC2086  # QT_MODULES is a deliberate word list
"$VENV/bin/aqt" install-qt "$AQT_HOST" desktop "$QT_VERSION" "$AQT_ARCH" \
    -m $QT_MODULES --outputdir "$NEW_DIR"

STAGED_PREFIX="$(prefix_of "$NEW_GEN")"
[ -x "$STAGED_PREFIX/bin/qmake" ] || die "aqt finished but left no qmake at $STAGED_PREFIX."
GOT="$("$STAGED_PREFIX/bin/qmake" -query QT_VERSION)"
[ "$GOT" = "$QT_VERSION" ] || die "aqt installed Qt $GOT, expected $QT_VERSION."
# qmake only proves qtbase landed; a partial install can still exit 0.
for m in $QT_MODULES; do
    case "$m" in
        qtmultimedia) pkg=Multimedia ;; qtshadertools) pkg=ShaderTools ;;
        *) continue ;;
    esac
    [ -f "$STAGED_PREFIX/lib/cmake/Qt6$pkg/Qt6${pkg}Config.cmake" ] ||
        die "aqt did not install Qt6$pkg ($m)."
done
for pkg in Core Widgets Network MultimediaWidgets Sql Svg Test GuiPrivate; do
    [ -f "$STAGED_PREFIX/lib/cmake/Qt6$pkg/Qt6${pkg}Config.cmake" ] ||
        die "aqt did not install required Qt6$pkg."
done
[ -f "$STAGED_PREFIX/plugins/sqldrivers/libqsqlite.so" ] ||
    [ -f "$STAGED_PREFIX/plugins/sqldrivers/libqsqlite.dylib" ] ||
    die "aqt did not install the SQLite driver plugin."

echo "$STAMP_CONTENT" > "$NEW_DIR/.sdr9700_qt_stamp"
# Publish: rename(2) of a regular file over another on the same filesystem is
# atomic, on GNU and BSD mv alike. Until this line the old generation is live;
# from it on, the new one is.
echo "$NEW_GEN" > "$POINTER.tmp.$$"
mv -f "$POINTER.tmp.$$" "$POINTER"
trap - EXIT
QT_PREFIX="$STAGED_PREFIX"
echo "Qt $QT_VERSION installed at $QT_PREFIX"
# The superseded generation stays because existing binaries may link to it.
if [ -n "$CURRENT_GEN" ] && [ "$CURRENT_GEN" != "$NEW_GEN" ]; then
    echo "Previous generation $CURRENT_GEN kept; run with --prune to remove it."
fi

echo
echo "Select this Qt for SDR9700 builds with:"
echo "  export CMAKE_PREFIX_PATH=\"$QT_PREFIX\""
echo "  make release"
