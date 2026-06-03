{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.services.limavm-nix;
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
in
{
  options.services.limavm-nix = lib.mkOption {
    type = lib.types.submoduleWith {
      modules = [ ../host-options.nix ];
      specialArgs = { inherit pkgs; };
    };
    default = { };
    description = "Configuration for a NixOS host orchestrating guest Lima VMs.";
  };

  config = lib.mkIf cfg.enable {
    assertions = lib.mapAttrsToList (n: vm: {
      assertion = (vm.yaml == null) != (vm.guest == null);
      message = "services.limavm-nix.vms.${n}: set exactly one of `yaml` or `guest`.";
    }) cfg.vms;

    environment.systemPackages = [ cfg.package ];

    systemd.services = lib.mapAttrs' (_: vm: {
      name = "lima-${vm.name}";
      value = {
        description = "Lima VM ${vm.name}";
        wantedBy = lib.optional vm.autoStart "multi-user.target";
        after = [ "network.target" ];
        serviceConfig = {
          Type = "simple";
          ExecStart = "${cfg.package}/bin/limactl start --tty=false --name=${vm.name} ${yamlOf vm}";
          ExecStop = "${cfg.package}/bin/limactl stop ${vm.name}";
          Restart = "on-failure";
        };
      };
    }) cfg.vms;
  };
}
