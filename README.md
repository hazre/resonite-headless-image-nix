# Resonite Headless Docker Image

Reproducible Resonite headless server Docker images built with Nix. Downloads Resonite at container startup.

## Quick Start

```bash
# Pull and run
docker run -d \
  -e STEAM_USERNAME=your_username \
  -e STEAM_PASSWORD=your_password \
  -e STEAM_BETA_PASSWORD=your_beta_code \
  -v ./game:/Game \
  -v ./Config.json:/Config/Config.json:ro \
  -v ./logs:/Logs \
  ghcr.io/hazre/resonite-headless:latest
```

## Prerequisites

- Steam account with Resonite access
- Beta password from `/headlessCode` in Resonite
- Container runtime (Docker or Podman)

## Using with Docker Compose

```yaml
services:
  resonite:
    image: ghcr.io/hazre/resonite-headless:latest
    environment:
      - STEAM_USERNAME=${STEAM_USERNAME}
      - STEAM_PASSWORD=${STEAM_PASSWORD}
      - STEAM_BETA_PASSWORD=${STEAM_BETA_PASSWORD}
    volumes:
      - ./game:/Game
      - ./Config.json:/Config/Config.json:ro
      - ./logs:/Logs
```

Create a `.env` file:
```bash
STEAM_USERNAME=your_username
STEAM_PASSWORD=your_password
STEAM_BETA_PASSWORD=your_beta_code
```

Then run:
```bash
docker compose up -d
```

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `STEAM_USERNAME` | Yes | Steam account username |
| `STEAM_PASSWORD` | Yes | Steam account password |
| `STEAM_BETA_PASSWORD` | Yes | Beta password from `/headlessCode` in Resonite |
| `RESONITE_VERSION` | No | Specific version to download (default: latest) |
| `RESONITE_CONFIG` | No | Config file path (default: `/Config/Config.json`) |
| `RESONITE_LOGS` | No | Logs directory (default: `/Logs`) |
| `RESONITE_GAME_DIR` | No | Game directory (default: `/Game`) |

## Volumes

| Path | Description |
|------|-------------|
| `/Game` | Persistent game storage - mount to avoid re-downloading on restart |
| `/Config` | Configuration files (mount your Config.json here) |
| `/Logs` | Log files |

## How It Works

1. On first run, the container downloads Resonite using DepotDownloader
2. The game is stored in `/Game` - mount a persistent volume to avoid re-downloading
3. On subsequent runs, the container checks the installed version and skips download if up-to-date
4. Version can be pinned with `RESONITE_VERSION` or defaults to latest

## Pinning a Version

```bash
docker run -e RESONITE_VERSION=2026.1.16.273 ... ghcr.io/hazre/resonite-headless:latest
```

## Multi-Architecture Support

Images are available for both `linux/amd64` and `linux/arm64`. Docker will automatically pull the correct architecture for your system.

## Building from Source

If you want to build the image yourself:

```bash
# Prerequisites: Nix with flakes enabled

# Build and export image
nix build .#image -o build/result
nix run .#copyToDockerArchive

# Load into docker/podman
docker load -i build/resonite-headless.tar
```

Cross-architecture builds:
```bash
nix run .#packages.x86_64-linux.copyToDockerArchive
nix run .#packages.aarch64-linux.copyToDockerArchive
```

## License

Nix expressions are MIT licensed. Resonite is proprietary software.
