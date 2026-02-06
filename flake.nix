# DO-NOT-EDIT. This file was auto-generated using github:vic/flake-file.
# Use `nix run .#write-flake` to regenerate it.
{
  description = "Resonite Headless Docker Images built with Nix";

  outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } (inputs.import-tree ./modules);

  nixConfig = {
    extra-substituters = [ "https://resonite-headless.cachix.org" ];
    extra-trusted-public-keys = [
      "resonite-headless.cachix.org-1:qiHbubszcmOC4XfIF/DAMkD2JZpO0ZMkywqtRtcK1oU="
    ];
  };

  inputs = {
    flake-file.url = "github:vic/flake-file";
    flake-parts = {
      inputs.nixpkgs-lib.follows = "nixpkgs-lib";
      url = "github:hercules-ci/flake-parts";
    };
    import-tree.url = "github:vic/import-tree";
    nix-oci = {
      inputs.flake-parts.follows = "flake-parts";
      url = "github:Dauliac/nix-oci";
    };
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-lib.follows = "nixpkgs";
    resonitedownloader = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:hazre/ResoniteDownloader";
    };
    systems.url = "github:nix-systems/default";
  };

}
