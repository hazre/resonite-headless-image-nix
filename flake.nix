{
  description = "Resonite Headless Docker Images built with Nix";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    nix2container = {
      url = "github:nlewo/nix2container";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    steam-fetcher = {
      url = "github:aidalgol/nix-steam-fetcher";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      nix2container,
      steam-fetcher,
    }:
    let
      # Support both x86_64 and ARM64
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f system);

      # Load manifest data (fetches from resonite-version-monitor, uses local hashes)
      manifestData = import ./nix/lib/manifest-loader.nix {
        inherit (nixpkgs) lib;
        hashesPath = ./hashes.json;
      };

      # Create nixpkgs instance with overlays for each system
      nixpkgsFor = forAllSystems (
        system:
        import nixpkgs {
          inherit system;
          config.allowUnfree = true;
          overlays = [
            steam-fetcher.overlay
            (import ./nix/overlays/steam-fetcher-arm64.nix)
          ];
        }
      );
    in
    {
      # Overlays for use in other flakes
      overlays = {
        default = import ./nix/overlays/default.nix;
        steam-fetcher-arm64 = import ./nix/overlays/steam-fetcher-arm64.nix;
      };

      # Packages indexed by target architecture
      # Cross-building is automatic - builds run on current system, target the specified arch
      packages =
        let
          # Always use x86_64-linux for building (most common case)
          # This enables cross-building without emulation
          buildSystem = "x86_64-linux";
          pkgs = nixpkgsFor.${buildSystem};
          n2c = nix2container.packages.${buildSystem}.nix2container;

          mkPackages =
            targetSystem:
            let
              buildInfo = manifestData.getBuildInfo targetSystem;

              resonite-headless = pkgs.callPackage ./nix/packages/resonite-headless.nix {
                inherit buildInfo targetSystem;
              };

              resonite-image = import ./nix/images/default.nix {
                inherit pkgs n2c resonite-headless;
                inherit (buildInfo) version timestamp;
              };
            in
            {
              inherit resonite-headless;
              inherit (resonite-image) image copyToDockerArchive;
              default = resonite-image.image;
            };
        in
        {
          x86_64-linux = mkPackages "x86_64-linux";
          aarch64-linux = mkPackages "aarch64-linux";
        };

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
              dive # Container image analysis tool
              skopeo # OCI image operations
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
