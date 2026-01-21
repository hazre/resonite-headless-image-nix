# Resonite Headless Docker Image (Nix)

Reproducible Resonite headless server Docker images using Nix. Downloads Resonite at container runtime.

## Quick Start

```bash
# 1. Build and export image
nix build .#image -o build/result
nix run .#copyToDockerArchive

# 2. Load and run
podman load -i build/resonite-headless.tar
podman run -d \
  -e STEAM_USERNAME=xxx \
  -e STEAM_PASSWORD=xxx \
  -e STEAM_BETA_PASSWORD=xxx \
  -v ./game:/Game \
  -v ./Config.json:/Config/Config.json:ro \
  -v ./logs:/Logs \
  -v ./data:/Data \
  resonite-headless:runtime
```

## Prerequisites

- [Nix](https://nixos.org/download.html) with flakes enabled
- [direnv](https://direnv.net/) (optional, auto-loads dev shell)
- Steam account with Resonite access
- Container runtime (podman/docker)

## Building

```bash
# Build image (outputs to build/ directory)
nix build .#image -o build/result

# Export to tarball
nix run .#copyToDockerArchive

# Load into podman/docker
podman load -i build/resonite-headless.tar
```

## Cross-Architecture

Both `x86_64-linux` and `aarch64-linux` are supported:

```bash
nix run .#packages.x86_64-linux.copyToDockerArchive
nix run .#packages.aarch64-linux.copyToDockerArchive
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
| `/Game` | Persistent game storage - download once, reuse across restarts |
| `/Config` | Configuration files (mount Config.json here) |
| `/Logs` | Log files |

## How It Works

1. On first run, the container downloads Resonite using DepotDownloader
2. The game is stored in `/Game` - mount a persistent volume to avoid re-downloading
3. On subsequent runs, the container checks `Build.version` and skips download if already installed
4. Version can be pinned with `RESONITE_VERSION` or defaults to latest from resonite-version-monitor

## Version Override

```bash
podman run ... -e RESONITE_VERSION=2026.1.16.273 ...
```

## Project Structure

```
├── flake.nix              # Main flake
└── nix/
    ├── images/            # Container image definition
    └── scripts/           # Runtime entrypoint script
```

## License

Nix expressions are MIT licensed. Resonite is proprietary software.
