{
  pkgs,
  den,
  host,
}:
let
  vmBuilt = host.instantiate {
    inherit (host) system;
    modules = [
      # Inject option definitions only so `config.lima.runner` is always
      # readable. The user's `toLima` battery is what flips it to true and
      # imports the rest of the guest module.
      ../options.nix
      (den.lib.aspects.resolve host.class (den.lib.resolveEntity "host" { inherit host; }))
    ];
  };
in
if !vmBuilt.config.lima.runner then
  null
else
  import ./mk-guest-packages.nix {
    inherit pkgs;
    name = host.name;
    nixosSystem = vmBuilt;
  }
