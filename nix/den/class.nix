# https://github.com/denful/den/blob/294d58404758df423e0332646a241b98ed087d78/templates/microvm/README.md
{ den, lib, ... }:
let
  inherit (den.lib.policy) resolve include provide;

  guestModule = ../limavm;

  hostClassToHostModule =
    class:
    if class == "darwin" then
      ../host/darwin.nix
    else if class == "nixos" then
      ../host/nixos.nix
    else
      throw "lima: unsupported host class '${class}' (expected darwin or nixos)";

  extendHostSchema =
    { host, ... }:
    {
      options.lima.module = lib.mkOption {
        description = "Lima guest";
        type = lib.types.deferredModule;
        default = guestModule;
      };

      options.lima.hostModule = lib.mkOption {
        description = ''
          Module merged into the host's class providing the orchestrator
          (launchd agents on darwin, systemd services on nixos) that
          consumes config.lima.vms.<name>.
        '';
        type = lib.types.deferredModule;
        default = hostClassToHostModule host.class;
      };

      options.lima.guests = lib.mkOption {
        type = lib.types.listOf lib.types.raw;
        default = [ ];
        description = ''
          Guest Lima VMs declared as den hosts, e.g.
            [ den.hosts.aarch64-linux.work-vm ]

          When non-empty, the host imports lima.hostModule and starts the
          lima-host context pipeline.
        '';
      };
    };
in
{
  den.classes.lima.description = "Lima VM guest configuration (limavm options)";

  den.policies.host-to-lima-host =
    { host, ... }:
    lib.optionals (host.lima.guests != [ ]) [
      (resolve.to "lima-host" { inherit host; })
      (include (
        { host }:
        {
          ${host.class}.imports = [ host.lima.hostModule ];
        }
      ))
    ];

  den.policies.lima-host-to-lima-guest =
    { host, ... }:
    lib.concatMap (vm: [
      (resolve.to "lima-guest" { inherit host vm; })
    ]) host.lima.guests;

  den.policies.lima-guest-resolve-vm =
    { host, vm, ... }:
    let
      vmResolved = den.lib.aspects.resolve vm.class (den.lib.resolveEntity "host" { host = vm; });
      limaResolved = den.lib.aspects.resolve "lima" vm.aspect;

      guestModuleImport = provide {
        class = vm.class;
        path = [ ];
        module =
          { ... }:
          {
            imports = [ host.lima.module ];
          };
      };

      osProvide = provide {
        class = host.class;
        path = [
          "lima"
          "vms"
          vm.name
          "config"
        ];
        module = _: vmResolved;
      };

      limaProvide = provide {
        class = host.class;
        path = [
          "lima"
          "vms"
          vm.name
        ];
        module = _: limaResolved;
      };
    in
    [
      guestModuleImport
      osProvide
      limaProvide
    ];

  den.schema.host.includes = [ den.policies.host-to-lima-host ];
  den.schema.lima-host.includes = [ den.policies.lima-host-to-lima-guest ];
  den.schema.lima-guest.includes = [ den.policies.lima-guest-resolve-vm ];
  den.schema.host.imports = [ extendHostSchema ];
}
