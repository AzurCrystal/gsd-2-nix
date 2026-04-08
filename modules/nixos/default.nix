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

    mcpServer.enable = lib.mkEnableOption "install the gsd MCP server companion package";

    mcpServer.package = lib.mkOption {
      type = lib.types.package;
      default = packages."gsd-mcp-server";
      description = "MCP server package used when programs.gsd.mcpServer.enable is enabled.";
    };

    daemon.enable = lib.mkEnableOption "install the gsd daemon companion package";

    daemon.package = lib.mkOption {
      type = lib.types.package;
      default = packages."gsd-daemon";
      description = "Daemon package used when programs.gsd.daemon.enable is enabled.";
    };

    rpcClient.enable = lib.mkEnableOption "install the gsd RPC client companion package";

    rpcClient.package = lib.mkOption {
      type = lib.types.package;
      default = packages."gsd-rpc-client";
      description = "RPC client package used when programs.gsd.rpcClient.enable is enabled.";
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
    environment.systemPackages =
      [ cfg.package ]
      ++ lib.optionals cfg.mcpServer.enable [ cfg.mcpServer.package ]
      ++ lib.optionals cfg.daemon.enable [ cfg.daemon.package ]
      ++ lib.optionals cfg.rpcClient.enable [ cfg.rpcClient.package ]
      ++ lib.optionals cfg.playwright.enable [ cfg.playwright.package ]
      ++ lib.optionals cfg.rtk.enable [ cfg.rtk.package ]
      ++ cfg.extraPackages;

    environment.sessionVariables = runtimeEnv;
  };
}
