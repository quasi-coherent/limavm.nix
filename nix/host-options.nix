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
        VMs to orchestrate on this host. Each entry produces a launchd agent on
        darwin or a systemd unit on nixos that runs a `limactl start` command.

        The input for the command is either passed verbatim if `vms.*.yaml` is
        not null, or it is given the string of a pre-built image, or it is built
        entirely from an in-line `nixosSystem`.
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

              image = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                description = ''
                  Image override: A string with URL or absolute path to a qcow2
                  used as `images.*.location` in the Lima yaml.

                  When set, this skips building an image and overrides whatever
                  the inline `guest` config's `lima.image` says.  When null, the
                  decision is deferred to the guest's own `lima.image`.
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
                          NixOS modules describing the guest. Merged on top of
                          the Lima guest base of `options.nix` and `lima.nix`.
                        '';
                      };
                    };
                  }
                );
              };

              autoStart = lib.mkOption {
                type = lib.types.bool;
                default = true;
                description = "Start the VM at login.";
              };
            };
          }
        )
      );
    };
  };
}
