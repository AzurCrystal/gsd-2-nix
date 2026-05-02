{ pkgs, sourceInfo, rootModules }:
pkgs.stdenvNoCC.mkDerivation {
  pname = "gsd-2-built-tree";
  inherit (sourceInfo) src version;

  nativeBuildInputs = [ pkgs.nodejs_24 ];
  env = sourceInfo.commonEnv;

  buildPhase = ''
    runHook preBuild

    export HOME="$TMPDIR"

    cp -a ${rootModules}/node_modules ./node_modules

    npm run build:core

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/share/gsd-2-blueprint/components"
    cp -a . "$out/"

    cat <<'EOF' > "$out/share/gsd-2-blueprint/components/gsd-2-built-tree.md"
# gsd-2-built-tree

role: shared compiled source tree
summary: Shared root/workspace build output that produces dist, pkg, and bundled resources before web packaging runs.

details:
- builds the root CLI sources and required workspace dist outputs
- is the real phase-1 compiled tree consumed by gsd-2-core
- leaves web standalone packaging for a later graph stage
EOF

    runHook postInstall
  '';

  meta = {
    description = "Compiled root/workspace build tree for gsd-2";
    platforms = pkgs.lib.platforms.unix;
  };
}
