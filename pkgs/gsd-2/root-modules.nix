{ pkgs, sourceInfo }:
pkgs.buildNpmPackage {
  pname = "gsd-2-root-modules";
  inherit (sourceInfo) src version;

  npmDepsHash = sourceInfo.rootNpmDepsHash;
  npmDepsFetcherVersion = 2;
  nodejs = pkgs.nodejs_24;
  dontNpmBuild = true;
  npmPackFlags = [ "--ignore-scripts" ];
  npmRebuildFlags = [ "--ignore-scripts" ];
  env = sourceInfo.commonEnv;
  postPatch = ''
    if ! grep -q '"node_modules/@emnapi/runtime"' package-lock.json; then
      if ! grep -q '"@emnapi/runtime": "1.10.0"' package-lock.json; then
        echo "known @emnapi/runtime lockfile patch does not cover this root package-lock.json" >&2
        exit 1
      fi
      awk '
        $0 == "    \"node_modules/@emnapi/wasi-threads\": {" && ! inserted {
          print "    \"node_modules/@emnapi/runtime\": {"
          print "      \"version\": \"1.10.0\","
          print "      \"resolved\": \"https://registry.npmjs.org/@emnapi/runtime/-/runtime-1.10.0.tgz\","
          print "      \"integrity\": \"sha512-ewvYlk86xUoGI0zQRNq/mC+16R1QeDlKQy21Ki3oSYXNgLb45GV1P6A0M+/s6nyCuNDqe5VpaY84BzXGwVbwFA==\","
          print "      \"license\": \"MIT\","
          print "      \"optional\": true,"
          print "      \"dependencies\": {"
          print "        \"tslib\": \"^2.4.0\""
          print "      }"
          print "    },"
          inserted = 1
        }
        { print }
        END {
          if (!inserted) {
            exit 2
          }
        }
      ' package-lock.json > package-lock.json.patched
      mv package-lock.json.patched package-lock.json
    fi
  '';

  installPhase = ''
        runHook preInstall

        mkdir -p "$out/share/gsd-2-blueprint/components"
        cp package.json package-lock.json "$out/"
        cp -a node_modules packages studio extensions "$out/"

        cat <<'EOF' > "$out/share/gsd-2-blueprint/components/gsd-2-root-modules.md"
    # gsd-2-root-modules

    role: internal dependency layer
    summary: Offline closure for the root package-lock, workspace node_modules layout, and shared JS runtime inputs.

    details:
    - consumes the root package-lock.json and root npm workspace graph
    - feeds the built-tree and unified runtime derivations
    - is implemented for real in phase 1 so later graph stages can reuse a stable offline root dependency layer
    EOF

        runHook postInstall
  '';

  meta = {
    description = "Offline root dependency closure for gsd-2";
    platforms = pkgs.lib.platforms.unix;
  };
}
