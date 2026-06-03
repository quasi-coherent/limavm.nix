{
  config,
  pkgs,
  lib,
  ...
}:
let
  prg = config.programs.limavm-nix;
  svc = config.services.limavm-nix;

  mkGuestYaml = (import ../lib).mkGuestYaml;
  yamlOf =
    vm:
    if vm.yaml != null then
      vm.yaml
    else
      mkGuestYaml {
        inherit pkgs;
        inherit (vm.guest) system modules;
      };

  prgCfg = lib.mkIf prg.enable {
    home.packages = [ svc.package ];
  };

  svcCfg = lib.mkIf svc.enable {
    assertions = lib.mapAttrsToList (n: vm: {
      assertion = (vm.yaml == null) != (vm.guest == null);
      message = "services.limavm-nix.vms.${n}: set exactly one of `yaml` or `guest`.";
    }) svc.vms;

    systemd.user.services = lib.mapAttrs' (_: vm: {
      name = "lima-${vm.name}";
      value = {
        Unit.Description = "Lima VM ${vm.name}";
        Install.WantedBy = lib.optional vm.autoStart "multi-user.target";
        Install.After = [ "network.target" ];
        Service = {
          Type = "simple";
          ExecStart = "${svc.package}/bin/limactl start --tty=false --name=${vm.name} ${yamlOf vm}";
          ExecStop = "${svc.package}/bin/limactl stop ${vm.name}";
          Restart = "on-failure";
        };
      };
    }) svc.vms;

    launchd.agents = lib.mapAttrs' (_: vm: {
      name = "lima-${vm.name}";
      value = {
        config = {
          enable = true;
          Label = "lima-${vm.name}";
          ProgramArguments = [
            "${svc.package}/bin/limactl"
            "start"
            "--tty=false"
            "--name=${vm.name}"
            "${yamlOf vm}"
          ];
          RunAtLoad = vm.autoStart;
          KeepAlive = vm.autoStart;
          StandardOutPath = "/tmp/lima-${vm.name}.log";
          StandardErrorPath = "/tmp/lima-${vm.name}.err";
        };
      };
    }) svc.vms;
  };
in
{
  options = {
    programs.limavm-nix.enable = lib.mkEnableOption ''
      Install `limactl` into the user's environment.
    '';

    services.limavm-nix = lib.mkOption {
      type = lib.types.submoduleWith {
        modules = [ ../host-options.nix ];
        specialArgs = { inherit pkgs; };
      };
      default = { };
      description = "Per-user Lima VM orchestrator.";
    };
  };

  config = lib.mkMerge [
    prgCfg
    svcCfg
  ];
}
