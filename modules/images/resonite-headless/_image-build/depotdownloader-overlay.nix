# DepotDownloader with .NET 10 runtime to share with Resonite
#
# Patches DepotDownloader.csproj to target net10.0 instead of net9.0,
# avoiding two separate .NET runtimes in the container image.
{
  pkgs,
}:

(pkgs.depotdownloader.override {
  dotnetCorePackages = pkgs.dotnetCorePackages // {
    runtime_9_0 = pkgs.dotnetCorePackages.runtime_10_0;
    sdk_9_0 = pkgs.dotnetCorePackages.sdk_10_0;
  };
}).overrideAttrs (old: {
  postPatch = (old.postPatch or "") + ''
    substituteInPlace DepotDownloader/DepotDownloader.csproj \
      --replace-fail '<TargetFramework>net9.0</TargetFramework>' '<TargetFramework>net10.0</TargetFramework>'
    rm -f global.json
  '';
})
