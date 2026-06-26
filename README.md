# V Rising dedicated server (Docker) — Bloodcraft

[![GitHub Actions](https://github.com/scheissegalo/vrising-docker/actions/workflows/main.yml/badge.svg)](https://github.com/scheissegalo/vrising-docker/actions)
[![Docker Image Version (latest semver)](https://img.shields.io/docker/v/scheissegalo/vrising?sort=semver)](https://hub.docker.com/r/scheissegalo/vrising/tags)

Docker image for a **V Rising dedicated server with BepInEx mods**, tuned for running **[Bloodcraft](https://thunderstore.io/c/v-rising/p/Deca/Bloodcraft/)**. The container copies mods from a host `mods/` folder into the game install on each start and **automatically syncs generated mod configs back into `mods/BepInEx/config/`** so Bloodcraft settings and player data survive restarts and image updates.

Pre-built images: [`scheissegalo/vrising`](https://hub.docker.com/r/scheissegalo/vrising) on Docker Hub.

For server settings and `VR_*` environment variables, see the [official V Rising dedicated server instructions](https://github.com/StunlockStudios/vrising-dedicated-server-instructions).

## Quickstart

Requirements: Linux host, Docker, Docker Compose v2, UDP ports open (~4 GB disk for the game download).

### Option A — Docker Hub (recommended for production)

Pull the published image; no local build.

```bash
git clone https://github.com/scheissegalo/vrising-docker.git
cd vrising-docker

# Install BepInEx into mods/ and add Bloodcraft (+ dependencies)
./scripts/install-mods.sh /path/to/BepInEx-BepInExPack_V_Rising-*.zip
cp /path/to/Bloodcraft.dll mods/BepInEx/plugins/
cp /path/to/VampireCommandFramework.dll mods/BepInEx/plugins/

# Uncomment ENABLE_MODS: 1 in docker-compose.yml
docker compose pull
docker compose up -d

docker compose logs -f
```

Or use a minimal compose file without cloning the full repo:

```yaml
services:
  vrising:
    image: scheissegalo/vrising:latest
    container_name: vrising
    restart: unless-stopped
    init: true
    environment:
      ENABLE_MODS: 1
      VR_SERVER_NAME: My Bloodcraft Server
      VR_GAME_PORT: "27017"
      VR_QUERY_PORT: "27018"
    volumes:
      - ./server:/mnt/vrising/server
      - ./data:/mnt/vrising/persistentdata
      - ./mods:/mnt/vrising/mods
    ports:
      - "27017:27017/udp"
      - "27018:27018/udp"
```

```bash
docker compose up -d
```

First boot downloads the server via SteamCMD into `server/` and creates saves/settings in `data/`. Mod configs generated at runtime are copied into `mods/BepInEx/config/` on every container start.

Updates:

```bash
docker compose pull
docker compose up -d
```

### Option B — Build from GitHub

Clone this repo and build the image locally (useful when changing the Dockerfile or before a release is tagged):

```bash
git clone https://github.com/scheissegalo/vrising-docker.git
cd vrising-docker

./scripts/install-mods.sh /path/to/BepInEx-BepInExPack_V_Rising-*.zip
cp /path/to/Bloodcraft.dll mods/BepInEx/plugins/
cp /path/to/VampireCommandFramework.dll mods/BepInEx/plugins/

# Uncomment ENABLE_MODS: 1 and build: . in docker-compose.yml
docker compose up -d --build

docker compose logs -f
```

### Option C — Docker CLI

```bash
mkdir -p server data mods
# populate mods/ first (see Bloodcraft setup below)

docker pull scheissegalo/vrising:latest

docker run -d --name vrising \
  --init \
  --restart unless-stopped \
  -e ENABLE_MODS=1 \
  -e VR_SERVER_NAME="My Bloodcraft Server" \
  -e VR_GAME_PORT=27017 \
  -e VR_QUERY_PORT=27018 \
  -v "$(pwd)/server:/mnt/vrising/server" \
  -v "$(pwd)/data:/mnt/vrising/persistentdata" \
  -v "$(pwd)/mods:/mnt/vrising/mods" \
  -p 27017:27017/udp \
  -p 27018:27018/udp \
  scheissegalo/vrising:latest
```

See **[DEPLOY.md](DEPLOY.md)** for migrating `server/`, `data/`, and `mods/` to another host.

## Bloodcraft setup

1. Install the BepInEx pack into `mods/`:

```bash
./scripts/install-mods.sh /path/to/BepInEx-BepInExPack_V_Rising-*.zip
```

2. Copy plugin DLLs into `mods/BepInEx/plugins/` (Bloodcraft and its dependencies from [Thunderstore](https://thunderstore.io/c/v-rising/p/Deca/Bloodcraft/)).

3. Set `ENABLE_MODS=1` (or `ENABLE_MODS: 1` in compose) and start the container.

4. After the first modded boot (~5–10 min extra), edit configs under `mods/BepInEx/config/` — the entrypoint syncs configs from the game install into that folder on every start, so changes there persist across restarts.

Alternative mod install: export an r2modman profile and use [r2modman-headless](https://github.com/mpawlowski/r2modman-headless) into `./mods` (see [Mods support](#mods-support) below).

## Environment variables

| Variable    | Description                                                  |
| ----------- | ------------------------------------------------------------ |
| ENABLE_MODS | Enables BepInEx; copies `mods/` into the server install and persists configs back to `mods/BepInEx/config/` |
| SKIP_UPDATE | Skips SteamCMD update on startup when server files already exist |
| SERVERNAME  | Optional display name logged at server start (game settings use `VR_*` variables) |

On first start, SteamCMD downloads server files and writes `data/.installed`. Later starts skip the update unless files are missing. `SKIP_UPDATE` also skips when `VRisingServer.exe` is present.

## Local development

For local testing (ports 9876/9877, isolated under `dev/`):

```bash
cd dev
docker compose up --build
```

See [`dev/README.md`](dev/README.md) for connecting from the game client.

## Ports

| Exposed Container port | Type | Default |
| ------------------------ | ------ | --------- |
| 9876                   | UDP  | dev     |
| 9877                   | UDP  | dev     |
| 27017                  | UDP  | production compose |
| 27018                  | UDP  | production compose |

For Steam server browser listing, use ports in **27015–27050** and enable `VR_LIST_ON_STEAM` / `VR_LIST_ON_EOS`.

## Volumes

| Volume             | Container path              | Description                             |
| -------------------- | ----------------------------- | ----------------------------------------- |
| Steam install path | /mnt/vrising/server         | Game files (SteamCMD download) |
| Saves & settings | /mnt/vrising/persistentdata | Server configuration and saves |
| Mods | /mnt/vrising/mods | BepInEx pack, plugins, and **persistent mod configs** (synced on each start) |

## Server list

1. Enable `"ListOnSteam": true` and `"ListOnEOS": true` in settings (both appear required even on Steam).
2. Use ports in the 27015–27050 Steam range.
3. Configure router/firewall for UDP.

## Server configuration

On first start, default settings are copied to `data/Settings/`. Edit `ServerHostSettings.json` there for ports, description, etc. Restart the container to apply changes.

## Mods support

When `ENABLE_MODS` is set, the entrypoint removes old mod files from the game install, **copies configs from `server/BepInEx/config/` into `mods/BepInEx/config/`**, then copies the full mod stack from `mods/` back into the server directory:

- BepInEx (directory)
- dotnet (directory)
- doorstop_config.ini (file)
- winhttp.dll (file)

Layout matches [BepInExPack_V_Rising](https://thunderstore.io/c/v-rising/p/BepInEx/BepInExPack_V_Rising/).

Suggested r2modman workflow:

- Use [r2modman](https://github.com/ebkr/r2modmanPlus) locally to pick mods, export profile as `.rdz`
- On the server, install with [r2modman-headless](https://github.com/mpawlowski/r2modman-headless):

```bash
r2modman-headless --install-dir=./mods \
  --profile-zip vrising-server.r2z \
  --thunderstore-metadata-url=https://thunderstore.io/c/v-rising/api/v1/package/ \
  --work-dir /tmp
```

Set `[Logging.Console] Enabled = false` in `mods/BepInEx/config/BepInEx.cfg`.

Follow [V Rising Mod Discord](https://discord.com/invite/QG2FmueAG9) for modding updates.

## RCON — Optional

Edit `data/Settings/ServerHostSettings.json` and add after `QueryPort`. Expose the port in compose or `docker run`. Use [RCON CLI](https://github.com/gorcon/rcon-cli) to connect.

```json
"Rcon": {
  "Enabled": true,
  "Password": "change me",
  "Port": 25575
},
```

## Credits

- Forked from [AndrewSav/vrising-docker](https://github.com/AndrewSav/vrising-docker), based on [TrueOsiris/docker-vrising](https://github.com/TrueOsiris/docker-vrising)
