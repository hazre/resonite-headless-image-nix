{ inputs, ... }:
{
  imports = [ inputs.flake-file.flakeModules.dendritic ];

  systems = [
    "x86_64-linux"
    "aarch64-linux"
  ];

  flake-file = {
    description = "Resonite Headless Docker Images built with Nix";

    nixConfig = {
      extra-substituters = [ "https://resonite-headless.cachix.org" ];
      extra-trusted-public-keys = [
        "resonite-headless.cachix.org-1:qiHbubszcmOC4XfIF/DAMkD2JZpO0ZMkywqtRtcK1oU="
      ];
    };

    inputs = {
      flake-file.url = "github:vic/flake-file";
      nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
      systems.url = "github:nix-systems/default";
    };
  };
}
