{
  den,
  lib,
  ...
}:
{
  # For registration with den's resolution pipeline.
  den.classes.limaGuest.description = "Lima VM guest configuration";

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
                  guest.modules = [
                    (den.lib.aspects.resolve "nixos" (den.lib.resolveEntity "host" { host = g; }))
                    (den.lib.aspects.resolve "limaGuest" (den.lib.resolveEntity "host" { host = g; }))
                  ];
                }
              ) guests
            );
          };
        };
      };
  };

  den.batteries.limaPackages = {
    description = "Expose this host as a runnable Lima guest (flake.packages.<sys>.<name>).";
    __functor =
      _self:
      { host, ... }:
      {
        name = "limaPackages";

        ${host.class} = {
          imports = [
            ../lima.nix
            (den.lib.aspects.resolve "limaGuest" (den.lib.resolveEntity "host" { inherit host; }))
          ];
          lima.enabledForDenHost = true;
        };
      };
  };
}
