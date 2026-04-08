{ pkgs, sourceInfo }:
pkgs.buildNpmPackage {
  pname = "gsd-2-root-modules";
  inherit (sourceInfo) src version;

  npmDepsHash = sourceInfo.rootNpmDepsHash;
  nodejs = pkgs.nodejs_24;
  dontNpmBuild = true;
  npmPackFlags = [ "--ignore-scripts" ];
  npmRebuildFlags = [ "--ignore-scripts" ];
  env = sourceInfo.commonEnv;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/share/gsd-2-blueprint/components"
    cp package.json package-lock.json "$out/"
    cp -a node_modules packages studio "$out/"

    cat <<'EOF' > "$out/share/gsd-2-blueprint/components/gsd-2-root-modules.md"
# gsd-2-root-modules

role: internal dependency layer
summary: Offline closure for the root package-lock, workspace node_modules layout, and shared JS runtime inputs.

details:
- consumes the root package-lock.json and root npm workspace graph
- feeds the built-tree and companion package derivations
- is implemented for real in phase 1 so later graph stages can reuse a stable offline root dependency layer
EOF

    runHook postInstall
  '';

  meta = {
    description = "Offline root dependency closure for gsd-2";
    platforms = pkgs.lib.platforms.unix;
  };
}
