{
  pkgs,
  sourceInfo,
  builtTree,
  companionsTree,
  nativeEngine,
  web,
  graphJson,
}:
let
  runtimePath = pkgs.lib.makeBinPath (
    [
      pkgs.fd
      pkgs.gitMinimal
      pkgs.nodejs_24
      pkgs.ripgrep
    ]
    ++ pkgs.lib.optionals pkgs.stdenv.hostPlatform.isLinux [ pkgs.xdg-utils ]
  );
in
pkgs.stdenvNoCC.mkDerivation {
  pname = "gsd-2";
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

            packageRoot="$out/lib/node_modules/gsd-pi"
            mkdir -p "$packageRoot" "$packageRoot/scripts" "$packageRoot/src" "$out/bin" "$out/share/gsd-2-blueprint/components"

            cp ${builtTree}/package.json ${builtTree}/README.md ${builtTree}/LICENSE "$packageRoot/"
            cp -a ${builtTree}/dist ${builtTree}/packages ${builtTree}/pkg ${builtTree}/node_modules ${builtTree}/studio ${builtTree}/extensions "$packageRoot/"
            cp -a ${builtTree}/src/resources "$packageRoot/src/"
            cp ${builtTree}/scripts/postinstall.js ${builtTree}/scripts/link-workspace-packages.cjs ${builtTree}/scripts/ensure-workspace-builds.cjs "$packageRoot/scripts/"
            chmod -R u+w "$packageRoot/dist" || true
            rm -rf "$packageRoot/dist/web"
            ln -s ${web}/dist/web "$packageRoot/dist/web"

            chmod -R u+w "$packageRoot/node_modules/@gsd-build" || true
            for engineDir in "$packageRoot"/node_modules/@gsd-build/engine-*; do
              if [ -e "$engineDir" ]; then
                chmod -R u+w "$engineDir" || true
                rm -rf "$engineDir"
              fi
            done

            mkdir -p "$packageRoot/native"
            ln -s ${nativeEngine}/lib/node_modules/gsd-pi/native/addon "$packageRoot/native/addon"

            chmod -R u+w "$packageRoot/packages" || true
            rm -rf "$packageRoot/packages/rpc-client" "$packageRoot/packages/mcp-server" "$packageRoot/packages/daemon"
            cp -a ${companionsTree}/packages/rpc-client "$packageRoot/packages/rpc-client"
            cp -a ${companionsTree}/packages/mcp-server "$packageRoot/packages/mcp-server"
            cp -a ${companionsTree}/packages/daemon "$packageRoot/packages/daemon"

            ln -s "$packageRoot/dist" "$out/dist"
            ln -s "$packageRoot/packages" "$out/packages"
            ln -s "$packageRoot/native" "$out/native"
            ln -s "$packageRoot/src" "$out/src"

            cat > "$out/share/gsd-2-blueprint/graph.json" <<'EOF'
            ${graphJson}
      EOF

            cat <<'EOF' > "$out/share/gsd-2-blueprint/components/gsd-2.md"
      # gsd-2

      role: unified core runtime
      summary: Unified gsd-2 runtime with CLI, MCP server, daemon, RPC client, web, and native engine in one package root.

      details:
      - wraps the built root/workspace tree from gsd-2-built-tree
      - includes the published runtime layout expected by the upstream loader
      - links the packaged standalone web host into dist/web so gsd --web can use default bootstrap resolution
      - exposes the source-built native addon at the relative path that @gsd/native resolves at runtime
      - installs mcp-server, daemon, and rpc-client into the same package root so core process boundaries share one runtime layout
      EOF

            makeWrapper ${node} "$out/bin/gsd" \
              --add-flags "$packageRoot/dist/loader.js" \
              --prefix PATH : "${runtimePath}" \
              --set-default GSD_SKIP_RTK_INSTALL "1"

            makeWrapper ${node} "$out/bin/gsd-cli" \
              --add-flags "$packageRoot/dist/loader.js" \
              --prefix PATH : "${runtimePath}" \
              --set-default GSD_SKIP_RTK_INSTALL "1"

            makeWrapper ${node} "$out/bin/gsd-mcp-server" \
              --add-flags "$packageRoot/packages/mcp-server/dist/cli.js" \
              --prefix PATH : "${runtimePath}" \
              --set-default GSD_CLI_PATH "$packageRoot/dist/loader.js" \
              --set-default GSD_SKIP_RTK_INSTALL "1"

            makeWrapper ${node} "$out/bin/gsd-daemon" \
              --add-flags "$packageRoot/packages/daemon/dist/cli.js" \
              --prefix PATH : "${runtimePath}" \
              --set-default GSD_CLI_PATH "$packageRoot/dist/loader.js" \
              --set-default GSD_SKIP_RTK_INSTALL "1"

            runHook postInstall
    '';

  meta = with pkgs.lib; {
    description = "Unified gsd-2 CLI, MCP, daemon, web, and native runtime package";
    homepage = "https://github.com/gsd-build/gsd-2";
    license = licenses.mit;
    mainProgram = "gsd";
    platforms = platforms.unix;
  };
}
