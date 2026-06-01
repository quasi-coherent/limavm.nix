{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.lima;
in
{
  options.lima = with lib; {
    vms = mkOption {
      type = types.attrsOf (
        types.submodule (
          { ... }:
          {
            options.config = mkOption {
              type = types.unspecified;
              description = "Resolved NixOS guest config.";
            };
            options.autoStart = mkOption {
              type = types.bool;
              default = true;
              description = "Whether the launchd agent runs at login.";
            };
          }
        )
      );
      default = { };
    };

    package = mkOption {
      type = types.package;
      default = pkgs.lima;
      defaultText = literalExpression "pkgs.lima";
      description = "Lima CLI package providing limactl.";
    };
  };

  config = lib.mkIf (cfg.vms != { }) {
    launchd.user.agents = lib.mapAttrs' (
      name: vm:
      lib.nameValuePair "lima-${name}" {
        serviceConfig = {
          Label = "lima-${name}";
          ProgramArguments = [
            "${cfg.package}/bin/limactl"
            "start"
            "--tty=false"
            "--name=${name}"
            "${vm.config.system.build.limaYaml}"
          ];
          RunAtLoad = vm.autoStart;
          KeepAlive = vm.autoStart;
          StandardOutPath = "/tmp/lima-${name}.log";
          StandardErrorPath = "/tmp/lima-${name}.err";
        };
      }
    ) cfg.vms;

    environment.systemPackages = [ cfg.package ];
  };
}
