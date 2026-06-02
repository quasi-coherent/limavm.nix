{
  den,
  inputs,
  lib,
  self,
  ...
}:
let
  # `lima.standalone` keys consumed here rather than projected into the
  # nixos config — strip before injecting `{ lima = …; }`.
  standaloneMeta = [
    "enable"
    "runnerSystems"
  ];

  # Default places to emit the wrapper: the guest's arch on both
  # darwin and linux. `limactl` runs on the host (not the guest), so
  # the wrapper package must live under a system the user actually
  # invokes `nix run` from.
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
      standaloneSettings = removeAttrs (host.lima.standalone or { }) standaloneMeta;
      runnerSystems = host.lima.standalone.runnerSystems or (defaultRunnerSystems host.system);

      vmResolved = den.lib.aspects.resolve host.class (den.lib.resolveEntity "host" { inherit host; });

      vmBuilt = host.instantiate {
        inherit (host) system;
        modules = [
          self.nixosModules.lima
          { lima = standaloneSettings; }
          vmResolved
        ];
      };

      limaYaml = vmBuilt.config.system.build.limaYaml;
      limaImage = vmBuilt.config.system.build.limaImage;

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
    if !(host.lima.standalone.enable or false) then
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
    (map mkLimaPkg)
    (lib.foldl' lib.recursiveUpdate { })
  ];
in
{
  flake.packages = limaPkgs;
}
