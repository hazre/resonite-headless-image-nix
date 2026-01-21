# Resonite Headless Entrypoint
# Simple C# wrapper that downloads Resonite and launches the server
{ pkgs }:

pkgs.buildDotnetModule {
  pname = "resonite-entrypoint";
  version = "1.0.0";

  src = ./.;

  projectFile = "Entrypoint.csproj";
  nugetDeps = ./deps.nix;

  dotnet-sdk = pkgs.dotnet-sdk_10;
  dotnet-runtime = pkgs.dotnet-runtime_10;

  executables = [ "Entrypoint" ];

  meta = {
    description = "Resonite Headless Server entrypoint";
    platforms = pkgs.lib.platforms.linux;
  };
}
