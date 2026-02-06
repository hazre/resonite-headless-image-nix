{ ... }:
{
  flake-file.inputs.resonitedownloader = {
    url = "github:hazre/ResoniteDownloader";
    inputs.nixpkgs.follows = "nixpkgs";
  };
}
