{
  pkgs,
  rustToolchain,
  sourceInfo ? import ./source.nix { inherit (pkgs) fetchFromGitHub; },
}:
let
  componentLib = import ./component-lib.nix {
    inherit (pkgs) lib stdenvNoCC symlinkJoin;
  };

  rootModules = import ./root-modules.nix {
    inherit pkgs sourceInfo;
  };

  builtTree = import ./built-tree.nix {
    inherit pkgs rootModules sourceInfo;
  };

  companionsTree = import ./companions/tree.nix {
    inherit builtTree pkgs sourceInfo;
  };

  nativeEngine = import ./native-engine.nix {
    inherit pkgs rustToolchain sourceInfo;
  };

  webModules = import ./web-modules.nix {
    inherit pkgs sourceInfo;
  };

  web = import ./web.nix {
    inherit
      builtTree
      nativeEngine
      pkgs
      sourceInfo
      webModules
      ;
  };

  graphData = {
    version = sourceInfo.version;
    phase = {
      current = 4;
      implemented = [
        "gsd-2-root-modules"
        "gsd-2-built-tree"
        "gsd-2-unified-runtime"
        "gsd-2-web-modules"
        "gsd-2-web-stage"
        "gsd-2-native-engine"
        "gsd-2-playwright-runtime"
        "gsd-2-rtk"
        "gsd-2-companions-tree"
      ];
      placeholders = [ ];
    };
    source = {
      upstream = "gsd-build/gsd-2";
    };
    internalComponents = [
      "gsd-2-root-modules"
      "gsd-2-built-tree"
      "gsd-2-companions-tree"
      "gsd-2-native-engine"
      "gsd-2-web-modules"
    ];
    publicPackages = [
      "gsd-2"
      "gsd-2-suite"
      "gsd-2-playwright-runtime"
      "gsd-2-rtk"
    ];
    composition = {
      "gsd-2" = [
        "root-cli"
        "mcp-server"
        "daemon"
        "rpc-client"
        "web"
        "native-engine"
      ];
      "gsd-2-suite" = [
        "gsd-2"
        "gsd-2-playwright-runtime"
        "gsd-2-rtk"
      ];
    };
  };

  graphJson = builtins.toJSON graphData;

  core = import ./core.nix {
    inherit
      builtTree
      companionsTree
      graphJson
      nativeEngine
      pkgs
      sourceInfo
      web
      ;
  };

  playwrightRuntime = import ./playwright-runtime.nix {
    inherit pkgs rootModules sourceInfo;
  };

  rtk = import ./rtk.nix {
    inherit pkgs rustToolchain sourceInfo;
  };

  suite = componentLib.mkMetaPackage {
    pname = "gsd-2-suite";
    version = sourceInfo.version;
    paths = [
      playwrightRuntime
      rtk
      core
    ];
    summary = "Extended gsd-2 suite meta package that includes optional runtime helper lanes.";
    details = [
      "Combines the unified gsd-2 core package with Playwright browser artifacts and RTK helper tooling."
      "Useful for hosts that want the full local runtime closure available from one profile entry."
    ];
    files = {
      "suite-layout.txt" = ''
        suite package:
        - gsd-2
        - gsd-2-playwright-runtime
        - gsd-2-rtk
      '';
    };
  };
in
{
  inherit graphData graphJson;

  internalPackages = {
    "gsd-2-root-modules" = rootModules;
    "gsd-2-built-tree" = builtTree;
    "gsd-2-companions-tree" = companionsTree;
    "gsd-2-native-engine" = nativeEngine;
    "gsd-2-web-modules" = webModules;
  };

  publicPackages = {
    "gsd-2" = core;
    "gsd-2-suite" = suite;
    "gsd-2-playwright-runtime" = playwrightRuntime;
    "gsd-2-rtk" = rtk;
  };
}
