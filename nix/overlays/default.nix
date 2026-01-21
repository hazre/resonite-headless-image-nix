# Default overlay that combines all project overlays
final: prev: {
  # Import steam-fetcher ARM64 overlay
  inherit (import ./steam-fetcher-arm64.nix final prev) fetchSteam;
}
