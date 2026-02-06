{ inputs, ... }:
{
  perSystem =
    { pkgs, system, ... }:
    let
      resoniteDownloaderPkg = inputs.resonitedownloader.packages.${system}.default;
    in
    {
      devShells.default = pkgs.mkShell {
        name = "resonite-headless-dev";

        packages = with pkgs; [
          jq
          resoniteDownloaderPkg
          depotdownloader
          nixfmt-tree
          dive
          skopeo
          dotnetCorePackages.runtime_10_0
        ];

        shellHook = ''
          echo "Resonite Headless Development Shell"
          echo "See README.md for usage instructions."
        '';
      };
    };
}
