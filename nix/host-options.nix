{ pkgs, lib, ... }:
{
  options = {
    enable = lib.mkEnableOption "Lima VM orchestrator on this host";

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
        `limactl start --name=<name> <yaml>`. Provide either a pre-built
        `yaml` path or an inline `guest` config; the orchestrator builds
        the guest from `guest` if `yaml` is null.
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
                type = lib.types.nullOr lib.types.path;
                default = null;
                description = ''
                  Pre-built `lima.yaml` path. Set this OR `guest`, not both.
                '';
              };

              guest = lib.mkOption {
                default = null;
                description = ''
                  Inline NixOS guest definition. Set this OR `yaml`, not both.
                '';
                type = lib.types.nullOr (
                  lib.types.submodule {
                    options = {
                      system = lib.mkOption {
                        type = lib.types.str;
                        description = "Guest system, e.g. \"aarch64-linux\".";
                      };
                      modules = lib.mkOption {
                        type = lib.types.listOf lib.types.unspecified;
                        default = [ ];
                        description = ''
                          NixOS modules describing the guest. Merged on top
                          of the Lima guest base (`options.nix` + `lima.nix`).
                        '';
                      };
                    };
                  }
                );
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
