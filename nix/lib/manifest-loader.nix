# Manifest loader for Resonite headless builds
#
# Fetches version info from resonite-version-monitor, uses local hashes.
#
# Environment variables (require --impure):
#   RESONITE_VERSION - Build a specific version (default: latest)
{
  lib,
  hashesPath,
}:

let
  # Fetch versions.json from resonite-version-monitor
  versionsUrl = "https://raw.githubusercontent.com/resonite-love/resonite-version-monitor/master/data/versions.json";
  versionsJson = builtins.fetchurl versionsUrl;
  versions = builtins.fromJSON (builtins.readFile versionsJson);

  # Get headless branch versions (array, newest last)
  headlessVersions = versions.headless;

  # Build a lookup table by gameVersion
  versionsByGameVersion = builtins.listToAttrs (
    map (v: lib.nameValuePair v.gameVersion v) headlessVersions
  );

  # Latest is the last entry
  latestVersion = (lib.last headlessVersions).gameVersion;

  # Load local hashes
  hashes = builtins.fromJSON (builtins.readFile hashesPath);

  # Allow selecting a specific version via env var
  versionOverride = builtins.getEnv "RESONITE_VERSION";
  selectedVersion = if versionOverride != "" then versionOverride else latestVersion;

  # Get version data
  versionData =
    versionsByGameVersion.${selectedVersion}
      or (throw "Unknown version '${selectedVersion}'. Available: ${lib.concatStringsSep ", " (builtins.attrNames versionsByGameVersion)}");

  # Get local data (may be missing for new versions)
  localData = hashes.${selectedVersion} or null;
  hash =
    if localData != null then
      localData.hash
    else
      builtins.trace "WARNING: No hash for version ${selectedVersion}. Run scripts/update-hashes.sh to fetch it." "";
  localManifestId = if localData != null then localData.manifestId else null;
in
{
  # Version info
  version = selectedVersion;
  latest = latestVersion;
  availableVersions = builtins.attrNames versionsByGameVersion;

  # Get build information for a specific system architecture
  # Note: Resonite uses the same depot (2519832) for all Linux architectures
  getBuildInfo = system: {
    appId = "2519830";
    depotId = "2519832";
    branch = "headless";
    version = selectedVersion;
    # Prefer local manifestId (for offline/pinned use), fall back to remote
    manifestId = if localManifestId != null then localManifestId else versionData.manifestId;
    # Timestamp from resonite-version-monitor (for image created date)
    timestamp = versionData.timestamp;
    inherit hash;
  };
}
