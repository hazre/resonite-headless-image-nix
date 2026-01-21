# Overlay to extend steam-fetcher with ARM64 support and authentication
#
# steam-fetcher's fetchSteam only supports x86_64-linux by default,
# but DepotDownloader from nixpkgs supports both x86_64 and aarch64.
# This overlay patches fetchSteam to work on ARM64 and adds Steam
# authentication support.
#
# USAGE: Build with `nix build --impure` and set these environment variables:
#   STEAM_USERNAME      - Steam account username
#   STEAM_PASSWORD      - Steam account password
#   STEAM_BETA_PASSWORD - Beta branch password (from /headlessCode in Resonite)
#   STEAM_BETA          - Override beta branch (optional, default from manifests.json)
final: prev:

let
  inherit (final) lib;

  # Read credentials at evaluation time (requires --impure flag)
  # This is the standard Nix pattern for handling build-time secrets
  steamUsername = builtins.getEnv "STEAM_USERNAME";
  steamPassword = builtins.getEnv "STEAM_PASSWORD";
  steamBetaPassword = builtins.getEnv "STEAM_BETA_PASSWORD";
in
{
  # Override fetchSteam to support ARM64 and Steam authentication
  fetchSteam =
    {
      name,
      appId,
      depotId,
      manifestId,
      branch ? null,
      hash,
      fileList ? [ ],
      debug ? false,
      # Additional parameters for authentication (override env vars if provided)
      username ? steamUsername,
      password ? steamPassword,
      betaPassword ? steamBetaPassword,
    }:
    let
      fileListFile =
        let
          content = lib.concatStringsSep "\n" fileList;
        in
        final.writeText "steam-file-list-${name}.txt" content;
    in
    final.stdenvNoCC.mkDerivation (
      {
        name = "${name}-depot";

        # Pass proxy env vars for network access
        impureEnvVars = lib.fetchers.proxyImpureEnvVars;

        inherit
          debug
          appId
          depotId
          manifestId
          branch
          ;

        # Pass credentials as derivation attributes (read at eval time with --impure)
        steamUser = username;
        steamPass = password;
        steamBetaPass = betaPassword;

        nativeBuildInputs = [ final.depotdownloader ];

        SSL_CERT_FILE = "${final.cacert}/etc/ssl/certs/ca-bundle.crt";

        builder = final.writeShellScript "fetch-steam-builder" ''
          # shellcheck source=/dev/null
          if [ -e .attrs.sh ]; then source .attrs.sh; fi
          source "$stdenv/setup"

          # Hack to prevent DepotDownloader from crashing trying to write to ~/.local/share/
          export HOME
          HOME=$(mktemp -d)

          args=(
            -app "$appId"
            -depot "$depotId"
            -manifest "$manifestId"
          )

          # Add authentication if credentials were provided at evaluation time
          if [ -n "$steamUser" ] && [ -n "$steamPass" ]; then
            args+=(-username "$steamUser" -password "$steamPass")
          else
            echo "WARNING: No Steam credentials provided. Using anonymous download."
            echo "For authenticated downloads, set STEAM_USERNAME and STEAM_PASSWORD"
            echo "environment variables and build with: nix build --impure"
          fi

          # Add branch if specified
          if [ -n "$branch" ]; then
            args+=(-beta "$branch")
          fi

          # Add beta password if specified
          if [ -n "$steamBetaPass" ]; then
            args+=(-betapassword "$steamBetaPass")
          fi

          if [ -n "$debug" ] && [ "$debug" != "false" ]; then
            args+=(-debug)
          fi

          if [ -n "$filelist" ]; then
            args+=(-filelist "$filelist")
          fi

          echo "Running DepotDownloader..."
          echo "  App: $appId"
          echo "  Depot: $depotId"
          echo "  Manifest: $manifestId"
          echo "  Branch: ''${branch:-public}"
          echo "  Authenticated: $([ -n "$steamUser" ] && echo "yes" || echo "no")"

          DepotDownloader "''${args[@]}" -dir "$out"

          # Clean up DepotDownloader metadata
          rm -rf "''${out:?}/.DepotDownloader"
        '';

        outputHash = hash;
        outputHashAlgo = "sha256";
        outputHashMode = "recursive";

        meta = {
          description = "Steam depot ${depotId} from app ${appId}";
          platforms = lib.platforms.linux;
        };
      }
      // lib.optionalAttrs (fileList != [ ]) { filelist = fileListFile; }
    );
}
