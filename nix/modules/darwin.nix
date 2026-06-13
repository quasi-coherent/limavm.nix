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
    description = "Configuration for a darwin host orchestrating guest Lima VMs.";
  };

  config = lib.mkIf cfg.enable (
    let
      limaHome = cfg.limaHomeDir;
      envLimaHome = lib.optionalAttrs (limaHome != null) { LIMA_HOME = limaHome; };
      mkdirHome = lib.optionalString (
        limaHome != null
      ) "${pkgs.coreutils}/bin/mkdir -p ${lib.escapeShellArg limaHome} && ";
      launchdShim =
        vm:
        pkgs.writeShellScript "lima-${vm.name}-launchd" ''
          ${mkdirHome}exec ${cfg.package}/bin/limactl start --tty=false --name=${vm.name} ${yamlOf vm}
        '';
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

      launchd.user.agents = lib.mapAttrs' (_: vm: {
        name = "lima-${vm.name}";
        value = {
          serviceConfig = {
            Label = "lima-${vm.name}";
            ProgramArguments = [ "${launchdShim vm}" ];
            EnvironmentVariables = envLimaHome;
            RunAtLoad = vm.autoStart;
            KeepAlive = vm.autoStart;
            StandardOutPath = "/tmp/lima-${vm.name}.log";
            StandardErrorPath = "/tmp/lima-${vm.name}.err";
          };
        };
      }) cfg.vms;
    }
  );
}
