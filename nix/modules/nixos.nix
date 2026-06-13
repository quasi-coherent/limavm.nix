{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.services.limavm-nix;
  yamlOf = import ../yaml-of.nix {
    inherit pkgs lib;
    hostSystem = pkgs.stdenv.hostPlatform.system;
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

  config = lib.mkIf cfg.enable (
    let
      limaHome = cfg.limaHomeDir;
      envLimaHome = lib.optionalAttrs (limaHome != null) { LIMA_HOME = limaHome; };
      mkdirPre = lib.optional (
        limaHome != null
      ) "${pkgs.coreutils}/bin/mkdir -p ${lib.escapeShellArg limaHome}";
    in
    {
      assertions = lib.mapAttrsToList (n: vm: {
        assertion = (vm.yaml == null) != (vm.guest == null);
        message = "services.limavm-nix.vms.${n}: set exactly one of `yaml` or `guest`.";
      }) cfg.vms;

      services.limavm-nix.limaHomeDir = lib.mkIf (cfg.user != null) (
        lib.mkDefault "${config.users.users.${cfg.user}.home}/.lima"
      );

      environment.systemPackages = [ cfg.package ];

      systemd.services = lib.mapAttrs' (_: vm: {
        name = "lima-${vm.name}";
        value = {
          description = "Lima VM ${vm.name}";
          wantedBy = lib.optional vm.autoStart "multi-user.target";
          after = [ "network.target" ];
          environment = envLimaHome;
          serviceConfig = {
            Type = "simple";
            ExecStartPre = mkdirPre;
            ExecStart = "${cfg.package}/bin/limactl start --tty=false --name=${vm.name} ${yamlOf vm}";
            ExecStop = "${cfg.package}/bin/limactl stop ${vm.name}";
            Restart = "on-failure";
          };
        };
      }) cfg.vms;
    }
  );
}
