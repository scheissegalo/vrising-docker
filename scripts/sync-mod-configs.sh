#!/bin/bash
# Copy generated BepInEx/mod configs from the server volume back to the mods volume.
set -eu

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE="${VRISING_PROFILE:-prod}"

usage() {
    cat <<EOF
Usage: $(basename "$0") [--profile dev|prod]

Copies runtime-generated configs from server/BepInEx/config/ into mods/BepInEx/config/
so they survive container restarts.

Run this after the server has started at least once with mods enabled.
Stop the container first to avoid partial copies.
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
            echo "Unknown argument: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

case "$PROFILE" in
    dev)
        MODS_DIR="${MODS_DIR:-${REPO_ROOT}/dev/mods}"
        SERVER_DIR="${SERVER_DIR:-${REPO_ROOT}/dev/server}"
        ;;
    prod)
        MODS_DIR="${MODS_DIR:-${REPO_ROOT}/mods}"
        SERVER_DIR="${SERVER_DIR:-${REPO_ROOT}/server}"
        ;;
    *)
        echo "Unknown profile: $PROFILE (use dev or prod)" >&2
        exit 1
        ;;
esac

SRC="${SERVER_DIR}/BepInEx/config"
DEST="${MODS_DIR}/BepInEx/config"

if [ ! -d "$SRC" ]; then
    echo "No generated configs found at ${SRC}" >&2
    echo "Start the server with ENABLE_MODS once, then run this again." >&2
    exit 1
fi

mkdir -p "$DEST"
cp -a "${SRC}/." "$DEST/"

echo "[sync-mod-configs] Copied configs:"
echo "  from ${SRC}"
echo "  to   ${DEST}"
echo "Edit files under ${DEST}, then restart the container."
