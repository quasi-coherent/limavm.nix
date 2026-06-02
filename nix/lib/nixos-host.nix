{ config, lib, ... }:
let
  cfg = config.lima;
in
{
  config = {
    environment.systemPackages = [ cfg.package ];

    systemd.services = lib.mapAttrs' (_: vm: {
      name = "lima-${vm.name}";
      value = {
        description = "Lima VM ${vm.name}";
        wantedBy = lib.optional vm.autoStart "multi-user.target";
        after = [ "network.target" ];
        serviceConfig = {
          Type = "simple";
          ExecStart = "${cfg.package}/bin/limactl start --tty=false --name=${vm.name} ${vm.yaml}";
          ExecStop = "${cfg.package}/bin/limactl stop ${vm.name}";
          Restart = "on-failure";
        };
      };
    }) cfg.vms;
  };
}
