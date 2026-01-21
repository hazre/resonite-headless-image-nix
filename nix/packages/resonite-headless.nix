# Resonite Headless Server package
{
  lib,
  stdenv,
  fetchSteam,
  targetSystem ? stdenv.hostPlatform.system,
  buildInfo,
}:

let
  inherit (buildInfo)
    appId
    depotId
    manifestId
    branch
    hash
    version
    ;

  archPatternsToRemove = {
    "x86_64-linux" = "linux-{arm,x86}*";
    "aarch64-linux" = "linux-{x64,x86}*";
  };
in
stdenv.mkDerivation {
  pname = "resonite-headless";
  inherit version;

  src = fetchSteam {
    name = "resonite-headless-${version}";
    inherit
      appId
      depotId
      manifestId
      branch
      hash
      ;
  };

  dontBuild = true;
  dontConfigure = true;
  dontFixup = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/resonite

    if [ ! -d "Headless" ]; then
      echo "ERROR: Headless directory not found in source"
      ls -la
      exit 1
    fi
    cp -r Headless $out/resonite/

    # Clean up platform-specific runtimes
    if [ -d "$out/resonite/Headless/runtimes" ]; then
      rm -rf "$out/resonite/Headless/runtimes"/{win,osx,ios,android,freebsd}* || true
      rm -rf "$out/resonite/Headless/runtimes"/{rhel,fedora}* || true
      rm -rf "$out/resonite/Headless/runtimes"/${archPatternsToRemove.${targetSystem}} || true
    fi

    # Remove Windows executables, debug symbols, static libraries
    find "$out/resonite/Headless" \( -name "*.exe" -o -name "*.pdb" -o -name "*.a" \) -delete

    if [ ! -f "$out/resonite/Headless/Resonite.dll" ]; then
      echo "ERROR: Resonite.dll not found"
      ls -la "$out/resonite/Headless/"
      exit 1
    fi

    echo "Installed Resonite Headless ($(du -sh $out/resonite/Headless | cut -f1))"

    runHook postInstall
  '';

  meta = {
    description = "Resonite Headless Server";
    homepage = "https://resonite.com";
    license = lib.licenses.unfree;
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
}
