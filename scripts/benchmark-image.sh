#!/usr/bin/env bash
# Analyze image size breakdown and find library overlaps
#
# Usage: ./scripts/benchmark-image.sh [--with-tar] [--debug]

set -euo pipefail

DEBUG="${DEBUG:-false}"
[[ "${1:-}" == "--debug" || "${2:-}" == "--debug" ]] && DEBUG=true

debug() {
  [[ "$DEBUG" == "true" ]] && echo "[DEBUG] $*" >&2 || true
}

cd "$(dirname "${BASH_SOURCE[0]}")/.."

echo "=== Resonite Headless Image Size Analysis ==="
echo "Date: $(date)"
echo ""

# Build resonite-headless and image
echo "Building resonite-headless and image..."
debug "Running: nix build .#resonite-headless .#image --impure --print-out-paths"
build_output=$(nix build .#resonite-headless .#image --impure --print-out-paths 2>/dev/null)
resonite_pkg=$(echo "$build_output" | grep "resonite-headless" | head -1)
image_pkg=$(echo "$build_output" | grep "image-resonite-headless" | head -1)
debug "resonite_pkg=$resonite_pkg"
debug "image_pkg=$image_pkg"
echo ""

echo "=== Image Sizes ==="

# Get image closure size from built path
debug "Running: nix path-info -Sh $image_pkg"
image_closure=$(nix path-info -Sh "$image_pkg" 2>&1 | grep -E "^/nix/store" | head -1 | awk '{print $2}' || true)
image_closure="${image_closure:-?}"
echo "Image closure: ${image_closure} MiB"

# Build and check tarball if requested
if [[ "${1:-}" == "--with-tar" ]]; then
  echo "Building tarball..."
  rm -f resonite-headless.tar
  nix run .#copyToDockerArchive --impure 2>&1 | tail -1
  echo "Tarball: $(ls -lh resonite-headless.tar | awk '{print $5}')"
fi
echo ""

echo "=== Component Sizes ==="

# Resonite package (direct size, not closure)
resonite_size=$(du -sh "$resonite_pkg" | cut -f1)
echo "resonite-headless: $resonite_size"

# .NET runtime closure
debug "Running: nix path-info -Sh nixpkgs#dotnet-runtime_10"
dotnet_size=$(nix path-info -Sh 'nixpkgs#dotnet-runtime_10' 2>&1 | grep -E "^/nix/store" | head -1 | awk '{print $2}' || true)
dotnet_size="${dotnet_size:-?}"
echo "dotnet-runtime_10: ${dotnet_size} MiB (closure)"
echo ""

echo "=== Native Libs from Nix (in nativeLibs) ==="
# These should match what's in nix/images/default.nix
nix_libs=(fontconfig icu openssl zlib)

for lib in "${nix_libs[@]}"; do
  debug "Checking size for nixpkgs#$lib"
  size=$(nix path-info -Sh "nixpkgs#$lib" 2>&1 | grep -E "^/nix/store" | head -1 | awk '{print $2}' || true)
  size="${size:-?}"
  printf "  %-12s %6s MiB (closure)\n" "$lib:" "$size"
done
echo ""

echo "=== Resonite Bundled Native Libs ==="
resonite_native_dir="$resonite_pkg/resonite/Headless/runtimes/linux-x64/native"
debug "Looking for native libs in: $resonite_native_dir"

if [[ -d "$resonite_native_dir" ]]; then
  # Get list of .so files
  bundled_libs=""
  while IFS= read -r -d '' file; do
    bundled_libs+="$(basename "$file")"$'\n'
  done < <(find "$resonite_native_dir" -maxdepth 1 -name "*.so" -print0 2>/dev/null)

  bundled_libs=$(echo "$bundled_libs" | sort | sed '/^$/d')
  debug "Found bundled libs: $(echo "$bundled_libs" | tr '\n' ' ')"

  if [[ -n "$bundled_libs" ]]; then
    echo "$bundled_libs"
    bundled_count=$(echo "$bundled_libs" | wc -l)
    bundled_size=$(du -sh "$resonite_native_dir" | cut -f1)
    echo ""
    echo "Total: $bundled_count libs, $bundled_size"
  else
    echo "No .so files found in native directory"
    bundled_libs=""
  fi
else
  echo "Native directory not found: $resonite_native_dir"
  debug "Available dirs in runtimes:"
  debug "$(ls "$resonite_pkg/resonite/Headless/runtimes/" 2>/dev/null || echo 'none')"
  bundled_libs=""
fi
echo ""

echo "=== Library Overlap Analysis ==="
echo "Checking if Resonite bundles libraries we also provide from Nix..."
echo ""

if [[ -z "$bundled_libs" ]]; then
  echo "No bundled libs found, skipping overlap analysis"
else
  # Map of nix package names to library name patterns
  declare -A lib_patterns
  lib_patterns["brotli"]="libbrotli|brolib"
  lib_patterns["fontconfig"]="libfontconfig"
  lib_patterns["freetype"]="libfreetype"
  lib_patterns["icu"]="libicu"
  lib_patterns["libopus"]="libopus"
  lib_patterns["openssl"]="libssl|libcrypto"
  lib_patterns["zlib"]="libz\."

  found_overlaps=()
  correctly_bundled=()

  for nix_pkg in "${!lib_patterns[@]}"; do
    pattern="${lib_patterns[$nix_pkg]}"
    debug "Checking pattern '$pattern' for package '$nix_pkg'"

    # Check if any bundled lib matches this pattern
    matching=$(echo "$bundled_libs" | grep -iE "$pattern" || true)

    if [[ -n "$matching" ]]; then
      matching_oneline=$(echo "$matching" | tr '\n' ' ')
      debug "Found match: $matching_oneline"

      # Check if this package is in our nativeLibs
      is_in_nativelibs=false
      for nl in "${nix_libs[@]}"; do
        if [[ "$nl" == "$nix_pkg" ]]; then
          is_in_nativelibs=true
          break
        fi
      done

      if [[ "$is_in_nativelibs" == "true" ]]; then
        echo "OVERLAP: $nix_pkg"
        echo "  Nix provides: $nix_pkg"
        echo "  Resonite bundles: $matching_oneline"
        echo "  Status: BOTH in nativeLibs and bundled - possible redundancy!"
        found_overlaps+=("$nix_pkg")
      else
        echo "OK: $nix_pkg"
        echo "  Resonite bundles: $matching_oneline"
        echo "  Status: Not in nativeLibs (using bundled version)"
        correctly_bundled+=("$nix_pkg")
      fi
      echo ""
    fi
  done

  echo "=== Summary ==="
  echo ""

  if [[ ${#found_overlaps[@]} -gt 0 ]]; then
    echo "OVERLAPPING (in both nativeLibs and bundled):"
    for lib in "${found_overlaps[@]}"; do
      echo "  - $lib"
    done
    echo ""
    echo "Consider removing these from nativeLibs in nix/images/default.nix"
    echo "if Resonite's bundled versions are sufficient."
  else
    echo "No overlapping libraries found - nativeLibs is optimized!"
  fi

  if [[ ${#correctly_bundled[@]} -gt 0 ]]; then
    echo ""
    echo "CORRECTLY USING BUNDLED (not in nativeLibs):"
    for lib in "${correctly_bundled[@]}"; do
      echo "  - $lib"
    done
  fi
fi

echo ""
echo "=== Nix Store Paths in Image ==="
echo "Counting unique store paths in image closure..."
nix_paths=$(nix path-info -r "$image_pkg" 2>/dev/null | wc -l || true)
nix_paths="${nix_paths:-?}"
echo "Total store paths: $nix_paths"
