{ pkgs, rustToolchain, sourceInfo ? import ./source.nix { inherit (pkgs) fetchFromGitHub; } }:
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
    inherit builtTree nativeEngine pkgs sourceInfo webModules;
  };

  core = import ./core.nix {
    inherit builtTree nativeEngine pkgs sourceInfo web;
  };

  playwrightRuntime = import ./playwright-runtime.nix {
    inherit pkgs sourceInfo;
  };

  rtk = import ./rtk.nix {
    inherit pkgs rustToolchain sourceInfo;
  };

  rpcClient = import ./companions/rpc-client.nix {
    inherit companionsTree pkgs sourceInfo;
  };

  mcpServer = import ./companions/mcp-server.nix {
    inherit companionsTree pkgs sourceInfo;
  };

  daemon = import ./companions/daemon.nix {
    inherit companionsTree pkgs sourceInfo;
  };

  graphData = {
    version = sourceInfo.version;
    phase = {
      current = 3;
      implemented = [
        "gsd-2-root-modules"
        "gsd-2-built-tree"
        "gsd-2-core"
        "gsd-2-web-modules"
        "gsd-2-web"
        "gsd-2-native-engine"
        "gsd-2-playwright-runtime"
        "gsd-2-rtk"
        "gsd-2-companions-tree"
        "gsd-rpc-client"
        "gsd-mcp-server"
        "gsd-daemon"
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
      "gsd-2-core"
      "gsd-2-web"
      "gsd-2-playwright-runtime"
      "gsd-2-rtk"
      "gsd-mcp-server"
      "gsd-daemon"
      "gsd-rpc-client"
    ];
    composition = {
      "gsd-2" = [
        "gsd-2-core"
        "gsd-2-web"
        "gsd-2-native-engine"
      ];
      "gsd-2-suite" = [
        "gsd-2"
        "gsd-mcp-server"
        "gsd-daemon"
        "gsd-2-playwright-runtime"
        "gsd-2-rtk"
      ];
    };
  };

  graphJson = builtins.toJSON graphData;

  meta = import ./meta.nix {
    inherit
      componentLib
      core
      graphJson
      nativeEngine
      sourceInfo
      web
      ;
  };

  suite = componentLib.mkMetaPackage {
    pname = "gsd-2-suite";
    version = sourceInfo.version;
    paths = [
      meta
      daemon
      mcpServer
      playwrightRuntime
      rpcClient
      rtk
    ];
    summary = "Extended gsd-2 suite meta package that includes companion CLIs and optional runtime helper lanes.";
    details = [
      "Built to make end-to-end host experimentation easier while the real package graph is still being implemented."
      "Not intended to be the default public dependency surface for downstream callers."
    ];
    files = {
      "suite-layout.txt" = ''
        suite package:
        - gsd-2
        - gsd-mcp-server
        - gsd-daemon
        - gsd-rpc-client
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
    "gsd-2" = meta;
    "gsd-2-suite" = suite;
    "gsd-2-core" = core;
    "gsd-2-web" = web;
    "gsd-2-playwright-runtime" = playwrightRuntime;
    "gsd-2-rtk" = rtk;
    "gsd-mcp-server" = mcpServer;
    "gsd-daemon" = daemon;
    "gsd-rpc-client" = rpcClient;
  };
}
