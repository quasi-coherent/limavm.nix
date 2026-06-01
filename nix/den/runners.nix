{
  den,
  lib,
  inputs,
  ...
}:
let
  # Expose `packages.<system>.<name>` for each den host with
  # `lima.standalone.enable = true`. The runner invokes `limactl start`
  # against the guest's built lima.yaml.
  buildRunner =
    host:
    let
      vmResolved = den.lib.aspects.resolve host.class (
        den.lib.resolveEntity "host" { host = host; }
      );
      vmBuilt = host.instantiate {
        inherit (host) system;
        modules = [ vmResolved ];
      };
      limaYaml = vmBuilt.config.system.build.limaYaml;
      limaImage = vmBuilt.config.system.build.limaImage;
      pkgs = import inputs.nixpkgs { inherit (host) system; };
    in
    if !(host.lima.standalone.enable or false) then
      { }
    else
      {
        ${host.system}.${host.name} = pkgs.writeShellApplication {
          name = host.name;
          runtimeInputs = [ pkgs.lima ];
          text = ''
            ${pkgs.coreutils}/bin/true ${limaImage}
            exec limactl start --tty=false --name=${host.name} ${limaYaml}
          '';
        };
      };

  runnersBySystem = lib.pipe den.hosts [
    lib.attrValues
    (lib.concatMap lib.attrValues)
    (map buildRunner)
    (lib.foldl' lib.recursiveUpdate { })
  ];
in
{
  flake.packages = runnersBySystem;
}
