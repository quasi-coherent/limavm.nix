{
  den,
  inputs,
  lib,
  ...
}:
let
  # Default places to emit the wrapper: the guest's arch on both darwin
  # and linux. `limactl` runs on the host (not the guest), so the wrapper
  # must live under a system the user actually invokes `nix run` from.
  defaultRunnerSystems =
    guestSystem:
    let
      arch = lib.head (lib.splitString "-" guestSystem);
    in
    [
      "${arch}-darwin"
      "${arch}-linux"
    ];

  mkLimaPkg =
    host:
    let
      vmBuilt = host.instantiate {
        inherit (host) system;
        modules = [
          ../lima.nix
          (den.lib.aspects.resolve host.class (den.lib.resolveEntity "host" { inherit host; }))
        ];
      };

      cfg = vmBuilt.config.lima;
      limaYaml = vmBuilt.config.system.build.limaYaml;
      limaImage = vmBuilt.config.system.build.limaImage;

      runnerSystems =
        if cfg.runnerSystems != [ ] then cfg.runnerSystems else defaultRunnerSystems host.system;

      runnerFor =
        runnerSystem:
        let
          pkgs = inputs.nixpkgs.legacyPackages.${runnerSystem};
        in
        pkgs.writeShellApplication {
          name = host.name;
          runtimeInputs = [ pkgs.lima ];
          text = ''
            ${pkgs.coreutils}/bin/true ${limaImage}
            exec limactl start --tty=false --name=${host.name} ${limaYaml}
          '';
        };
    in
    if !cfg.runner then
      { }
    else
      lib.listToAttrs (
        map (sys: {
          name = sys;
          value.${host.name} = runnerFor sys;
        }) runnerSystems
      );

  limaPkgs = lib.pipe den.hosts [
    lib.attrValues
    (lib.concatMap lib.attrValues)
    (lib.filter (h: h.class == "nixos"))
    (map mkLimaPkg)
    (lib.foldl' lib.recursiveUpdate { })
  ];
in
{
  flake.packages = limaPkgs;
}
