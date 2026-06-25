#!/bin/bash
set -eu

s=/mnt/vrising/server
p=/mnt/vrising/persistentdata
m=/mnt/vrising/mods
installed_marker="${p}/.installed"

log_steamcmd() { echo "[SteamCMD] $*"; }
log_xvfb()    { echo "[Xvfb] $*"; }
log_wine()    { echo "[Wine] $*"; }
log_server()  { echo "[Server] $*"; }

mkdir -p /tmp/runtime-root /tmp/.X11-unix /root/.steam
chmod 700 /tmp/runtime-root
chmod 1777 /tmp/.X11-unix
export XDG_RUNTIME_DIR=/tmp/runtime-root
export DISPLAY=:0
export WINEPREFIX=/root/.wine
export WINEDEBUG=-all
export WINEDLLOVERRIDES=mscoree=d

should_update=false
if [ ! -f "$installed_marker" ] || [ ! -f "${s}/VRisingServer.exe" ]; then
    should_update=true
fi
if [ -n "${SKIP_UPDATE:-}" ] && [ -f "${s}/VRisingServer.exe" ]; then
    should_update=false
    log_steamcmd "Skipping update (SKIP_UPDATE is set)"
elif [ -n "${SKIP_UPDATE:-}" ] && [ ! -f "${s}/VRisingServer.exe" ]; then
    log_steamcmd "SKIP_UPDATE is set but server files are missing. Forcing update..."
    should_update=true
fi

if [ "$should_update" = true ]; then
    log_steamcmd "Updating V-Rising Dedicated Server files..."
    retries=5
    while ! /usr/bin/steamcmd \
        +@sSteamCmdForcePlatformType windows \
        +force_install_dir "$s" \
        +login anonymous \
        +app_update 1829350 validate \
        +quit; do
        retries=$((retries - 1))
        if [ "$retries" -le 0 ]; then
            log_steamcmd "Failed updating with steamcmd after multiple attempts"
            exit 1
        fi
        log_steamcmd "Update failed, retrying ($retries attempts remaining)..."
    done
    touch "$installed_marker"
    log_steamcmd "Update complete"
else
    log_steamcmd "Skipping update (already installed)"
fi

if ! grep -q -o 'avx[^ ]*' /proc/cpuinfo; then
    unsupported_file="VRisingServer_Data/Plugins/x86_64/lib_burst_generated.dll"
    log_server "AVX or AVX2 not supported; checking if unsupported ${unsupported_file} exists..."
    if [ -f "${s}/${unsupported_file}" ]; then
        log_server "Renaming ${unsupported_file} as attempt to fix issues..."
        mv "${s}/${unsupported_file}" "${s}/${unsupported_file}.bak"
    fi
fi

mkdir -p "$p/Settings"
if [ ! -f "$p/Settings/ServerGameSettings.json" ]; then
    log_server "$p/Settings/ServerGameSettings.json not found. Copying default file..."
    cp "$s/VRisingServer_Data/StreamingAssets/Settings/ServerGameSettings.json" "$p/Settings/"
fi
if [ ! -f "$p/Settings/ServerHostSettings.json" ]; then
    log_server "$p/Settings/ServerHostSettings.json not found. Copying default file..."
    cp "$s/VRisingServer_Data/StreamingAssets/Settings/ServerHostSettings.json" "$p/Settings/"
fi

log_server "Cleaning up old mods (if any)..."
rm -rf "$s/BepInEx"
rm -rf "$s/dotnet"
rm -f "$s/doorstop_config.ini"
rm -f "$s/winhttp.dll"

if [ -n "${ENABLE_MODS:-}" ]; then
    if [ ! -f "$m/winhttp.dll" ] || [ ! -d "$m/BepInEx" ]; then
        log_server "ERROR: ENABLE_MODS is set but ${m} is missing BepInEx."
        log_server "Run: ./scripts/install-mods.sh /path/to/BepInExPack.zip [--profile dev]"
        exit 1
    fi
    log_server "Setting up mods..."
    cp -r "$m/BepInEx" "$s/BepInEx"
    cp -r "$m/dotnet" "$s/dotnet"
    cp "$m/doorstop_config.ini" "$s/doorstop_config.ini"
    cp "$m/winhttp.dll" "$s/winhttp.dll"
fi

rm -f /tmp/.X11-unix/X0 /tmp/.X0-lock

log_xvfb "Starting virtual display on ${DISPLAY}"
Xvfb :0 -screen 0 1024x768x16 &
XVFB_PID=$!

for _ in $(seq 1 100); do
    if [ -S /tmp/.X11-unix/X0 ]; then
        break
    fi
    if ! kill -0 "$XVFB_PID" 2>/dev/null; then
        log_xvfb "Process died before display was ready"
        exit 1
    fi
    sleep 0.1
done

if [ ! -S /tmp/.X11-unix/X0 ]; then
    log_xvfb "Socket /tmp/.X11-unix/X0 not ready after timeout"
    exit 1
fi
log_xvfb "Display ready"

if [ ! -d "$WINEPREFIX" ]; then
    log_wine "Initializing Wine prefix at ${WINEPREFIX}..."
    wineboot --init
    log_wine "Wine prefix initialized"
else
    log_wine "Using existing prefix at ${WINEPREFIX}"
fi

if [ -n "${ENABLE_MODS:-}" ]; then
    log_wine "Configuring Wine for BepInEx (winhttp native override)"
    wine reg add 'HKCU\Software\Wine\DllOverrides' /v winhttp /t REG_SZ /d native,builtin /f >/dev/null
fi

if ! ldconfig -p 2>/dev/null | grep -q 'libvulkan.so.1'; then
    export LIBGL_ALWAYS_SOFTWARE=1
    log_wine "libvulkan.so.1 not found; forcing software rendering"
fi

log_server "Starting V Rising Dedicated Server (name: ${SERVERNAME:-vrising-dedicated})..."
cd "$s"
if [ -n "${ENABLE_MODS:-}" ]; then
    log_wine "Launching with BepInEx (winhttp=n,b override)"
    exec env WINEDLLOVERRIDES="mscoree=d,winhttp=n,b" wine VRisingServer.exe \
        -persistentDataPath "$p" \
        -logFile "$p/$(date +%Y%m%d-%H%M)-VRisingServer.log"
fi
exec wine VRisingServer.exe \
    -persistentDataPath "$p" \
    -logFile "$p/$(date +%Y%m%d-%H%M)-VRisingServer.log"
