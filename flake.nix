{
  description = "Nix packaging for gsd-build/gsd-2 with split components, optional runtime helpers, and host modules";

  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    fenix = {
      url = "github:nix-community/fenix/monthly";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    git-hooks-nix = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      self,
      flake-parts,
      git-hooks-nix,
      treefmt-nix,
      ...
    }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" ];

      imports = [
        treefmt-nix.flakeModule
        git-hooks-nix.flakeModule
        ./pkgs/gsd-2/default.nix
        ./apps/default.nix
        ./checks/gsd-2.nix
      ];

      perSystem =
        {
          config,
          pkgs,
          system,
          ...
        }:
        let
          fenixPkgs = inputs.fenix.packages.${system};
          rustToolchain =
            with fenixPkgs;
            combine (
              with latest;
              [
                cargo
                rust-src
                rustc
              ]
            );
        in
        {
          treefmt = {
            programs = {
              nixfmt.enable = true;
              prettier = {
                enable = true;
                settings = {
                  printWidth = 100;
                  proseWrap = "preserve";
                };
              };
              ruff-format.enable = true;
              shfmt.enable = true;
            };
          };

          pre-commit.settings.hooks.treefmt.enable = true;

          devShells.default = pkgs.mkShellNoCC {
            packages = with pkgs; [
              git
              config.treefmt.build.wrapper
              config.pre-commit.settings.package
              ripgrep
              rustToolchain
            ];
            shellHook = config.pre-commit.shellHook;
          };
        };

      flake = {
        nixosModules = {
          default = import ./modules/nixos/default.nix self;
          gsd = import ./modules/nixos/default.nix self;
        };
        homeManagerModules = {
          default = import ./modules/home-manager/default.nix self;
          gsd = import ./modules/home-manager/default.nix self;
        };
      };
    };
}
