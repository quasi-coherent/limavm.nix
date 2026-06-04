{
  coreutils,
  callPackage,
  den,
  host,
  lib,
  lima,
  writeShellApplication,
}:
let
  vmBuilt = host.instantiate {
    inherit (host) system;
    modules = [
      ../lima.nix
      (den.lib.aspects.resolve host.class (den.lib.resolveEntity "host" { inherit host; }))
    ];
  };
  limaYaml = vmBuilt.config.system.build.limaYaml;
in
callPackage ./limactl.nix {
  inherit
    coreutils
    lib
    lima
    limaYaml
    writeShellApplication
    ;
  name = host.name;
}
