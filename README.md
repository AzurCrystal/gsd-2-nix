# `gsd-2-nix`

`gsd-2-nix` packages [`gsd-build/gsd-2`](https://github.com/gsd-build/gsd-2)
as a split `flake-parts` project with one simple public entrypoint and several
optional runtime/helper lanes.

Repository: <https://github.com/AzurCrystal/gsd-2-nix>

The guiding idea is:

- downstream users should usually only need `packages.${system}.gsd-2`
- the packaging internals can still stay explicit and decomposed
- runtime helpers such as Playwright browsers and RTK can stay optional rather
  than bloating the default closure

## Status

This repository is already in a usable state for Linux packaging work:

- the main `gsd` CLI is built from upstream source
- the standalone web lane is built from upstream source
- the native engine is built locally with Rust via `fenix`
- companion CLIs (`gsd-mcp-server`, `gsd-daemon`, `gsd-rpc-client`) are built
  from upstream source
- Playwright and RTK no longer rely on upstream postinstall downloads when used
  through the packaged helper lanes
- flake checks include both structure checks and runtime smoke checks

What is still intentionally open:

- whether optional runtime helpers should remain separate helper packages or
  move deeper into host/service integration
- how far NixOS/Home Manager integration should go beyond package install plus
  runtime environment wiring

## What This Repository Provides

Public package outputs:

- `packages.${system}.gsd-2`
  Default user-facing meta package.
- `packages.${system}.gsd-2-suite`
  Convenience meta package that bundles the default package with companion CLIs
  and optional runtime helper lanes.
- `packages.${system}.gsd-2-core`
  Core CLI/runtime layer.
- `packages.${system}.gsd-2-web`
  Standalone web-host layer.
- `packages.${system}.gsd-2-playwright-runtime`
  Helper package that wires packaged Playwright browser artifacts into `gsd`.
- `packages.${system}.gsd-2-rtk`
  Source-built RTK plus a small `gsd` runtime wrapper.
- `packages.${system}.gsd-mcp-server`
  MCP server companion CLI.
- `packages.${system}.gsd-daemon`
  Daemon companion CLI.
- `packages.${system}.gsd-rpc-client`
  RPC client companion SDK/CLI lane.

Public module outputs:

- `nixosModules.gsd`
  NixOS module exposing `programs.gsd.*`.
- `homeManagerModules.gsd`
  Home Manager module exposing the same `programs.gsd.*` surface.

## Packaging Shape

The package graph is deliberately split:

1. `source`
2. `root-modules`
3. `built-tree`
4. `native-engine`
5. `web-modules`
6. `web`
7. `core`
8. `meta`

Companion packages and helper runtimes sit beside that main path instead of
being hidden inside one giant derivation.

## Quick Start

Inspect outputs:

```bash
nix flake show
```

Use it as a flake input:

```nix
{
  inputs.gsd-2-nix.url = "github:AzurCrystal/gsd-2-nix";
}
```

Run the default CLI:

```bash
nix run .#gsd-2 -- --version
```

Build the broader package set:

```bash
nix build .#gsd-2-suite
```

Run browser-tools with packaged Playwright browsers:

```bash
nix shell .#gsd-2 .#gsd-2-playwright-runtime \
  -c gsd-playwright-runtime -- gsd ...
```

Run `gsd` with packaged RTK support:

```bash
nix shell .#gsd-2 .#gsd-2-rtk \
  -c gsd-rtk-runtime -- gsd ...
```

## Validation

`nix flake check` currently covers three layers:

- package-graph and layout assertions
- runtime smoke checks for browser-tools and RTK integration
- companion smoke checks for `gsd-mcp-server` and `gsd-daemon`

## Cachix

GitHub Actions can push build outputs into the `azurcrystal` Cachix cache. For
local use, configure the substituter directly or use the manual Nix settings
snippet below:

```bash
nix profile install --accept-flake-config nixpkgs#cachix
```

If you prefer to configure Nix manually, add the Cachix substituter and public
key for `azurcrystal` to `nix.settings`:

```nix
{
  nix.settings.substituters = [
    "https://azurcrystal.cachix.org"
  ];
  nix.settings.trusted-public-keys = [
    "azurcrystal.cachix.org-1:Hapo2wSReDyg2S7Veo7P5JzqQERYV3qj3I1kGbXCNyA="
  ];
}
```

The flake inputs are maintained separately through a dedicated `flake.lock`
refresh workflow, so package-source updates and input updates stay reviewable
on their own.

## Module Usage

Both module entrypoints use the `programs.gsd` prefix.

Example NixOS usage:

```nix
{
  imports = [
    inputs.gsd-2-nix.nixosModules.gsd
  ];

  programs.gsd = {
    enable = true;
    mcpServer.enable = true;
    daemon.enable = true;
    playwright.enable = true;
    rtk.enable = true;
  };
}
```

Example Home Manager usage:

```nix
{
  imports = [
    inputs.gsd-2-nix.homeManagerModules.gsd
  ];

  programs.gsd = {
    enable = true;
    playwright.enable = true;
    rtk.enable = true;
  };
}
```
