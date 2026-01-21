# Resonite Headless Docker Image
#
# Simple layer strategy - all deps in one layer to avoid duplication.
# The config references create implicit dependencies, so we bundle everything
# together to prevent the same packages appearing in multiple layers.
{
  pkgs,
  n2c,
  resonite-headless,
  version,
  timestamp,
}:

let
  inherit (pkgs) lib;

  # Native libs required by Resonite that aren't bundled
  # Note: Resonite bundles its own libfreetype6.so, libopus.so, and brolib
  nativeLibs = with pkgs; [
    fontconfig
    icu
    openssl
    zlib
  ];

  # Entrypoint script - uses env vars set in container config
  entrypoint = pkgs.writeShellScriptBin "resonite-headless" ''
    set -euo pipefail
    export DOTNET_EnableDiagnostics=0

    CONFIG_PATH="''${RESONITE_CONFIG:-/Config/Config.json}"
    LOGS_PATH="''${RESONITE_LOGS:-/Logs}"

    echo "Starting Resonite Headless Server..."
    cd "$RESONITE_PATH"

    exec "$DOTNET_ROOT/bin/dotnet" \
      "$RESONITE_PATH/Resonite.dll" \
      -HeadlessConfig "$CONFIG_PATH" \
      -Logs "$LOGS_PATH" \
      "$@"
  '';

  # All dependencies in a single layer to avoid duplication from config references
  allDeps = [
    pkgs.cacert
    pkgs.dotnet-runtime_10
    resonite-headless
    entrypoint
  ]
  ++ nativeLibs;

  imageName = "resonite-headless";
  imageTag = version;

  image = n2c.buildImage {
    name = imageName;
    tag = imageTag;

    # Use version's release timestamp for reproducible builds
    # Fall back to epoch if timestamp is missing (new versions before hash update)
    created = if timestamp != null && timestamp != "" then timestamp else "1970-01-01T00:00:00Z";

    # Single layer with all dependencies
    layers = [
      (n2c.buildLayer { deps = allDeps; })
    ];

    config = {
      Entrypoint = [ "${entrypoint}/bin/resonite-headless" ];
      Env = [
        "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
        "DOTNET_ROOT=${pkgs.dotnet-runtime_10}"
        "RESONITE_PATH=${resonite-headless}/resonite/Headless"
        "LD_LIBRARY_PATH=${lib.makeLibraryPath nativeLibs}"
      ];
      Volumes = {
        "/Config" = { };
        "/Logs" = { };
        "/Data" = { };
      };
      Labels = {
        "org.opencontainers.image.title" = "Resonite Headless Server";
        "org.opencontainers.image.description" = "Resonite headless server built with Nix";
        "org.opencontainers.image.version" = version;
      };
    };
  };

  # Convenience script to save image with proper name:tag in the archive
  copyToDockerArchive = pkgs.writeShellScriptBin "copy-to-docker-archive" ''
    set -euo pipefail
    OUTPUT="''${1:-build/${imageName}.tar}"
    mkdir -p "$(dirname "$OUTPUT")"
    # Remove existing file - skopeo can't overwrite docker-archive
    rm -f "$OUTPUT"
    echo "Saving image as ${imageName}:${imageTag} to $OUTPUT..."
    ${image.copyTo}/bin/copy-to docker-archive:"$OUTPUT":${imageName}:${imageTag}
    echo "Done. Load with: podman load -i $OUTPUT"
  '';

in
{
  inherit
    image
    imageName
    imageTag
    copyToDockerArchive
    ;
}
