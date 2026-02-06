# Resonite Headless Entrypoint
# Simple C# wrapper that downloads Resonite and launches the server
{ pkgs }:

pkgs.buildDotnetModule {
  pname = "resonite-entrypoint";
  version = "1.0.0";

  src = ./.;

  projectFile = "Entrypoint.csproj";

  dotnet-sdk = pkgs.dotnetCorePackages.sdk_10_0;
  dotnet-runtime = pkgs.dotnetCorePackages.runtime_10_0;

  executables = [ "Entrypoint" ];

  meta = {
    description = "Resonite Headless Server entrypoint";
    platforms = pkgs.lib.platforms.linux;
  };
}
