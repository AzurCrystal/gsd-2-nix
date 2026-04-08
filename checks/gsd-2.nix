{ ... }:
{
  perSystem =
    { pkgs, config, ... }:
    {
      checks.gsd-2-blueprint = pkgs.runCommand "gsd-2-blueprint-check" {
        nativeBuildInputs = [
          pkgs.gitMinimal
          pkgs.nodejs_24
        ];
      } ''
        test -x ${config.packages."gsd-2"}/bin/gsd
        test "$(${config.packages."gsd-2"}/bin/gsd --version)" = "2.65.0"
        test -x ${config.packages."gsd-2-suite"}/bin/gsd-mcp-server
        test -x ${config.packages."gsd-2-suite"}/bin/gsd-daemon
        test -x ${config.packages."gsd-2-playwright-runtime"}/bin/gsd-playwright-runtime
        test -x ${config.packages."gsd-2-rtk"}/bin/rtk
        test -x ${config.packages."gsd-2-rtk"}/bin/gsd-rtk-runtime
        test -f ${config.packages."gsd-2"}/share/gsd-2-blueprint/graph.json
        test -f ${config.packages."gsd-2-core"}/share/gsd-2-blueprint/components/gsd-2-core.md
        test -f ${config.packages."gsd-2-web"}/dist/web/standalone/server.js
        test -f ${config.packages."gsd-2"}/dist/web/standalone/server.js
        test -n "$(find -L ${config.packages."gsd-2"}/lib/node_modules/gsd-pi/native/addon -maxdepth 1 -type f -name 'gsd_engine.*.node' -print -quit)"
        test -z "$(find -L ${config.packages."gsd-2"}/lib/node_modules -path '*/@gsd-build/engine-*' -print -quit)"
        test "$(${config.packages."gsd-2-rtk"}/bin/rtk rewrite 'git status')" = "rtk git status"
        rtkEnv="$(${config.packages."gsd-2-rtk"}/bin/gsd-rtk-runtime --print-env)"
        printf '%s\n' "$rtkEnv" | grep -q '^GSD_RTK_PATH='
        printf '%s\n' "$rtkEnv" | grep -q '^GSD_SKIP_RTK_INSTALL=1$'
        printf '%s\n' "$rtkEnv" | grep -q '^RTK_TELEMETRY_DISABLED=1$'
        test -L ${config.packages."gsd-2-playwright-runtime"}/share/gsd-2-playwright-runtime/browsers
        playwrightEnv="$(${config.packages."gsd-2-playwright-runtime"}/bin/gsd-playwright-runtime --print-env)"
        printf '%s\n' "$playwrightEnv" | grep -q '^PLAYWRIGHT_BROWSERS_PATH='
        printf '%s\n' "$playwrightEnv" | grep -q '^PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1$'
        printf '%s\n' "$playwrightEnv" | grep -q '^PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS=true$'
        mkdir -p "$out"
      '';
    };
}
