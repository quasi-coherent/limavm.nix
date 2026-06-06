{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.services.limavm-nix;
  lima-lib = import ../lib { inherit lib; };
  yamlOf = lima-lib.yamlOf { inherit pkgs; };
in
{
  options.services.limavm-nix = lib.mkOption {
    type = lib.types.submoduleWith {
      modules = [ ../host-options.nix ];
      specialArgs = { inherit pkgs; };
    };
    default = { };
    description = "Configuration for a darwin host orchestrating guest Lima VMs.";
  };

  config = lib.mkIf cfg.enable {
    assertions = lib.mapAttrsToList (n: vm: {
      assertion = (vm.yaml == null) != (vm.guest == null);
      message = "services.limavm-nix.vms.${n}: set exactly one of `yaml` or `guest`.";
    }) cfg.vms;

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
            "${yamlOf vm}"
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
