{ lib, ... }:
let
  extendHostSchema =
    { host, ... }:
    {
      options.lima.standalone = lib.mkOption {
        type = lib.types.attrs;
        default = { };
        description = ''
          Declare this den host as a runnable Lima guest. When `enable`
          is true, `mkLimactl` injects `inputs.limavm.nixosModules.lima`
          into the host's NixOS evaluation, projects the remaining keys
          here (cpus, memory, vmType, mounts, portForwards,
          rosetta.enabled, ssh.*, ...) into `lima.*`, and emits a
          `flake.packages.<runnerSystem>.<name>` runner for each entry
          in `runnerSystems` (default: the guest arch on both darwin
          and linux). `limactl` runs on the host, not the guest, so
          the wrapper lives under the host's system — not the guest's.

          Reserved meta keys (not projected into `lima.*`):
            - `enable`         — gates emission of the runner.
            - `runnerSystems`  — list of systems where the wrapper is
                                 emitted. Override to narrow or widen.
        '';
      };

      config.intoAttr = lib.mkIf (host.lima.standalone.enable or false) [ ];
    };
in
{
  den.classes.lima.description = "Lima VM guest configuration (limavm options)";
  den.schema.host.imports = [ extendHostSchema ];
}
