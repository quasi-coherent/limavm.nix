{
  lib,
  pkgs,
  ...
}:
{
  options.lima = {
    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.lima;
      defaultText = lib.literalExpression "pkgs.lima";
      description = "The `limactl` package used by the orchestrator.";
    };

    vms = lib.mkOption {
      default = { };
      description = ''
        VMs to orchestrate on this host. Each entry produces a launchd
        agent (darwin) or systemd service (nixos) that runs
        `limactl start --name=<name> <yaml>`.
      '';
      type = lib.types.attrsOf (
        lib.types.submodule (
          { name, ... }:
          {
            options = {
              name = lib.mkOption {
                type = lib.types.str;
                default = name;
                description = "Lima instance name (defaults to the attr name).";
              };

              yaml = lib.mkOption {
                type = lib.types.path;
                description = ''
                  Path to the `lima.yaml` for this VM, typically
                  `nixosConfigurations.<name>.config.system.build.limaYaml`.
                '';
              };

              autoStart = lib.mkOption {
                type = lib.types.bool;
                default = true;
                description = "Start the VM at user login / boot.";
              };
            };
          }
        )
      );
    };
  };
}
