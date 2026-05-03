{
  pkgs,
  companionsTree,
  sourceInfo,
}:
let
  runtimePath = pkgs.lib.makeBinPath [
    pkgs.gitMinimal
    pkgs.nodejs_24
  ];
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
            cp -a ${companionsTree}/node_modules ${companionsTree}/packages ${companionsTree}/studio ${companionsTree}/extensions "$root/"

            cat <<'EOF' > "$out/share/gsd-2-blueprint/components/gsd-mcp-server.md"
      # gsd-mcp-server

      role: companion CLI lane
      summary: Source-built MCP server companion CLI extracted from the shared companions tree.

      details:
      - compiled from upstream gsd-2 source
      - runs against the local companion root tree instead of a placeholder stub
      EOF

            makeWrapper ${node} "$out/bin/gsd-mcp-server" \
              --add-flags "$root/packages/mcp-server/dist/cli.js" \
              --prefix PATH : "${runtimePath}"

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
