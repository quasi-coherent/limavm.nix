{
  pkgs,
  lib,
  den,
  host,
}:
let
  vmBuilt = host.instantiate {
    inherit (host) system;
    modules = [
      ../options.nix
      ../lima.nix
      (den.lib.aspects.resolve host.class (den.lib.resolveEntity "host" { inherit host; }))
    ];
  };
  guestCfg = vmBuilt.config.lima;
  settings = vmBuilt.config.system.build.limaSettings;
  image =
    if builtins.isString guestCfg.image then guestCfg.image else vmBuilt.config.system.build.limaImage;
  lima-lib = import ./. { inherit lib; };
in
lima-lib.mkGuestPackages {
  inherit pkgs settings image;
  name = host.name;
  inherit (guestCfg) arch;
}
