{ inputs, ... }:
{
  perSystem =
    { config, pkgs, system, ... }:
    let
      imageName = "resonite-headless";
      imageTag = "runtime";
      ociImage = config.oci.internal.OCIs.${imageName};

      resoniteDownloaderPkg = inputs.resonitedownloader.packages.${system}.default;

      nativeLibs = with pkgs; [
        bzip2
        libpng
        zlib
      ];

      tmpDir = pkgs.runCommand "tmp-dir" { } ''
        mkdir -p $out/tmp
        chmod 1777 $out/tmp
      '';

      copyHelper = pkgs.writeShellScriptBin "oci-${imageName}-copy" ''
        set -euo pipefail

        output_path="''${1:-build/${imageName}.tar}"
        mkdir -p "$(dirname "$output_path")"
        rm -f "$output_path"
        exec ${ociImage.copyTo}/bin/copy-to "docker-archive:$output_path:${imageName}:${imageTag}"
      '';
    in
    {
      oci.containers.${imageName} = {
        name = imageName;
        tag = imageTag;
        isRoot = false;
        test.dive.enabled = true;
        cve.trivy.enabled = true;
        cve.grype.enabled = true;
        sbom.syft.enabled = true;
        dependencies = [
          resoniteDownloaderPkg
          pkgs.cacert
          pkgs.dotnetCorePackages.runtime_10_0
          tmpDir
        ] ++ nativeLibs;
      };

      packages = {
        "oci-${imageName}-copy" = copyHelper;
      };
    };
}
