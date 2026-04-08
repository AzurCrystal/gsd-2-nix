{ fetchFromGitHub }:
let
  version = "2.65.0";
in
{
  inherit version;
  playwrightVersion = "1.58.2";
  rtkVersion = "0.33.1";
  rtkSrcHash = "sha256-QkAtxSpMyjbscQgSUWks0aIkWaAYXgY6c9qM3sdPN+0=";
  rootNpmDepsHash = "sha256-ymhQQ87/eSNTG9VRkHmj6/ei8/XVtJ/Fiy33BEcKVco=";
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
    hash = "sha256-SaSyn8DEKSATkIg4ed0EfRr8B+Gk72R5rQkh1KoNgl8=";
  };

  patchSet = {
    webLocalFonts = ../../patches/web-local-fonts.patch;
    noNetworkPostinstall = ../../patches/no-network-postinstall.patch;
    standaloneSymlinkFix = ../../patches/standalone-symlink-fix.patch;
  };
}
