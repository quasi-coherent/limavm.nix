{
  coreutils,
  den,
  host,
  lib,
  lima,
  writeShellApplication,
}:
let
  lctl =
    limaYaml: name:
    (import ./limactl {
      inherit
        coreutils
        lib
        lima
        limaYaml
        name
        writeShellApplication
        ;
    });

  vmBuilt = host.instantiate {
    inherit (host) system;
    modules = [
      ../lima.nix
      (den.lib.aspects.resolve host.class (den.lib.resolveEntity "host" { inherit host; }))
    ];
  };
  limaYaml = vmBuilt.config.system.build.limaYaml;
  limaPkg = lctl limaYaml host.name;
in
limaPkg
