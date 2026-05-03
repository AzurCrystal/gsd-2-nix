{
  pkgs,
  builtTree,
  sourceInfo,
}:
pkgs.stdenvNoCC.mkDerivation {
  pname = "gsd-2-companions-tree";
  inherit (sourceInfo) version;

  src = builtTree;
  nativeBuildInputs = [ pkgs.nodejs_24 ];
  env = sourceInfo.commonEnv;

  buildPhase = ''
    runHook preBuild

    export HOME="$TMPDIR"

    npm run build -w @gsd-build/rpc-client
    npm run build -w @gsd-build/mcp-server
    npm run build -w @gsd-build/daemon

    runHook postBuild
  '';

  installPhase = ''
        runHook preInstall

        mkdir -p "$out/share/gsd-2-blueprint/components"
        cp -a package.json package-lock.json node_modules packages studio extensions "$out/"

        cat <<'EOF' > "$out/share/gsd-2-blueprint/components/gsd-2-companions-tree.md"
    # gsd-2-companions-tree

    role: shared companion build tree
    summary: Shared source-built tree for rpc-client, mcp-server, and daemon companion outputs.

    details:
    - builds all upstream companion packages from the gsd-2 source tree
    - reuses the root workspace dependency closure instead of introducing a second packaging style
    - exists so individual companion packages can install from one consistent built tree
    EOF

        runHook postInstall
  '';

  meta = {
    description = "Shared source-built companion tree for gsd-2";
    platforms = pkgs.lib.platforms.unix;
  };
}
