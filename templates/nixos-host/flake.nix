{
  description = "nixos host running a nixos guest";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
  inputs.limavm.url = "github:quasi-coherent/limavm.nix";
  inputs.limavm.inputs.nixpkgs.follows = "nixpkgs";

  outputs =
    {
      nixpkgs,
      limavm,
      ...
    }:
    {
      nixosConfigurations.server = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          limavm.nixosModules.lima
          {
            system.stateVersion = "26.05";
            boot.loader.grub.device = "/dev/sda";
            fileSystems."/" = {
              device = "/dev/sda1";
              fsType = "ext4";
            };

            services.limavm-nix = {
              enable = true;
              # `user` supplies the default for `limaHomeDir`
              # (`${config.users.users.<user>.home}/.lima`). Leave null to let
              # `limactl` pick its own per-OS default at runtime.
              user = "alice";
              vms.work-vm = {
                autoStart = true;
                # Optional: boot a prebuilt qcow2 (URL or local path) instead
                # of building one, e.g.,
                #   image = "https://example.com/nixos-base.qcow2";
                # Overrides the inline guest's `lima.image`.
                guest = {
                  modules = [
                    {
                      lima = {
                        enable = true;
                        runner = {
                          cpus = 4;
                          memory = "4GiB";
                          vmType = "qemu";
                        };
                      };
                      users.users.root.password = "";
                      system.stateVersion = "26.05";
                    }
                  ];
                };
              };
            };
          }
        ];
      };
    };
}
