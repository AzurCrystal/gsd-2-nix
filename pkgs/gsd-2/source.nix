{ fetchFromGitHub }:
let
  sourceInfo = builtins.fromJSON (builtins.readFile ./source.json);
in
sourceInfo
// {
  commonEnv = {
    CI = "1";
    GSD_SKIP_RTK_INSTALL = "1";
    NEXT_TELEMETRY_DISABLED = "1";
    PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD = "1";
  };

  src = fetchFromGitHub {
    owner = "gsd-build";
    repo = "gsd-2";
    rev = "v${sourceInfo.version}";
    hash = sourceInfo.srcHash;
  };

  patchSet = {
    webLocalFonts = ../../patches/web-local-fonts.patch;
    noNetworkPostinstall = ../../patches/no-network-postinstall.patch;
    standaloneSymlinkFix = ../../patches/standalone-symlink-fix.patch;
  };
}
