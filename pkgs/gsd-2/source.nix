{ fetchFromGitHub }:
let
  version = "2.67.0";
in
{
  inherit version;
  playwrightVersion = "1.58.2";
  rtkVersion = "0.33.1";
  rtkSrcHash = "sha256-QkAtxSpMyjbscQgSUWks0aIkWaAYXgY6c9qM3sdPN+0=";
  rootNpmDepsHash = "sha256-NPrfUiBVlo8/tDqCPlbqNSvlXE4GAOOS9/P5mHxnRoM=";
  webNpmDepsHash = "sha256-TITFRG9tlDTMyvG5ohhgpjVARJIeVraWCzwWSRZ3MWw=";

  commonEnv = {
    CI = "1";
    GSD_SKIP_RTK_INSTALL = "1";
    NEXT_TELEMETRY_DISABLED = "1";
    PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD = "1";
  };

  src = fetchFromGitHub {
    owner = "gsd-build";
    repo = "gsd-2";
    rev = "v${version}";
    hash = "sha256-HL1CDdLv13T4/sNS+qH5pERN8qoFuO1YIeY1eJENFoY=";
  };

  patchSet = {
    webLocalFonts = ../../patches/web-local-fonts.patch;
    noNetworkPostinstall = ../../patches/no-network-postinstall.patch;
    standaloneSymlinkFix = ../../patches/standalone-symlink-fix.patch;
  };
}
