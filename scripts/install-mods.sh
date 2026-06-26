#!/bin/bash
# Install BepInEx pack into a mods volume from a Thunderstore/r2modman zip.
set -eu

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE="${VRISING_PROFILE:-prod}"
ZIP=""

usage() {
    cat <<EOF
Usage: $(basename "$0") [path-to-BepInExPack.zip] [--profile dev|prod]

Installs BepInEx into the mods volume and ensures the Docker image is available.

Profiles:
  prod (default)  ${REPO_ROOT}/mods       + root docker-compose.yml
  dev             ${REPO_ROOT}/dev/mods   + dev/docker-compose.yml

Environment overrides:
  VRISING_PROFILE=dev|prod
  MODS_DIR=/custom/path/to/mods
EOF
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --profile)
            PROFILE="${2:?profile required}"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            ZIP="$1"
            shift
            ;;
    esac
done

case "$PROFILE" in
    dev)
        MODS_DIR="${MODS_DIR:-${REPO_ROOT}/dev/mods}"
        COMPOSE_FILE="${REPO_ROOT}/dev/docker-compose.yml"
        IMAGE="scheissegalo/vrising:dev"
        ;;
    prod)
        MODS_DIR="${MODS_DIR:-${REPO_ROOT}/mods}"
        COMPOSE_FILE="${REPO_ROOT}/docker-compose.yml"
        IMAGE="scheissegalo/vrising:latest"
        ;;
    *)
        echo "Unknown profile: $PROFILE (use dev or prod)" >&2
        exit 1
        ;;
esac

ZIP="${ZIP:-${HOME}/Downloads/BepInEx-BepInExPack_V_Rising-1.733.2.zip}"

if [ ! -f "$ZIP" ]; then
    usage >&2
    echo >&2
    echo "Zip not found: $ZIP" >&2
    exit 1
fi

mkdir -p "$MODS_DIR"

if [ "$PROFILE" = dev ]; then
    echo "[install-mods] Building image from ${COMPOSE_FILE}..."
    docker compose -f "$COMPOSE_FILE" build
else
    echo "[install-mods] Pulling ${IMAGE}..."
    docker pull "$IMAGE"
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

unzip -q "$ZIP" -d "$TMP"
SRC="$TMP/BepInExPack_V_Rising"
if [ ! -d "$SRC" ]; then
    echo "Unexpected zip layout (expected BepInExPack_V_Rising/ at top level)" >&2
    exit 1
fi

echo "[install-mods] Installing into ${MODS_DIR}..."
docker run --rm --entrypoint bash \
    -v "${MODS_DIR}:/mods" \
    -v "${SRC}:/src:ro" \
    "${IMAGE}" \
    -c 'rm -rf /mods/* && cp -a /src/BepInEx /src/dotnet /src/doorstop_config.ini /src/winhttp.dll /mods/'

docker run --rm --entrypoint bash \
    -v "${MODS_DIR}:/mods" \
    "${IMAGE}" \
    -c "sed -i '/\[Logging.Console\]/,/^\[/ s/^Enabled = true/Enabled = false/' /mods/BepInEx/config/BepInEx.cfg"

echo "[install-mods] Done."
echo "  Mods dir:  ${MODS_DIR}"
echo "  Profile:   ${PROFILE}"
echo "  Next:      add plugin DLLs to ${MODS_DIR}/BepInEx/plugins/ if needed"
if [ "$PROFILE" = dev ]; then
    echo "  Start:     cd dev && docker compose up -d --build"
else
    echo "  Start:     docker compose up -d   (set ENABLE_MODS: 1 in compose first)"
fi
