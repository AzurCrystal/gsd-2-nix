{ fetchFromGitHub }:
let
  version = "2.66.1";
in
{
  inherit version;
  playwrightVersion = "1.58.2";
  rtkVersion = "0.33.1";
  rtkSrcHash = "sha256-QkAtxSpMyjbscQgSUWks0aIkWaAYXgY6c9qM3sdPN+0=";
  rootNpmDepsHash = "sha256-HSxGd+DdqQChEXCV1NUt2W998RbJUKeY2RAecREqPFY=";
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
    hash = "sha256-iKjGyJfcPsZF/fw2gsMg80lJCTtWd8EvkQfNw6T5F/Q=";
  };

  patchSet = {
    webLocalFonts = ../../patches/web-local-fonts.patch;
    noNetworkPostinstall = ../../patches/no-network-postinstall.patch;
    standaloneSymlinkFix = ../../patches/standalone-symlink-fix.patch;
  };
}
