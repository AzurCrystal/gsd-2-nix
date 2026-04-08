{ pkgs, sourceInfo, builtTree }:
let
  runtimePath =
    pkgs.lib.makeBinPath (
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
  pname = "gsd-2-core";
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
      cp -a ${builtTree}/dist ${builtTree}/packages ${builtTree}/pkg ${builtTree}/node_modules ${builtTree}/studio "$packageRoot/"
      cp -a ${builtTree}/src/resources "$packageRoot/src/"
      cp ${builtTree}/scripts/postinstall.js ${builtTree}/scripts/link-workspace-packages.cjs ${builtTree}/scripts/ensure-workspace-builds.cjs "$packageRoot/scripts/"

      chmod -R u+w "$packageRoot/node_modules/@gsd-build" || true
      for engineDir in "$packageRoot"/node_modules/@gsd-build/engine-*; do
        if [ -e "$engineDir" ]; then
          chmod -R u+w "$engineDir" || true
          rm -rf "$engineDir"
        fi
      done

      cat <<'EOF' > "$out/share/gsd-2-blueprint/components/gsd-2-core.md"
# gsd-2-core

role: primary CLI runtime
summary: Real phase-1 core gsd-2 CLI/runtime layer with working gsd and gsd-cli entrypoints.

details:
- wraps the built root/workspace tree from gsd-2-built-tree
- includes the published runtime layout expected by the upstream loader
- intentionally excludes packaged web standalone assets so phase 1 stays scoped
EOF

      makeWrapper ${node} "$out/bin/gsd" \
        --add-flags "$packageRoot/dist/loader.js" \
        --prefix PATH : "${runtimePath}" \
        --set-default GSD_SKIP_RTK_INSTALL "1"

      makeWrapper ${node} "$out/bin/gsd-cli" \
        --add-flags "$packageRoot/dist/loader.js" \
        --prefix PATH : "${runtimePath}" \
        --set-default GSD_SKIP_RTK_INSTALL "1"

      runHook postInstall
    '';

  meta = with pkgs.lib; {
    description = "Core gsd-2 CLI/runtime layer with working root/workspace offline build";
    homepage = "https://github.com/gsd-build/gsd-2";
    license = licenses.mit;
    mainProgram = "gsd";
    platforms = platforms.unix;
  };
}
