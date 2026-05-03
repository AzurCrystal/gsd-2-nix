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
  pname = "gsd-daemon";
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

            root="$out/share/gsd-2-daemon-root"
            mkdir -p "$root" "$out/bin" "$out/share/gsd-2-blueprint/components"
            cp -a ${companionsTree}/node_modules ${companionsTree}/packages ${companionsTree}/studio ${companionsTree}/extensions "$root/"

            cat <<'EOF' > "$out/share/gsd-2-blueprint/components/gsd-daemon.md"
      # gsd-daemon

      role: companion CLI lane
      summary: Source-built daemon companion CLI extracted from the shared companions tree.

      details:
      - compiled from upstream gsd-2 source
      - runs against the local companion root tree instead of a placeholder stub
      EOF

            makeWrapper ${node} "$out/bin/gsd-daemon" \
              --add-flags "$root/packages/daemon/dist/cli.js" \
              --prefix PATH : "${runtimePath}"

            runHook postInstall
    '';

  meta = with pkgs.lib; {
    description = "Source-built daemon companion CLI for gsd-2";
    homepage = "https://github.com/gsd-build/gsd-2";
    license = licenses.mit;
    mainProgram = "gsd-daemon";
    platforms = platforms.unix;
  };
}
