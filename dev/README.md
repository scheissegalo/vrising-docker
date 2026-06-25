# Local dev / testing

Run a local server from this directory so game files and saves stay under `dev/` and are not committed.

## Quick start

```bash
cd dev
docker compose up --build
```

First start downloads ~2 GB via SteamCMD and can take several minutes. Wait until the server log shows:

```
[Server] Startup Completed - Disabling Scene Loading Systems
```

## Connect from the game

1. **Online Play → Show All Servers → Direct Connect**
2. Enter **`127.0.0.1`** (no port needed)

Dev uses the default game ports **9876/9877**, matching the original repo. The V Rising client assumes port 9876 when you only enter an IP.

3. Wait for world load on first connect (can take a minute after server startup completes).

## Mods (BepInEx)

`ENABLE_MODS: 1` is already set in `docker-compose.yml`. Install the BepInEx pack into `mods/`:

```bash
./install-mods.sh
# or: ./install-mods.sh /path/to/BepInEx-BepInExPack_V_Rising-*.zip
```

Then restart:

```bash
docker compose up --build --force-recreate
```

Modded startup takes several extra minutes. Check BepInEx loaded:

```bash
tail -f server/BepInEx/LogOutput.log
```

Look for `Chainloader` startup messages. The pack only provides the loader — add plugins under `mods/BepInEx/plugins/` before restart if needed.

## Useful commands

```bash
docker compose up --build          # foreground, rebuild image
docker compose up -d --build       # detached
docker compose logs -f             # follow logs
docker compose down                # stop
docker compose restart             # restart (skips SteamCMD if already installed)
```

## Ports

| Port | Purpose        | Dev compose |
| ---- | -------------- | ----------- |
| 9876 | Game (UDP)     | default, use for local Direct Connect |
| 9877 | Query (UDP)    | default     |
| 27017–27050 | Game/query | Steam server browser only |

For public listing, use the root `docker-compose.yml` with ports in the Steam range and enable `"ListOnSteam"` / `"ListOnEOS"` in `ServerHostSettings.json`.

## Layout

| Path    | Purpose                          |
| ------- | -------------------------------- |
| `server/` | SteamCMD install (gitignored)  |
| `data/`   | Saves, settings, `.installed`  |
| `mods/`   | Optional mod files             |

To wipe and reinstall: `docker compose down` then remove `server/`, `data/`, and `mods/`.
