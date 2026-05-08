self:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.gsd;
  packages = self.packages.${pkgs.stdenv.hostPlatform.system};
  runtimeEnv =
    lib.optionalAttrs cfg.playwright.enable {
      PLAYWRIGHT_BROWSERS_PATH = "${cfg.playwright.package}/share/gsd-2-playwright-runtime/browsers";
      PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD = "1";
      PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS = "true";
    }
    // lib.optionalAttrs cfg.rtk.enable {
      GSD_RTK_PATH = "${cfg.rtk.package}/bin/rtk";
      GSD_SKIP_RTK_INSTALL = "1";
      RTK_TELEMETRY_DISABLED = "1";
    }
    // cfg.extraSessionVariables;
in
{
  options.programs.gsd = {
    enable = lib.mkEnableOption "the gsd package set";

    package = lib.mkOption {
      type = lib.types.package;
      default = packages."gsd-2";
      description = "Primary gsd meta package to install.";
    };

    playwright.enable = lib.mkEnableOption "install the Playwright runtime package and export the browser runtime environment for gsd";

    playwright.package = lib.mkOption {
      type = lib.types.package;
      default = packages."gsd-2-playwright-runtime";
      description = "Playwright runtime package used when programs.gsd.playwright.enable is enabled.";
    };

    rtk.enable = lib.mkEnableOption "install the RTK helper package and export the RTK runtime environment for gsd";

    rtk.package = lib.mkOption {
      type = lib.types.package;
      default = packages."gsd-2-rtk";
      description = "RTK package used when programs.gsd.rtk.enable is enabled.";
    };

    extraPackages = lib.mkOption {
      type = with lib.types; listOf package;
      default = [ ];
      description = "Additional packages to install with the gsd-2 package set.";
    };

    extraSessionVariables = lib.mkOption {
      type = with lib.types; attrsOf str;
      default = { };
      description = "Extra session variables to export alongside the gsd runtime environment.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      cfg.package
    ]
    ++ lib.optionals cfg.playwright.enable [ cfg.playwright.package ]
    ++ lib.optionals cfg.rtk.enable [ cfg.rtk.package ]
    ++ cfg.extraPackages;

    home.sessionVariables = runtimeEnv;
  };
}
