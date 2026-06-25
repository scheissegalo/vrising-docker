# Deploying on a new server

Everything needed to run is in this repo. Game files, saves, and mods are **not** committed — you create them on each host.

## Requirements

- Linux host with Docker and Docker Compose v2
- UDP ports open in firewall (9876/9877 for local/dev, 27017/27018 for public listing)
- ~4 GB disk for the server download + saves

## Option A — Production server (root compose)

For a dedicated host with Steam browser ports (27017/27018):

```bash
git clone <your-repo-url> vrising-docker
cd vrising-docker

# Build and start (first run downloads ~2 GB via SteamCMD)
docker compose up -d --build

# Follow startup
docker compose logs -f
```

First boot creates:

- `server/` — game install (SteamCMD)
- `data/` — saves and `Settings/ServerHostSettings.json`

Configure the server in `data/Settings/`, then `docker compose restart`.

### Production with mods

1. Uncomment `ENABLE_MODS: 1` in [`docker-compose.yml`](docker-compose.yml).

2. Install BepInEx and add plugins:

```bash
./scripts/install-mods.sh /path/to/BepInEx-BepInExPack_V_Rising-*.zip
cp /path/to/MyMod.dll mods/BepInEx/plugins/
```

3. Start:

```bash
docker compose up -d --build --force-recreate
```

4. After the first modded boot (~5–10 min extra), persist generated configs:

```bash
docker compose down
./scripts/sync-mod-configs.sh
docker compose up -d
```

5. Verify mods loaded:

```bash
grep 'Loading \[' server/BepInEx/LogOutput.log
tail -f server/BepInEx/LogOutput.log
```

## Option B — Local / dev testing (`dev/` compose)

Same flow, isolated under `dev/` (ports 9876/9877, Direct Connect to `127.0.0.1`):

```bash
git clone <your-repo-url> vrising-docker
cd vrising-docker

./scripts/install-mods.sh /path/to/BepInEx-BepInExPack_V_Rising-*.zip --profile dev
cp /path/to/Bloodcraft.dll dev/mods/BepInEx/plugins/
cp /path/to/VampireCommandFramework.dll dev/mods/BepInEx/plugins/

cd dev
docker compose up -d --build
```

After first modded run:

```bash
docker compose down
../scripts/sync-mod-configs.sh --profile dev
docker compose up -d
```

See [`dev/README.md`](dev/README.md) for dev-specific notes.

## Moving an existing server to a new host

Copy these directories to the new machine (same paths relative to the repo):

| Directory | Contains |
| --------- | -------- |
| `server/` or `dev/server/` | Game install |
| `data/` or `dev/data/` | Saves, settings, `.installed` marker |
| `mods/` or `dev/mods/` | BepInEx pack, plugins, and synced configs |

Then on the new host:

```bash
git clone <your-repo-url> vrising-docker
cd vrising-docker
# restore the three directories above
docker compose up -d --build          # or: cd dev && docker compose up -d --build
```

No SteamCMD re-download if `server/VRisingServer.exe` and `data/.installed` are present.

## Scripts reference

| Script | Purpose |
| ------ | ------- |
| [`scripts/install-mods.sh`](scripts/install-mods.sh) | Install BepInEx pack into `mods/` (use `--profile dev` for dev) |
| [`scripts/sync-mod-configs.sh`](scripts/sync-mod-configs.sh) | Manually copy configs from `server/` to `mods/` (optional — entrypoint does this on startup) |

## Where data is stored

| What | Path (prod) | Path (dev) |
| ---- | ----------- | ---------- |
| World / character saves | `data/Saves/` | `dev/data/Saves/` |
| Server settings | `data/Settings/` | `dev/data/Settings/` |
| Mod DLLs + configs | `mods/BepInEx/` | `dev/mods/BepInEx/` |

These directories are bind-mounted and **survive** `docker compose down`. They are gitignored but remain on the host disk.

Do **not** use `docker compose down -v` unless you intend to wipe data (not applicable to bind mounts, but avoid destructive cleanup of these folders).

Mod configs generated at runtime are auto-synced from `server/BepInEx/config/` → `mods/BepInEx/config/` on each container start when `ENABLE_MODS` is set.


| Symptom | Check |
| ------- | ----- |
| Can't connect locally | Dev uses port **9876** — Direct Connect `127.0.0.1` with no port |
| `ENABLE_MODS` but no BepInEx log | Run `./scripts/install-mods.sh` first |
| Mod configs reset on restart | Run `./scripts/sync-mod-configs.sh` after first modded boot |
| SteamCMD on every restart | Ensure `data/.installed` exists and `server/VRisingServer.exe` is present |
