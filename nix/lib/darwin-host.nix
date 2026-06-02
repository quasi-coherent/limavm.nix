{ config, lib, ... }:
let
  cfg = config.lima;
in
{
  config = {
    environment.systemPackages = [ cfg.package ];

    launchd.user.agents = lib.mapAttrs' (_: vm: {
      name = "lima-${vm.name}";
      value = {
        serviceConfig = {
          Label = "lima-${vm.name}";
          ProgramArguments = [
            "${cfg.package}/bin/limactl"
            "start"
            "--tty=false"
            "--name=${vm.name}"
            "${vm.yaml}"
          ];
          RunAtLoad = vm.autoStart;
          KeepAlive = vm.autoStart;
          StandardOutPath = "/tmp/lima-${vm.name}.log";
          StandardErrorPath = "/tmp/lima-${vm.name}.err";
        };
      };
    }) cfg.vms;
  };
}
