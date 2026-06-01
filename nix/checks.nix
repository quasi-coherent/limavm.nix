{
  inputs,
  lib,
  config,
  ...
}:
{
  den.hosts.aarch64-linux.lima-check-vm = {
    intoAttr = [ ];
  };

  den.hosts.aarch64-linux.lima-check-orchestrator = {
    lima.guests = [ config.den.hosts.aarch64-linux.lima-check-vm ];
  };

  den.aspects.lima-check-vm.nixos = {
    users.users.root.password = "";
    system.stateVersion = "24.11";
  };

  den.aspects.lima-check-orchestrator.nixos = {
    system.stateVersion = "24.11";
    boot.loader.grub.enable = false;
    fileSystems."/" = {
      device = "/dev/null";
      fsType = "ext4";
    };
  };

  perSystem =
    { pkgs, system, ... }:
    lib.optionalAttrs
      (builtins.elem system [
        "aarch64-darwin"
        "x86_64-darwin"
        "aarch64-linux"
        "x86_64-linux"
      ])
      {
        checks.lima-policy-eval = pkgs.writeText "lima-policy-eval" (
          builtins.toString
            config.flake.nixosConfigurations.lima-check-orchestrator.config.lima.vms.lima-check-vm.config.networking.hostName
        );
      };
}
