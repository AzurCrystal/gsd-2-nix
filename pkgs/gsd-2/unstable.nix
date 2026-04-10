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

      sourceInfo = import ./source-unstable.nix {
        inherit (pkgs) fetchFromGitHub;
      };

      graph = import ./graph.nix {
        inherit pkgs rustToolchain sourceInfo;
      };
    in
    {
      packages = {
        "gsd-2-unstable" = graph.publicPackages."gsd-2";
        "gsd-2-unstable-suite" = graph.publicPackages."gsd-2-suite";
      };
    };
}
