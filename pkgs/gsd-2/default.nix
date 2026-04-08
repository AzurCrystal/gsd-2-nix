{ ... }:
{
  perSystem =
    { pkgs, inputs', ... }:
    let
      rustToolchain =
        with inputs'.fenix.packages;
        combine (
          with latest;
          [
            cargo
            rust-src
            rustc
          ]
        );

      graph = import ./graph.nix {
        inherit pkgs rustToolchain;
      };
    in
    {
      packages = graph.publicPackages;
    };
}
