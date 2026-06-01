{
  lib,
  config,
  ...
}:
{
  den.hosts.aarch64-linux.lima-check-vm.lima.standalone = {
    enable = true;
    cpus = 2;
    memory = "2GiB";
    vmType = "vz";
  };

  den.aspects.lima-check-vm.nixos = {
    users.users.root.password = "";
    system.stateVersion = "26.05";
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
        checks.lima-runner-eval = pkgs.writeText "lima-runner-eval" (
          builtins.toString config.flake.packages.aarch64-linux.lima-check-vm.drvPath
        );
      };
}
