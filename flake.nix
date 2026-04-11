{
  description = "Nix packaging for gsd-build/gsd-2 with split components, optional runtime helpers, and host modules";

  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    fenix = {
      url = "github:nix-community/fenix/monthly";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs =
    inputs@{
      self,
      flake-parts,
      ...
    }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" ];

      imports = [
        ./pkgs/gsd-2/default.nix
        ./pkgs/gsd-2/unstable.nix
        ./apps/default.nix
        ./checks/gsd-2.nix
      ];

      perSystem =
        { pkgs, system, ... }:
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
          formatter = pkgs.nixfmt;

          devShells.default = pkgs.mkShellNoCC {
            packages = with pkgs; [
              git
              nixfmt
              ripgrep
              rustToolchain
            ];
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
