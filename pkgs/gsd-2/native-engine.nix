{
  pkgs,
  rustToolchain,
  sourceInfo,
}:
let
  rustPlatform = pkgs.makeRustPlatform {
    cargo = rustToolchain;
    rustc = rustToolchain;
  };

  archTag =
    if pkgs.stdenv.hostPlatform.isx86_64 then
      "x64"
    else if pkgs.stdenv.hostPlatform.isAarch64 then
      "arm64"
    else
      throw "Unsupported native-engine CPU for gsd-2: ${pkgs.stdenv.hostPlatform.parsed.cpu.name}";

  platformTag =
    if pkgs.stdenv.hostPlatform.isLinux then
      "linux-${archTag}"
    else if pkgs.stdenv.hostPlatform.isDarwin then
      "darwin-${archTag}"
    else
      throw "Unsupported native-engine platform for gsd-2: ${pkgs.stdenv.hostPlatform.system}";

  libraryName =
    if pkgs.stdenv.hostPlatform.isLinux then
      "libgsd_engine.so"
    else if pkgs.stdenv.hostPlatform.isDarwin then
      "libgsd_engine.dylib"
    else
      throw "Unsupported native-engine library mapping for ${pkgs.stdenv.hostPlatform.system}";
in
rustPlatform.buildRustPackage {
  pname = "gsd-2-native-engine";
  inherit (sourceInfo) src version;

  sourceRoot = "${sourceInfo.src.name}/native";
  cargoLock.lockFile = "${sourceInfo.src}/native/Cargo.lock";
  cargoBuildFlags = [
    "--package"
    "gsd-engine"
  ];

  nativeBuildInputs = [
    pkgs.cmake
    pkgs.pkg-config
    pkgs.perl
  ];

  buildInputs = [
    pkgs.openssl
    pkgs.zlib
  ];

  env = sourceInfo.commonEnv;
  doCheck = false;

  installPhase = ''
        runHook preInstall

        addonDir="$out/lib/node_modules/gsd-pi/native/addon"
        mkdir -p "$addonDir" "$out/share/gsd-2-blueprint/components"

        builtAddon="$(find target -type f -name "${libraryName}" -print -quit)"
        if [ -z "$builtAddon" ]; then
          echo "failed to locate native-engine output ${libraryName} under target/" >&2
          find target -maxdepth 4 -type f | sort >&2 || true
          exit 1
        fi

        cp "$builtAddon" "$addonDir/gsd_engine.${platformTag}.node"

        cat <<'EOF' > "$out/share/gsd-2-blueprint/components/gsd-2-native-engine.md"
    # gsd-2-native-engine

    role: native runtime bridge
    summary: Source-built Rust N-API addon for the @gsd/native runtime path.

    details:
    - builds the native engine from the upstream gsd-2 Rust workspace using a fenix-provided toolchain
    - installs the compiled addon at lib/node_modules/gsd-pi/native/addon so the packaged loader can resolve it locally
    - is intended to replace reliance on upstream prebuilt @gsd-build/engine-* packages
    EOF

        runHook postInstall
  '';

  meta = with pkgs.lib; {
    description = "Source-built Rust native engine for gsd-2";
    homepage = "https://github.com/gsd-build/gsd-2";
    license = licenses.mit;
    platforms = platforms.unix;
  };
}
