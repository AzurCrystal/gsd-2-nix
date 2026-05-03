{ pkgs, sourceInfo }:
let
  webNpmDeps = pkgs.fetchNpmDeps {
    inherit (sourceInfo) src;
    sourceRoot = "source/web";
    hash = sourceInfo.webNpmDepsHash;
  };
in
pkgs.buildNpmPackage {
  pname = "gsd-2-web-modules";
  inherit (sourceInfo) src version;

  npmRoot = "web";
  npmDeps = webNpmDeps;
  nodejs = pkgs.nodejs_24;
  dontNpmBuild = true;
  npmPackFlags = [ "--ignore-scripts" ];
  npmRebuildFlags = [
    "--foreground-scripts"
    "node-pty"
  ];
  env = sourceInfo.commonEnv;

  installPhase = ''
        runHook preInstall

        mkdir -p "$out/share/gsd-2-blueprint/components"
        cp web/package.json web/package-lock.json "$out/"
        cp -a web/node_modules "$out/"

        cat <<'EOF' > "$out/share/gsd-2-blueprint/components/gsd-2-web-modules.md"
    # gsd-2-web-modules

    role: web dependency layer
    summary: Offline closure for the dedicated web/package-lock dependency graph, including node-pty and image-processing inputs.

    details:
    - consumes web/package-lock.json independently from the root package-lock
    - rebuilds node-pty in the Nix build so the packaged standalone host has native terminal support
    - is implemented for real in phase 2 so the web host can build without reusing the root dependency lock
    EOF

        runHook postInstall
  '';

  meta = {
    description = "Offline web dependency closure for gsd-2";
    platforms = pkgs.lib.platforms.unix;
  };
}
