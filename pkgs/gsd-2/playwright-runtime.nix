{ pkgs, sourceInfo }:
let
  inherit (pkgs) lib;

  playwrightDriver = pkgs.playwright-driver;
  playwrightBrowsers = playwrightDriver.selectBrowsers {
    withFirefox = false;
    withWebkit = false;
  };
in
assert lib.assertMsg (
  # Upstream declares a semver range for Playwright; sourceInfo stores the lower bound.
  lib.versionAtLeast playwrightDriver.version sourceInfo.playwrightVersion
) "gsd-2-playwright-runtime expects nixpkgs playwright-driver >= ${sourceInfo.playwrightVersion}, got ${playwrightDriver.version}";
pkgs.stdenvNoCC.mkDerivation {
  pname = "gsd-2-playwright-runtime";
  version = sourceInfo.version;
  dontUnpack = true;

  installPhase = ''
    mkdir -p \
      "$out/bin" \
      "$out/share/gsd-2-blueprint/components" \
      "$out/share/gsd-2-playwright-runtime"

    ln -s ${playwrightBrowsers} "$out/share/gsd-2-playwright-runtime/browsers"

    cat <<'EOF' > "$out/share/gsd-2-playwright-runtime/env"
PLAYWRIGHT_BROWSERS_PATH=$out/share/gsd-2-playwright-runtime/browsers
PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1
PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS=true
EOF

    cat <<'EOF' > "$out/share/gsd-2-blueprint/components/gsd-2-playwright-runtime.md"
# gsd-2-playwright-runtime

role: optional browser automation host runtime
summary: Host-side Playwright Chromium runtime for gsd browser-tools, kept outside the default gsd-2 closure.

details:
- uses nixpkgs playwright-driver Chromium browser artifacts, including the headless shell Playwright expects in headless mode, instead of npm postinstall downloads
- exports PLAYWRIGHT_BROWSERS_PATH so the upstream playwright dependency in gsd resolves a matching browser bundle offline
- exports PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1 and PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS=true for Nix-hosted browser execution
- keeps browser automation policy outside the default gsd-2 meta package so non-browser users do not pay the Chromium closure cost
- leaves BROWSER_PATH unset by default and relies on Playwright's own browser-root resolution; callers can still override BROWSER_PATH explicitly
EOF

    cat <<'EOF' > "$out/bin/gsd-playwright-runtime"
#!${pkgs.runtimeShell}
set -euo pipefail

runtime_root="$(cd "$(dirname "$0")/.." && pwd)"
export PLAYWRIGHT_BROWSERS_PATH="$runtime_root/share/gsd-2-playwright-runtime/browsers"
export PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1
export PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS=true

print_env() {
  cat <<ENV
PLAYWRIGHT_BROWSERS_PATH=$PLAYWRIGHT_BROWSERS_PATH
PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=$PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD
PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS=$PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS
ENV
}

case "''${1-}" in
  ""|-h|--help)
    cat <<'USAGE'
gsd-playwright-runtime

Usage:
  gsd-playwright-runtime --print-env
  gsd-playwright-runtime -- <command> [args...]

Purpose:
  Runs a command with the gsd Playwright host runtime environment wired to the
  nixpkgs Chromium browser closure.
USAGE
    exit 0
    ;;
  --print-env)
    print_env
    exit 0
    ;;
  --)
    shift
    ;;
esac

if [ "$#" -eq 0 ]; then
  exit 0
fi

exec "$@"
EOF
    chmod +x "$out/bin/gsd-playwright-runtime"
  '';

  meta = with pkgs.lib; {
    description = "Optional Playwright Chromium host runtime for gsd-2 browser tools";
    homepage = "https://github.com/gsd-build/gsd-2";
    license = licenses.mit;
    platforms = platforms.unix;
    mainProgram = "gsd-playwright-runtime";
  };
}
