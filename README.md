# `gsd-2-nix`

`gsd-2-nix` packages [`gsd-build/gsd-2`](https://github.com/gsd-build/gsd-2)
as a `flake-parts` project with one unified GSD package and a small number of
optional runtime/helper lanes.

Repository: <https://github.com/AzurCrystal/gsd-2-nix>

The guiding idea is:

- downstream users should usually only need `packages.${system}.gsd-2`
- the core runtime stays together in one package root because the CLI, MCP
  server, daemon, RPC client, web host, and native engine are one product
  boundary
- runtime helpers such as Playwright browsers and RTK can stay optional rather
  than bloating the default closure

## Status

This repository is already in a usable state for Linux packaging work:

- the main `gsd` CLI, `gsd-mcp-server`, `gsd-daemon`, RPC client package, web
  host, and native engine are installed into one unified `gsd-2` runtime root
- the native engine is built locally with Rust via `fenix`
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
  Default user-facing package. Includes `gsd`, `gsd-cli`, `gsd-mcp-server`,
  `gsd-daemon`, `@gsd-build/rpc-client`, the web host, and the native engine in
  one package root.
- `packages.${system}.gsd-2-suite`
  Convenience meta package that bundles the unified package with optional
  Playwright and RTK helper lanes.
- `packages.${system}.gsd-2-playwright-runtime`
  Helper package that wires packaged Playwright browser artifacts into `gsd`.
- `packages.${system}.gsd-2-rtk`
  Source-built RTK plus a small `gsd` runtime wrapper.

Public module outputs:

- `nixosModules.gsd`
  NixOS module exposing `programs.gsd.*`.
- `homeManagerModules.gsd`
  Home Manager module exposing the same `programs.gsd.*` surface.

## Packaging Shape

The build graph is still explicit internally, but the public core runtime is
not split into independently-installed pieces:

1. `source`
2. `root-modules`
3. `built-tree`
4. `native-engine`
5. `web-modules`
6. `web`
7. `core`
8. `gsd-2`

The companion workspace packages are compiled in an internal step and installed
back into the single `gsd-2` package root. Playwright browser artifacts and RTK
remain separate helper packages because they are optional host/runtime
attachments.

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
- MCP server and daemon smoke checks from the unified `gsd-2` package

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
