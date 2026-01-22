{
  description = "Resonite Headless Docker Images built with Nix";

  nixConfig = {
    extra-substituters = [ "https://resonite-headless.cachix.org" ];
    extra-trusted-public-keys = [
      "resonite-headless.cachix.org-1:qiHbubszcmOC4XfIF/DAMkD2JZpO0ZMkywqtRtcK1oU="
    ];
  };

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    nix2container = {
      url = "github:nlewo/nix2container";
      inputs.nixpkgs.follows = "nixpkgs";
    };

  };

  outputs =
    {
      self,
      nixpkgs,
      nix2container,
    }:
    let
      # Support both x86_64 and ARM64
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f system);

      # Create nixpkgs instance for each system
      nixpkgsFor = forAllSystems (
        system:
        import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        }
      );
    in
    {
      # Packages indexed by system
      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgsFor.${system};
          n2c = nix2container.packages.${system}.nix2container;
          skopeo-nix2container = nix2container.packages.${system}.skopeo-nix2container;

          resonite-image = import ./nix/images/default.nix {
            inherit
              pkgs
              n2c
              skopeo-nix2container
              ;
          };
        in
        {
          inherit (resonite-image)
            image
            copyToDockerArchive
            copyToPodman
            copyTo
            ;
          default = resonite-image.image;
        }
      );

      # Development shells
      devShells = forAllSystems (
        system:
        let
          pkgs = nixpkgsFor.${system};
        in
        {
          default = pkgs.mkShell {
            name = "resonite-headless-dev";

            packages = with pkgs; [
              jq
              depotdownloader
              nixfmt-tree
              dive
              skopeo
              dotnet-sdk_10
            ];

            shellHook = ''
              echo "Resonite Headless Development Shell"
              echo "See README.md for usage instructions."
            '';
          };
        }
      );

      # Formatter
      formatter = forAllSystems (system: nixpkgsFor.${system}.nixfmt-tree);

    };
}
