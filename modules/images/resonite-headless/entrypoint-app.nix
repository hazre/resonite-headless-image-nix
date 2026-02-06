{
  perSystem =
    { lib, pkgs, ... }:
    let
      entrypointApp = import ./_image-build/entrypoint-app { inherit pkgs; };
    in
    {
      oci.containers.resonite-headless = {
        package = lib.mkDefault entrypointApp;
        entrypoint = lib.mkDefault [ "${entrypointApp}/bin/Entrypoint" ];
      };
    };
}
