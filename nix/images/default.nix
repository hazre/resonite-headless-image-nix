# Resonite Headless Docker Image
#
# Runtime download version - downloads Resonite at container startup.
# Requires Steam credentials via environment variables.
{
  pkgs,
  n2c,
  skopeo-nix2container,
  resoniteDownloaderPkg,
}:

let
  inherit (pkgs) lib;

  # DepotDownloader with .NET 10 runtime (same as Resonite) to reduce image size
  depotdownloader = import ../packages/depotdownloader.nix { inherit pkgs; };

  # C# entrypoint - downloads Resonite and launches the server
  entrypoint = import ../packages/entrypoint { inherit pkgs; };

  # Native libs required by Resonite that aren't bundled
  # These are transitive dependencies of the bundled native libs (e.g. libfreetype6.so)
  nativeLibs = with pkgs; [
    bzip2
    libpng
    zlib
  ];

  # Runtime dependencies
  runtimeDeps = [
    depotdownloader
    resoniteDownloaderPkg
    entrypoint
  ];

  # Create /tmp directory for .NET isolated storage
  tmpDir = pkgs.runCommand "tmp-dir" { } ''
    mkdir -p $out/tmp
  '';


  # All dependencies in a single layer
  allDeps = [
    pkgs.cacert
    pkgs.dotnetCorePackages.runtime_10_0
  ]
  ++ runtimeDeps
  ++ nativeLibs;

  imageName = "resonite-headless";
  imageTag = "runtime";

  image = n2c.buildImage {
    name = imageName;
    tag = imageTag;

    # Use epoch for reproducible builds
    created = "1970-01-01T00:00:00Z";

    # Single layer with all dependencies
    layers = [
      (n2c.buildLayer { deps = allDeps; })
    ];

    # Create /tmp with 1777 permissions
    copyToRoot = [ tmpDir ];
    perms = [
      {
        path = tmpDir;
        regex = ".*";
        mode = "1777";
      }
    ];

    config = {
      Entrypoint = [ "${entrypoint}/bin/Entrypoint" ];
      Env = [
        "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
        "DOTNET_ROOT=${pkgs.dotnetCorePackages.runtime_10_0}"
        "PATH=${lib.makeBinPath runtimeDeps}:${pkgs.dotnetCorePackages.runtime_10_0}/bin"
        "LD_LIBRARY_PATH=${lib.makeLibraryPath nativeLibs}"
        "HOME=/Game"
      ];
      Volumes = {
        "/Game" = { };
        "/Config" = { };
        "/Logs" = { };
      };
      Labels = {
        "org.opencontainers.image.title" = "Resonite Headless Server";
        "org.opencontainers.image.description" = "Resonite headless server (runtime download)";
      };
    };
  };

  # Convenience script to save image with proper name:tag in the archive
  copyToDockerArchive = pkgs.writeShellScriptBin "copy-to-docker-archive" ''
    set -euo pipefail
    OUTPUT="''${1:-build/${imageName}.tar}"
    mkdir -p "$(dirname "$OUTPUT")"
    rm -f "$OUTPUT"
    echo "Saving image as ${imageName}:${imageTag} to $OUTPUT..."
    ${image.copyTo}/bin/copy-to docker-archive:"$OUTPUT":${imageName}:${imageTag}
    echo "Done."
  '';

in
{
  inherit
    image
    imageName
    imageTag
    copyToDockerArchive
    ;
  # Direct copy to local podman storage
  copyToPodman = image.copyToPodman;
  # Generic copy (use with any skopeo destination)
  copyTo = image.copyTo;
}
