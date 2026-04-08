{ lib, ... }:
{
  perSystem =
    { config, ... }:
    {
      apps.default = {
        type = "app";
        program = lib.getExe config.packages."gsd-2";
        meta.description = "Run the primary gsd-2 package";
      };

      apps.gsd-2 = config.apps.default;
    };
}
