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
5. After startup reaches `World Running`, the entrypoint sends `log` once to enable continuous log output by default

## Interactive Shell Behavior

- The headless shell stays interactive through container stdin/stdout.
- On first `World Running`, the wrapper sends `log` automatically so logs stream to console.
- Press Enter once to leave log-stream mode and return to interactive command mode.
- You can run `log` again any time to switch back to log-stream mode.

## Pinning a Version

```bash
docker run -e RESONITE_VERSION=2026.1.16.273 ... ghcr.io/hazre/resonite-headless:latest
```

## Multi-Architecture Support

Images are available for both `linux/amd64` and `linux/arm64`. Docker will automatically pull the correct architecture for your system.

## Command Reference

All flake outputs below are available for both `x86_64-linux` and `aarch64-linux`.

Current output names:
- Packages: `nix-lib-docs`, `oci-resonite-headless`, `oci-resonite-headless-copy`, `write-flake`
- Apps: `oci-cve-trivy-resonite-headless`, `oci-cve-grype-resonite-headless`, `oci-sbom-syft-resonite-headless`
- Checks: `check-flake-file`, `oci-dive-resonite-headless`
- Image passthru commands on `oci-resonite-headless`: `copyTo`, `copyToPodman`, `copyToDockerDaemon`, `copyToRegistry`

Build image package:
```bash
nix build .#oci-resonite-headless
```

Build local docs package:
```bash
nix build .#nix-lib-docs
```

Export Docker archive (project helper, removes old tar first):
```bash
nix run .#oci-resonite-headless-copy -- build/resonite-headless.tar
```

Cross-architecture archive export:
```bash
nix run .#packages.x86_64-linux.oci-resonite-headless-copy -- build/resonite-headless-amd64.tar
nix run .#packages.aarch64-linux.oci-resonite-headless-copy -- build/resonite-headless-arm64.tar
```

Load resulting archive:
```bash
docker load -i build/resonite-headless.tar
```

nix-oci default copy commands exposed on the image package:
```bash
# Generic skopeo copy (set destination yourself)
nix run .#oci-resonite-headless.copyTo -- docker://ghcr.io/<user>/resonite-headless:runtime

# Copy to local podman store
nix run .#oci-resonite-headless.copyToPodman

# Copy to local docker daemon
nix run .#oci-resonite-headless.copyToDockerDaemon

# Copy directly to docker/oci registry
nix run .#oci-resonite-headless.copyToRegistry

# Docker archive via default copyTo
nix run .#oci-resonite-headless.copyTo -- docker-archive:build/resonite-headless.tar:resonite-headless:runtime
```

Image analysis and security:
```bash
# Dive layer analysis (check output)
nix build .#checks.x86_64-linux.oci-dive-resonite-headless

# CVE scans (apps)
nix run .#oci-cve-trivy-resonite-headless
nix run .#oci-cve-grype-resonite-headless

# SBOM generation (app)
nix run .#oci-sbom-syft-resonite-headless
```

## Flake Workflow

`flake.nix` is generated. Do not edit it directly.

When you change flake inputs/module wiring:

```bash
# Regenerate flake.nix from flake-file modules
nix run .#write-flake

# Verify generated flake.nix is up to date
nix build .#checks.x86_64-linux.check-flake-file

# Run all checks on all systems
nix flake check --all-systems
```

## Module Layout

Feature modules are under `modules/` and auto-imported via `import-tree`.

Image-related feature files:
- `modules/images/resonite-headless/flake-parts.nix` - base container/output wiring
- `modules/images/resonite-headless/depotdownloader-overlay.nix` - module that adds patched DepotDownloader to image dependencies
- `modules/images/resonite-headless/entrypoint-app.nix` - module that sets the image package/entrypoint to the .NET entrypoint app

Feature-local implementation assets:
- `modules/images/resonite-headless/_image-build/...`

`_image-build` is intentionally prefixed with `_` so `import-tree` does not auto-import it as flake modules.

## License

Nix expressions are MIT licensed. Resonite is proprietary software.
