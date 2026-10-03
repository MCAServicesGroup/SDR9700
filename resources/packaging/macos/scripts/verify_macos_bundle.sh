#!/bin/sh

set -eu

if [ "$(uname -s)" != "Darwin" ]; then
    echo "The macOS bundle verification script can only run on macOS." >&2
    exit 1
fi

app_path="${1:-_workspace/build/bin/SDR9700.app}"
contents_path="${app_path}/Contents"
frameworks_path="${contents_path}/Frameworks"

if [ ! -x "${contents_path}/MacOS/SDR9700" ]; then
    echo "SDR9700 application bundle not found at ${app_path}" >&2
    exit 1
fi
bundle_root="$(cd "${app_path}" && pwd -P)"

if [ "$(plutil -extract CFBundleDisplayName raw -o - "${contents_path}/Info.plist")" != "SDR9700" ]; then
    echo "Unexpected CFBundleDisplayName; expected SDR9700" >&2
    exit 1
fi

errors_file="$(mktemp /tmp/sdr9700-bundle-errors.XXXXXX)"
trap 'rm -f "${errors_file}"' EXIT HUP INT TERM

check_bundled_path()
{
    candidate="${1}"
    source_path="${2}"
    description="${3}"
    if [ ! -e "${candidate}" ]; then
        echo "${source_path}: missing ${description}" >>"${errors_file}"
        return
    fi
    resolved_path="$(python3 -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "${candidate}")" || {
        echo "${source_path}: cannot resolve ${description}" >>"${errors_file}"
        return
    }
    case "${resolved_path}" in
    "${bundle_root}" | "${bundle_root}"/*) ;;
    *) echo "${source_path}: ${description} escapes the application bundle" >>"${errors_file}" ;;
    esac
}

expected_qt_version="$(sed -n 's/^QT_VERSION=//p' _developer/qt/qt_pin.env)"
qtcore_info="${frameworks_path}/QtCore.framework/Resources/Info.plist"
if [ -z "${expected_qt_version}" ] || [ ! -f "${qtcore_info}" ]; then
    echo "Missing Qt version pin or bundled QtCore framework metadata" >>"${errors_file}"
else
    bundled_qt_version="$(plutil -extract CFBundleVersion raw -o - "${qtcore_info}")" || {
        echo "Cannot read bundled QtCore CFBundleVersion" >>"${errors_file}"
        bundled_qt_version=""
    }
    if [ "${bundled_qt_version}" != "${expected_qt_version}" ]; then
        echo "Bundled QtCore version ${bundled_qt_version} does not match pinned Qt ${expected_qt_version}" >>"${errors_file}"
    fi
    bundled_qt_short_version="$(plutil -extract CFBundleShortVersionString raw -o - "${qtcore_info}")" || {
        echo "Cannot read bundled QtCore CFBundleShortVersionString" >>"${errors_file}"
        bundled_qt_short_version=""
    }
    if [ "${bundled_qt_short_version}" != "${expected_qt_version%.*}" ]; then
        echo "Bundled QtCore short version ${bundled_qt_short_version} does not match pinned Qt ${expected_qt_version%.*}" >>"${errors_file}"
    fi
fi

expected_macos_version="$(sed -n 's/^QT_MIN_MACOS=//p' _developer/qt/qt_pin.env)"
bundle_macos_version="$(plutil -extract LSMinimumSystemVersion raw -o - "${contents_path}/Info.plist")" || {
    echo "Cannot read the application minimum macOS version" >>"${errors_file}"
    bundle_macos_version=""
}
if [ -z "${expected_macos_version}" ] || [ "${bundle_macos_version}" != "${expected_macos_version}" ]; then
    echo "Application minimum macOS version ${bundle_macos_version} does not match Qt SDK floor ${expected_macos_version}" >>"${errors_file}"
fi

for required_plugin in \
    "${contents_path}/PlugIns/platforms/libqcocoa.dylib" \
    "${contents_path}/PlugIns/multimedia/libdarwinmediaplugin.dylib" \
    "${contents_path}/PlugIns/iconengines/libqsvgicon.dylib" \
    "${contents_path}/PlugIns/sqldrivers/libqsqlite.dylib"; do
    if [ ! -f "${required_plugin}" ]; then
        echo "Missing required Qt plugin: ${required_plugin}" >>"${errors_file}"
    fi
done

if [ ! -d "${frameworks_path}/QtSvg.framework" ]; then
    echo "Missing required Qt framework: ${frameworks_path}/QtSvg.framework" >>"${errors_file}"
fi

while IFS= read -r symlink_path; do
    [ -n "${symlink_path}" ] || continue
    check_bundled_path "${symlink_path}" "${symlink_path}" "symlink target"
done <<EOF
$(find "${contents_path}" -type l)
EOF

while IFS= read -r binary_path; do
    file_description="$(file "${binary_path}")" || {
        echo "${binary_path}: file inspection failed" >>"${errors_file}"
        continue
    }
    if ! printf '%s\n' "${file_description}" | grep -q "Mach-O"; then
        continue
    fi

    architectures="$(lipo -archs "${binary_path}" 2>/dev/null)" || {
        echo "${binary_path}: architecture inspection failed" >>"${errors_file}"
        continue
    }
    if [ "${architectures}" != "arm64" ]; then
        echo "${binary_path}: expected arm64-only binary, found ${architectures}" >>"${errors_file}"
    fi

    minimum_macos="$(vtool -show-build "${binary_path}" 2>/dev/null | awk '$1 == "minos" { print $2; exit }')" || true
    if [ -z "${minimum_macos}" ]; then
        echo "${binary_path}: cannot read minimum macOS version" >>"${errors_file}"
    elif ! awk -v actual="${minimum_macos}" -v allowed="${expected_macos_version}" 'BEGIN {
        split(actual, a, "."); split(allowed, b, ".")
        for (i = 1; i <= 3; i++) {
            if (a[i] + 0 > b[i] + 0) exit 1
            if (a[i] + 0 < b[i] + 0) exit 0
        }
    }'; then
        echo "${binary_path}: requires macOS ${minimum_macos}, above bundle minimum ${expected_macos_version}" >>"${errors_file}"
    fi

    linked_libraries="$(otool -L "${binary_path}")" || {
        echo "${binary_path}: dependency inspection failed" >>"${errors_file}"
        continue
    }
    printf '%s\n' "${linked_libraries}" | awk 'NR > 1 { print $1 }' | while IFS= read -r dependency; do
        case "${dependency}" in
        /System/Library/* | /usr/lib/*)
            ;;
        @loader_path/*)
            relative_path="${dependency#@loader_path/}"
            check_bundled_path "$(dirname "${binary_path}")/${relative_path}" "${binary_path}" "${dependency}"
            ;;
        @executable_path/../Frameworks/*)
            relative_path="${dependency#@executable_path/../Frameworks/}"
            check_bundled_path "${frameworks_path}/${relative_path}" "${binary_path}" "${dependency}"
            ;;
        @rpath/*)
            relative_path="${dependency#@rpath/}"
            check_bundled_path "${frameworks_path}/${relative_path}" "${binary_path}" "${dependency}"
            ;;
        /*)
            echo "${binary_path}: external dependency ${dependency}" >>"${errors_file}"
            ;;
        *)
            echo "${binary_path}: unsupported dependency ${dependency}" >>"${errors_file}"
            ;;
        esac
    done

    install_id="$(otool -D "${binary_path}" 2>/dev/null | tail -n +2 | head -n 1)"
    if [ -n "${install_id}" ]; then
        case "${install_id}" in
        @rpath/* | @loader_path/* | @executable_path/*)
            ;;
        *)
            echo "${binary_path}: external install ID ${install_id}" >>"${errors_file}"
            ;;
        esac
    fi

    load_commands="$(otool -l "${binary_path}")" || {
        echo "${binary_path}: load-command inspection failed" >>"${errors_file}"
        continue
    }
    printf '%s\n' "${load_commands}" | awk '
        $1 == "cmd" && $2 == "LC_RPATH" { reading_rpath = 1; next }
        reading_rpath && $1 == "path" {
            print $2
            reading_rpath = 0
        }
    ' | while IFS= read -r rpath; do
        case "${rpath}" in
        @loader_path/*)
            check_bundled_path "$(dirname "${binary_path}")/${rpath#@loader_path/}" "${binary_path}" "rpath ${rpath}"
            ;;
        @executable_path/*)
            check_bundled_path "${contents_path}/MacOS/${rpath#@executable_path/}" "${binary_path}" "rpath ${rpath}"
            ;;
        *)
            echo "${binary_path}: external rpath ${rpath}" >>"${errors_file}"
            ;;
        esac
    done
done <<EOF
$(find "${contents_path}" -type f)
EOF

if [ -s "${errors_file}" ]; then
    echo "The application bundle is not self-contained:" >&2
    cat "${errors_file}" >&2
    exit 1
fi

echo "Verified self-contained application bundle: ${app_path}"
