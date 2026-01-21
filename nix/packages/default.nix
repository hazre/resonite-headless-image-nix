# Package exports
{
  pkgs,
  buildInfo,
}:

{
  resonite-headless = pkgs.callPackage ./resonite-headless.nix { inherit buildInfo; };
}
