#!/bin/bash
# Install BepInEx pack into dev/mods from a Thunderstore/r2modman zip.
set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODS_DIR="${SCRIPT_DIR}/mods"
ZIP="${1:-${HOME}/Downloads/BepInEx-BepInExPack_V_Rising-1.733.2.zip}"

if [ ! -f "$ZIP" ]; then
    echo "Usage: $0 [path-to-BepInExPack.zip]"
    echo "Zip not found: $ZIP"
    exit 1
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

unzip -q "$ZIP" -d "$TMP"
SRC="$TMP/BepInExPack_V_Rising"
if [ ! -d "$SRC" ]; then
    echo "Unexpected zip layout (expected BepInExPack_V_Rising/ at top level)"
    exit 1
fi

docker run --rm --entrypoint bash \
    -v "${MODS_DIR}:/mods" \
    -v "${SRC}:/src:ro" \
    andrewsav/vrising:dev \
    -c 'rm -rf /mods/* && cp -a /src/BepInEx /src/dotnet /src/doorstop_config.ini /src/winhttp.dll /mods/'

# Disable console logging (recommended for Docker — see main README)
docker run --rm --entrypoint bash \
    -v "${MODS_DIR}:/mods" \
    andrewsav/vrising:dev \
    -c "sed -i '/\[Logging.Console\]/,/^\[/ s/^Enabled = true/Enabled = false/' /mods/BepInEx/config/BepInEx.cfg"

echo "Installed BepInEx into ${MODS_DIR}"
echo "Start with: cd dev && docker compose up --build"
echo "ENABLE_MODS must be set in docker-compose.yml (already enabled for dev)."
