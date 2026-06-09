{
  den,
  lib,
  ...
}:
{
  # For registration with den's resolution pipeline.
  den.classes.lima.description = "Lima VM guest configuration";

  den.batteries.limaGuests = {
    description = "Run a list of den hosts as Lima guests on this host.";
    __functor =
      _self: guests:
      { host, ... }:
      {
        name = "limaGuests";

        ${host.class} = {
          imports = [
            ../modules/${host.class}.nix
          ];
          services.limavm-nix = {
            enable = true;
            vms = lib.listToAttrs (
              map (
                g:
                lib.nameValuePair g.name {
                  guest = {
                    inherit (g) system;
                    modules = [
                      (den.lib.aspects.resolve "nixos" (den.lib.resolveEntity "host" { host = g; }))
                    ];
                  };
                }
              ) guests
            );
          };
        };
      };
  };

  den.batteries.toLima = {
    description = "Expose this host as a runnable Lima guest (flake.packages.<sys>.<name>).";
    __functor =
      _self: settings:
      { host, ... }:
      {
        name = "toLima";
        ${host.class} = {
          imports = [
            ../options.nix
            ../lima.nix
          ];
          lima = settings // {
            runner = true;
          };
        };
      };
  };
}
