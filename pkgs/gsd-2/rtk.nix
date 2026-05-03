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

  rtkSrc = pkgs.fetchFromGitHub {
    owner = "rtk-ai";
    repo = "rtk";
    rev = "v${sourceInfo.rtkVersion}";
    hash = sourceInfo.rtkSrcHash;
  };
in
rustPlatform.buildRustPackage {
  pname = "gsd-2-rtk";
  version = sourceInfo.version;
  src = rtkSrc;

  cargoLock.lockFile = "${rtkSrc}/Cargo.lock";

  nativeBuildInputs = [
    pkgs.perl
  ];

  doCheck = false;

  postInstall = ''
        mkdir -p \
          "$out/share/gsd-2-blueprint/components" \
          "$out/share/gsd-2-rtk"

        cat <<'EOF' > "$out/share/gsd-2-rtk/env"
    GSD_RTK_PATH=$out/bin/rtk
    GSD_SKIP_RTK_INSTALL=1
    RTK_TELEMETRY_DISABLED=1
    EOF

        cat <<'EOF' > "$out/share/gsd-2-blueprint/components/gsd-2-rtk.md"
    # gsd-2-rtk

    role: optional shell compression helper
    summary: Source-built RTK helper for gsd shell-command compression, kept outside the default gsd-2 closure.

    details:
    - builds rtk from the upstream rtk-ai/rtk source tag pinned by gsd instead of downloading release binaries at postinstall time
    - exports GSD_RTK_PATH to the packaged binary so gsd can use RTK without writing into ~/.gsd/agent/bin
    - exports GSD_SKIP_RTK_INSTALL=1 to keep runtime behavior offline once a packaged RTK path is provided
    - exports RTK_TELEMETRY_DISABLED=1 to match gsd's managed-invocation policy
    - keeps RTK out of the default gsd-2 meta package so users who do not opt into experimental.rtk avoid the extra closure
    EOF

        cat <<'EOF' > "$out/bin/gsd-rtk-runtime"
    #!${pkgs.runtimeShell}
    set -euo pipefail

    runtime_root="$(cd "$(dirname "$0")/.." && pwd)"
    export GSD_RTK_PATH="$runtime_root/bin/rtk"
    export GSD_SKIP_RTK_INSTALL=1
    export RTK_TELEMETRY_DISABLED=1

    print_env() {
      cat <<ENV
    GSD_RTK_PATH=$GSD_RTK_PATH
    GSD_SKIP_RTK_INSTALL=$GSD_SKIP_RTK_INSTALL
    RTK_TELEMETRY_DISABLED=$RTK_TELEMETRY_DISABLED
    ENV
    }

    case "''${1-}" in
      ""|-h|--help)
        cat <<'USAGE'
    gsd-rtk-runtime

    Usage:
      gsd-rtk-runtime --print-env
      gsd-rtk-runtime -- <command> [args...]

    Purpose:
      Runs a command with gsd pointed at the packaged RTK binary, without allowing
      gsd's postinstall/runtime bootstrap to download RTK into ~/.gsd/agent/bin.
    USAGE
        exit 0
        ;;
      --print-env)
        print_env
        exit 0
        ;;
      --)
        shift
        ;;
    esac

    if [ "$#" -eq 0 ]; then
      exec "$runtime_root/bin/rtk" --help
    fi

    exec "$@"
    EOF
        chmod +x "$out/bin/gsd-rtk-runtime"
  '';

  meta = with pkgs.lib; {
    description = "Source-built RTK runtime helper for gsd-2";
    homepage = "https://github.com/rtk-ai/rtk";
    license = licenses.mit;
    platforms = platforms.unix;
    mainProgram = "rtk";
  };
}
