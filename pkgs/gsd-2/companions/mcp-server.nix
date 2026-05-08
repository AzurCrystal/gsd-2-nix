{
  pkgs,
  builtTree,
  companionsTree,
  core,
  sourceInfo,
}:
let
  runtimePath = pkgs.lib.makeBinPath [
    core
    pkgs.gitMinimal
    pkgs.nodejs_24
  ];
  gsdCliPath = "${core}/bin/gsd";
in
pkgs.stdenvNoCC.mkDerivation {
  pname = "gsd-mcp-server";
  inherit (sourceInfo) version;

  dontUnpack = true;
  nativeBuildInputs = [
    pkgs.makeWrapper
    pkgs.nodejs_24
  ];

  installPhase =
    let
      node = pkgs.lib.getExe pkgs.nodejs_24;
    in
    ''
            runHook preInstall

            root="$out/share/gsd-2-mcp-server-root"
            mkdir -p "$root" "$out/bin" "$out/share/gsd-2-blueprint/components"
            cp ${builtTree}/package.json "$root/"
            cp -a ${companionsTree}/node_modules ${companionsTree}/packages ${companionsTree}/studio ${companionsTree}/extensions "$root/"
            mkdir -p "$root/dist"
            cp -a ${builtTree}/dist/resources "$root/dist/"
            mkdir -p "$root/src"
            cp -a ${builtTree}/src/resources "$root/src/"

            cat <<'EOF' > "$out/share/gsd-2-blueprint/components/gsd-mcp-server.md"
      # gsd-mcp-server

      role: companion CLI lane
      summary: Source-built MCP server companion CLI extracted from the shared companions tree.

      details:
      - compiled from upstream gsd-2 source
      - runs against the local companion root tree instead of a placeholder stub
      - includes root GSD runtime resources required by workflow mutation tools
      - resolves gsd_execute sessions through the packaged gsd CLI
      EOF

            makeWrapper ${node} "$out/bin/gsd-mcp-server" \
              --add-flags "$root/packages/mcp-server/dist/cli.js" \
              --prefix PATH : "${runtimePath}" \
              --set-default GSD_CLI_PATH "${gsdCliPath}"

            runHook postInstall
    '';

  meta = with pkgs.lib; {
    description = "Source-built MCP server companion CLI for gsd-2";
    homepage = "https://github.com/gsd-build/gsd-2";
    license = licenses.mit;
    mainProgram = "gsd-mcp-server";
    platforms = platforms.unix;
  };
}
