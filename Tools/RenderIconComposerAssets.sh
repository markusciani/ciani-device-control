#!/bin/sh
set -eu

ICON_TOOL="/Applications/Icon Composer.app/Contents/Executables/ictool"
ICON_SOURCE="${SRCROOT}/iOS/AppIcon.icon"
ICON_OUTPUT="${SRCROOT}/iOS/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"

if [ ! -x "${ICON_TOOL}" ] || [ ! -d "${ICON_SOURCE}" ]; then
    echo "warning: Icon Composer renderer is unavailable; using the last generated app icon."
    exit 0
fi

ICON_TEMP="$(mktemp -t cdc-app-icon).png"
trap 'rm -f "${ICON_TEMP}"' EXIT

"${ICON_TOOL}" "${ICON_SOURCE}" --export-image --output-file "${ICON_TEMP}" \
    --platform iOS --rendition Default --width 1024 --height 1024 --scale 1 >/dev/null

if ! cmp -s "${ICON_TEMP}" "${ICON_OUTPUT}"; then
    cp "${ICON_TEMP}" "${ICON_OUTPUT}"
fi
