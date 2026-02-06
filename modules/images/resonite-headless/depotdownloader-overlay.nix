{
  perSystem =
    { lib, pkgs, ... }:
    let
      depotdownloader = import ./_image-build/depotdownloader-overlay.nix { inherit pkgs; };
    in
    {
      oci.containers.resonite-headless.dependencies = lib.mkAfter [ depotdownloader ];
    };
}
