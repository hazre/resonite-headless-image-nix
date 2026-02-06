{ inputs, lib, ... }:
{
  flake-file.inputs.nix-oci = {
    url = "github:Dauliac/nix-oci";
    inputs.flake-parts.follows = "flake-parts";
  };

  imports = lib.optionals (inputs ? nix-oci) [
    inputs.nix-oci.inputs.nix-lib.flakeModules.default
    (import "${inputs.nix-oci.outPath}/nix/modules")
  ];

  perSystem = lib.mkIf (inputs ? nix-oci) (
    { system, ... }:
    {
      oci.packages = {
        nix2container = inputs.nix-oci.inputs.nix2container.packages.${system}.nix2container;
        skopeo = inputs.nix-oci.inputs.nix2container.packages.${system}.skopeo-nix2container;
      };
    }
  );

  oci = {
    enabled = true;
    enableFlakeOutputs = true;
    enableDevShell = false;
  };
}
