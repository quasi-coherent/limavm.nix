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
    };
  };

  config = lib.mkIf (cfg.vms != { }) {
    systemd.services = lib.mapAttrs' (
      name: vm:
      lib.nameValuePair "lima-${name}" {
        description = "Lima VM ${name}";
        wantedBy = lib.optional vm.autoStart "multi-user.target";
        after = [ "network.target" ];
        serviceConfig = {
          Type = "simple";
          ExecStart = "${cfg.package}/bin/limactl start --tty=false --name=${name} ${vm.config.system.build.limaYaml}";
          ExecStop = "${cfg.package}/bin/limactl stop ${name}";
          Restart = "on-failure";
        };
      }
    ) cfg.vms;

    environment.systemPackages = [ cfg.package ];
  };
}
