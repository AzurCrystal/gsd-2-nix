{
  pkgs,
  companionsTree,
  sourceInfo,
}:
pkgs.stdenvNoCC.mkDerivation {
  pname = "gsd-rpc-client";
  inherit (sourceInfo) version;

  dontUnpack = true;

  installPhase = ''
        runHook preInstall

        packageRoot="$out/lib/node_modules/@gsd-build/rpc-client"
        mkdir -p "$packageRoot" "$out/share/gsd-2-blueprint/components"
        cp ${companionsTree}/packages/rpc-client/package.json "$packageRoot/"
        cp ${companionsTree}/packages/rpc-client/README.md "$packageRoot/"
        cp -a ${companionsTree}/packages/rpc-client/dist "$packageRoot/"

        cat <<'EOF' > "$out/share/gsd-2-blueprint/components/gsd-rpc-client.md"
    # gsd-rpc-client

    role: companion library lane
    summary: Source-built rpc-client companion package extracted from the shared companions tree.

    details:
    - compiled from the upstream gsd-2 source tree
    - packaged as a library-style output without a top-level CLI wrapper
    EOF

        runHook postInstall
  '';

  meta = with pkgs.lib; {
    description = "Source-built rpc-client companion package for gsd-2";
    homepage = "https://github.com/gsd-build/gsd-2";
    license = licenses.mit;
    platforms = platforms.unix;
  };
}
