# Resonite Headless Docker Image (Nix)

Reproducible Resonite headless server Docker images using Nix.

## Quick Start

```bash
# 1. Configure Steam credentials
cp .env.example .env
# Edit .env with your credentials

# 2. Build and export image (skip source if using direnv)
source .env
nix run .#copyToDockerArchive --impure

# 3. Load and run
podman load -i build/resonite-headless.tar
podman run -d \
  -v ./Config.json:/Config/Config.json:ro \
  -v ./logs:/Logs \
  -v ./data:/Data \
  resonite-headless:latest
```

## Prerequisites

- [Nix](https://nixos.org/download.html) with flakes enabled
- [direnv](https://direnv.net/) (optional, auto-loads `.env` and dev shell)
- Steam account with Resonite access
- Container runtime (podman/docker)

## Building

```bash
# Build image (outputs to build/ directory)
nix build .#image --impure -o build/result

# Export to tarball
nix run .#copyToDockerArchive --impure

# Load into podman/docker
podman load -i build/resonite-headless.tar
```

## Cross-Architecture

Both `x86_64-linux` and `aarch64-linux` are supported:

```bash
nix run .#packages.x86_64-linux.copyToDockerArchive --impure
nix run .#packages.aarch64-linux.copyToDockerArchive --impure
```

## Updating

Version info is fetched automatically from [resonite-version-monitor](https://github.com/resonite-love/resonite-version-monitor). When a new version is available:

```bash
# 1. Build (will fail with hash mismatch)
nix build .#resonite-headless --impure 2>&1 | grep "got:"

# 2. Add the hash to hashes.json
# { "2026.1.17.100": "sha256-..." }

# 3. Rebuild
nix build .#image --impure
```

## Building Older Versions

All versions tracked by resonite-version-monitor are available:

```bash
RESONITE_VERSION=2026.1.16.273 nix build .#image --impure
```

Note: You need a hash entry in `hashes.json` for each version you want to build.

## Environment Variables

| Variable | Description |
|----------|-------------|
| `STEAM_USERNAME` | Steam account username |
| `STEAM_PASSWORD` | Steam account password |
| `STEAM_BETA_PASSWORD` | Beta password from `/headlessCode` in Resonite |
| `RESONITE_VERSION` | Build a specific version (default: latest) |

## Project Structure

```
├── flake.nix              # Main flake
├── hashes.json            # NAR hashes for each version
├── scripts/               # Utility scripts
└── nix/
    ├── packages/          # Resonite headless package
    ├── images/            # Container image definition
    ├── lib/               # Manifest loader
    └── overlays/          # Nixpkgs overlays
```

## License

Nix expressions are MIT licensed. Resonite is proprietary software.
