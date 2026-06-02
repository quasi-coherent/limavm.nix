{
  den,
  lib,
  ...
}:
{
  # Needs to be here to register as a class with the den pipeline.
  den.classes.lima.description = "Lima VM guest configuration";

  # Run each entry as a Lima guest on the including host.
  den.batteries.limaGuests = {
    description = "Run a list of den hosts as Lima guests on this host.";
    __functor =
      _self: guests:
      { host, ... }:
      {
        name = "limaGuests";

        ${host.class} = {
          imports = [
            ../host.nix
            ../lib/${host.class}-host.nix
          ];
          lima.vms = lib.listToAttrs (
            map (
              g:
              lib.nameValuePair g.name {
                yaml =
                  (g.instantiate {
                    inherit (g) system;
                    modules = [
                      ../lima.nix
                      (den.lib.aspects.resolve "nixos" (den.lib.resolveEntity "host" { host = g; }))
                    ];
                  }).config.system.build.limaYaml;
              }
            ) guests
          );
        };
      };
  };

  # Expose the including host as a Lima guest via at the package
  # `flake.packages.<runnerSys>.<host.name>`.
  den.batteries.toLima = {
    description = "Expose this host as a runnable Lima guest (flake.packages.<sys>.<name>).";
    __functor =
      _self: settings:
      { host, ... }:
      {
        name = "toLima";
        ${host.class} = {
          imports = [ ../lima.nix ];
          lima = settings // {
            runner = true;
          };
        };
      };
  };
}
